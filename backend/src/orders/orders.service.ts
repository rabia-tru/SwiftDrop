import {
  BadRequestException,
  Injectable,
  NotFoundException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { Order } from './entities/order.entity';
import { OrderStatusHistory } from './entities/order-status-history.entity';
import { CreateOrderDto, UpdateOrderStatusDto } from './dto/order.dto';
import { OrderStatus, RiderStatus } from '../common/enums';
import { RidersService } from '../riders/riders.service';
import { LocationGateway } from '../websocket/location.gateway';

// Which statuses are allowed to follow which — prevents e.g. jumping
// straight from PENDING to DELIVERED.
const ALLOWED_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  [OrderStatus.PENDING]: [OrderStatus.ASSIGNED, OrderStatus.CANCELLED],
  [OrderStatus.ASSIGNED]: [OrderStatus.ACCEPTED, OrderStatus.CANCELLED],
  [OrderStatus.ACCEPTED]: [OrderStatus.PICKED_UP, OrderStatus.CANCELLED],
  [OrderStatus.PICKED_UP]: [OrderStatus.IN_TRANSIT, OrderStatus.CANCELLED],
  [OrderStatus.IN_TRANSIT]: [OrderStatus.DELIVERED, OrderStatus.CANCELLED],
  [OrderStatus.DELIVERED]: [],
  [OrderStatus.CANCELLED]: [],
};

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order)
    private orderRepository: Repository<Order>,
    @InjectRepository(OrderStatusHistory)
    private historyRepository: Repository<OrderStatusHistory>,
    @Inject(forwardRef(() => RidersService))
    private ridersService: RidersService,
    private locationGateway: LocationGateway,
  ) {}

  // The mobile app's ETA/"rider X min away" logic reads order['riderLat'] /
  // order['lastKnownLat'] straight off the order object — it never looks
  // inside a nested `rider` relation. TypeORM only gives us the rider's
  // position nested under `order.rider.lastKnownLat`, so without this the
  // app always gets `null` here and silently falls back to a fake 3km
  // guess. This flattens the rider's last known position onto the order
  // itself so the app's distance/ETA calculation uses real GPS data.
  private withRiderLocation(order: Order | null): any {
    if (!order) return order;
    const plain: any = { ...order };
    if (order.rider) {
      plain.riderLat = order.rider.lastKnownLat ?? null;
      plain.riderLng = order.rider.lastKnownLng ?? null;
      plain.lastKnownLat = order.rider.lastKnownLat ?? null;
      plain.lastKnownLng = order.rider.lastKnownLng ?? null;
      plain.riderLastLocationAt = order.rider.lastLocationAt ?? null;
    }
    return plain;
  }

  async create(dto: CreateOrderDto) {
    const order = this.orderRepository.create({
      ...dto,
      status: OrderStatus.PENDING,
    });
    const saved = await this.orderRepository.save(order);
    await this.recordHistory(saved.id, OrderStatus.PENDING, 'Order created');

    // Broadcast new order creation
    this.locationGateway.broadcastOrderStatus(saved.id, {
      status: OrderStatus.PENDING,
      updatedAt: saved.createdAt.toISOString(),
    });

    // Notify the business this order belongs to
    this.locationGateway.broadcastNewOrderToBusiness(saved);

    // Broadcast to all online riders
    this.locationGateway.broadcastNewOrderToRiders(saved);

    return saved;
  }

  async findAll() {
    const orders = await this.orderRepository.find({
      relations: { rider: true },
      order: { createdAt: 'DESC' },
    });
    return orders.map((o) => this.withRiderLocation(o));
  }

  // Raw entity — used internally when we need to mutate + save() the order
  // (assignRider/updateStatus). findOne() below is the public/API-facing
  // version and returns the flattened plain object instead.
  private async findEntity(id: string): Promise<Order> {
    const order = await this.orderRepository.findOne({
      where: { id },
      relations: { rider: true, statusHistory: true },
    });
    if (!order) throw new NotFoundException('Order not found');
    return order;
  }

  async findOne(id: string) {
    const order = await this.findEntity(id);
    return this.withRiderLocation(order);
  }

  async findForRider(riderId: string) {
    return this.orderRepository.find({
      where: { riderId },
      order: { createdAt: 'DESC' },
    });
  }

  async findForCustomer(customerId: string) {
    const orders = await this.orderRepository.find({
      where: { customerId },
      relations: { rider: true },
      order: { createdAt: 'DESC' },
    });
    return orders.map((o) => this.withRiderLocation(o));
  }

  async findForBusiness(businessId: string) {
    const orders = await this.orderRepository.find({
      where: { businessId },
      relations: { rider: true },
      order: { createdAt: 'DESC' },
    });
    return orders.map((o) => this.withRiderLocation(o));
  }

  /**
   * Business-confirmed orders with no rider yet, excluding ones already
   * assigned to the given rider. Used when a rider comes online so they
   * instantly pick up confirmed orders that were broadcast while they
   * were offline.
   */
  async findUnassignedConfirmedOrders(excludeRiderId: string) {
    return this.orderRepository.find({
      where: {
        status: OrderStatus.PENDING,
        riderId: IsNull(),
        businessConfirmed: true,
      },
      order: { createdAt: 'ASC' }, // oldest first — fair FIFO handout
    });
  }

  async createForCustomer(dto: CreateOrderDto, customerId: string) {
    const order = this.orderRepository.create({
      ...dto,
      customerId,
      status: OrderStatus.PENDING,
    });
    const saved = await this.orderRepository.save(order);
    await this.recordHistory(saved.id, OrderStatus.PENDING, 'Order created by customer');

    // Broadcast new order
    this.locationGateway.broadcastOrderStatus(saved.id, {
      status: OrderStatus.PENDING,
      updatedAt: saved.createdAt.toISOString(),
    });

    // Notify the business + the customer's own live feed
    this.locationGateway.broadcastNewOrderToBusiness(saved);
    this.locationGateway.broadcastToCustomer(saved.customerId, {
      orderId: saved.id,
      status: saved.status,
      businessName: (saved as any).businessName,
      updatedAt: saved.createdAt.toISOString(),
    });

    // Try to auto-assign to an online rider
    try {
      const onlineRiders = await this.ridersService.findAllOnline();
      if (onlineRiders.length > 0) {
        // Pick the first available rider
        const rider = onlineRiders[0];
        return this.assignRider(saved.id, rider.id);
      }
    } catch (e) {
      console.log('[Orders] Auto-assign failed, order stays pending:', e.message);
    }

    // If no rider available, broadcast to all riders
    this.locationGateway.broadcastNewOrderToRiders(saved);

    return saved;
  }

  // Business confirms it will prepare this order. Independent of `status`/
  // ALLOWED_TRANSITIONS on purpose — see the `businessConfirmed` column
  // comment on the entity for why this isn't just another order status.
  async businessAccept(orderId: string) {
    const order = await this.findEntity(orderId);
    if (order.status === OrderStatus.DELIVERED || order.status === OrderStatus.CANCELLED) {
      throw new BadRequestException(
        `Cannot confirm an order that is already ${order.status}`,
      );
    }
    if (order.businessConfirmed) {
      return this.withRiderLocation(order);
    }

    order.businessConfirmed = true;
    order.businessConfirmedAt = new Date();
    const saved = await this.orderRepository.save(order);
    await this.recordHistory(orderId, order.status, 'Business confirmed the order');

    let full: any = await this.orderRepository.findOne({
      where: { id: orderId },
      relations: { rider: true },
    });

    // If no rider has been assigned yet (order still PENDING), try to
    // auto-assign an online rider NOW. Without this, a business accepting
    // an order saw zero progress: the order stayed 'pending' forever and
    // no rider was ever asked to pick it up — the report behind
    // "business owner can't accept the order".
    if (order.status === OrderStatus.PENDING && !order.riderId) {
      try {
        const onlineRiders = await this.ridersService.findAllOnline();
        if (onlineRiders.length > 0) {
          full = await this.assignRider(orderId, onlineRiders[0].id);
        }
      } catch (e) {
        console.log('[Orders] Business-accept auto-assign failed:', (e as Error).message);
      }
    }

    const finalStatus = (full?.status ?? order.status) as OrderStatus;
    const hasRider = !!(full?.riderId ?? order.riderId);

    // Still no rider → broadcast to the whole rider fleet so whoever comes
    // online sees the confirmed, ready-to-pickup order.
    if (!hasRider) {
      this.locationGateway.broadcastNewOrderToRiders(full ?? saved);
    }

    // Let the customer's live feed show "restaurant is preparing it" and
    // let the rider know the business is on it (useful if they're already
    // en route to pickup before the business confirmed).
    if (full?.customerId) {
      this.locationGateway.broadcastToCustomer(full.customerId, {
        orderId,
        status: finalStatus,
        businessConfirmed: true,
        riderName: full?.rider?.name,
        updatedAt: saved.updatedAt.toISOString(),
      });
    }
    if (order.riderId) {
      this.locationGateway.notifyRiderOfOrder(order.riderId, full ?? saved);
    }

    return this.withRiderLocation(full ?? saved);
  }

  /**
   * Business says the food is PREPARED — tell the assigned rider to come
   * pick it up now (and fleet-broadcast if nobody is attached yet).
   * This is the "user ka order prepare ho gaya, rider ko kaise pata chale"
   * path: the rider gets a system notification + live feed refresh.
   */
  async markReady(orderId: string) {
    const order = await this.findEntity(orderId);
    if (order.status === OrderStatus.DELIVERED || order.status === OrderStatus.CANCELLED) {
      throw new BadRequestException(`Cannot mark a ${order.status} order as ready`);
    }
    if (!order.businessConfirmed) {
      throw new BadRequestException('Accept the order first, then mark it ready');
    }

    order.readyNotifiedAt = new Date();
    const saved = await this.orderRepository.save(order);
    await this.recordHistory(orderId, order.status, 'Business marked the order as ready for pickup');

    const full: any = await this.orderRepository.findOne({
      where: { id: orderId },
      relations: { rider: true },
    });

    if (order.riderId) {
      // Assigned rider: private room message → app shows a notification.
      this.locationGateway.notifyRiderOfOrder(order.riderId, full ?? saved);
    }
    // Fleet fallback so an unassigned-but-online rider also hears it.
    if (!order.riderId) {
      this.locationGateway.broadcastNewOrderToRiders(full ?? saved);
    }
    if (full?.customerId) {
      this.locationGateway.broadcastToCustomer(full.customerId, {
        orderId,
        status: full.status,
        readyForPickup: true,
        updatedAt: saved.updatedAt.toISOString(),
      });
    }

    return this.withRiderLocation(full ?? saved);
  }

  async assignRider(orderId: string, riderId: string) {
    const order = await this.findEntity(orderId);
    if (order.status !== OrderStatus.PENDING) {
      throw new BadRequestException(
        `Cannot assign rider to an order in status ${order.status}`,
      );
    }

    // Confirms rider exists and is reachable
    const rider = await this.ridersService.findById(riderId);

    order.riderId = riderId;
    order.status = OrderStatus.ASSIGNED;
    const saved = await this.orderRepository.save(order);

    await this.ridersService.updateStatus(riderId, RiderStatus.ON_DELIVERY);
    await this.recordHistory(orderId, OrderStatus.ASSIGNED, `Assigned to rider ${riderId}`);

    // Reload with rider relation so the response always includes rider details
    const full = await this.orderRepository.findOne({
      where: { id: orderId },
      relations: { rider: true },
    });

    // Broadcast rider assignment via WebSocket
    this.locationGateway.broadcastRiderAssigned(orderId, {
      riderId,
      riderName: (rider as any).name || 'Rider',
      riderPhone: (rider as any).phone,
      vehicleType: (rider as any).vehicleType,
      updatedAt: saved.updatedAt.toISOString(),
    });

    // Notify the business + customer that a rider is on it
    this.locationGateway.broadcastNewOrderToBusiness(full ?? saved);
    if (full?.customerId) {
      this.locationGateway.broadcastToCustomer(full.customerId, {
        orderId,
        status: saved.status,
        riderName: (rider as any).name || 'Rider',
        updatedAt: saved.updatedAt.toISOString(),
      });
    }

    // Notify the assigned rider specifically
    this.locationGateway.notifyRiderOfOrder(riderId, saved);

    return this.withRiderLocation(full ?? saved);
  }

  async updateDropAddress(orderId: string, dropAddress: string) {
    const order = await this.findEntity(orderId);
    if (
      order.status === OrderStatus.DELIVERED ||
      order.status === OrderStatus.CANCELLED
    ) {
      throw new BadRequestException(
        'Cannot change the address of a delivered or cancelled order',
      );
    }
    order.dropAddress = dropAddress;
    const saved = await this.orderRepository.save(order);
    // Let customer/rider/map screens pick up the new drop location text.
    this.locationGateway.broadcastOrderStatus(orderId, {
      status: saved.status,
      riderId: order.riderId,
      note: 'Delivery address updated',
      dropAddress,
      updatedAt: saved.updatedAt.toISOString(),
    });
    return this.withRiderLocation(saved);
  }

  async updateStatus(orderId: string, dto: UpdateOrderStatusDto) {
    const order = await this.findEntity(orderId);

    const allowedNext = ALLOWED_TRANSITIONS[order.status] || [];
    if (!allowedNext.includes(dto.status)) {
      throw new BadRequestException(
        `Cannot move order from ${order.status} to ${dto.status}`,
      );
    }

    order.status = dto.status;
    const saved = await this.orderRepository.save(order);
    await this.recordHistory(orderId, dto.status, dto.note);

    // Reload with rider relation so the response always includes rider details
    const full = await this.orderRepository.findOne({
      where: { id: orderId },
      relations: { rider: true },
    });

    // Free up the rider once delivery finishes or is cancelled
    if (
      (dto.status === OrderStatus.DELIVERED ||
        dto.status === OrderStatus.CANCELLED) &&
      order.riderId
    ) {
      await this.ridersService.updateStatus(order.riderId, RiderStatus.ONLINE);
    }

    // Broadcast status change via WebSocket
    this.locationGateway.broadcastOrderStatus(orderId, {
      status: dto.status,
      riderId: order.riderId,
      note: dto.note,
      updatedAt: saved.updatedAt.toISOString(),
    });

    // Keep business + customer live feeds in sync
    this.locationGateway.broadcastNewOrderToBusiness(full ?? saved);
    if (order.customerId) {
      this.locationGateway.broadcastToCustomer(order.customerId, {
        orderId,
        status: dto.status,
        riderId: order.riderId,
        updatedAt: saved.updatedAt.toISOString(),
      });
    }

    return this.withRiderLocation(full ?? saved);
  }

  private async recordHistory(
    orderId: string,
    status: OrderStatus,
    note?: string,
  ) {
    const entry = this.historyRepository.create({ orderId, status, note });
    await this.historyRepository.save(entry);
  }
}