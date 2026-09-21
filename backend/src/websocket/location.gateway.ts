import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatService } from '../chat/chat.service';
import { WsValidationException, catchWsError } from '../common/ws-utils';

// Customer app / admin dashboard connects and joins a room named after
// the orderId (or riderId) it wants to watch, then receives live pings.
@WebSocketGateway({
  cors: { origin: '*' }, // tighten this to your real frontend origin in production
  namespace: '/tracking',
})
export class LocationGateway {
  @WebSocketServer()
  server: Server;

  constructor(private readonly chatService: ChatService) {}

  handleConnection(client: Socket) {
    console.log(`[WS] Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    console.log(`[WS] Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('watchOrder')
  handleWatchOrder(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { orderId: string },
  ) {
    const room = `order:${data.orderId}`;
    client.join(room);
    console.log(`[WS] Client ${client.id} watching order ${data.orderId}`);
    return { event: 'watchingOrder', data: { orderId: data.orderId, success: true } };
  }

  @SubscribeMessage('unwatchOrder')
  handleUnwatchOrder(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { orderId: string },
  ) {
    const room = `order:${data.orderId}`;
    client.leave(room);
    console.log(`[WS] Client ${client.id} stopped watching order ${data.orderId}`);
    return { event: 'unwatchedOrder', data: { orderId: data.orderId, success: true } };
  }

  @SubscribeMessage('watchRider')
  handleWatchRider(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { riderId: string },
  ) {
    const room = `rider:${data.riderId}`;
    client.join(room);
    console.log(`[WS] Client ${client.id} watching rider ${data.riderId}`);
    return { event: 'watchingRider', data: { riderId: data.riderId, success: true } };
  }

  @SubscribeMessage('watchCustomerOrders')
  handleWatchCustomerOrders(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { customerId: string },
  ) {
    const room = `customer:${data.customerId}`;
    client.join(room);
    console.log(`[WS] Client ${client.id} watching customer ${data.customerId} orders`);
    return { event: 'watchingCustomerOrders', data: { customerId: data.customerId, success: true } };
  }

  @SubscribeMessage('watchBusiness')
  handleWatchBusiness(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { businessId: string },
  ) {
    const room = `business:${data.businessId}`;
    client.join(room);
    console.log(`[WS] Client ${client.id} watching business ${data.businessId}`);
    return { event: 'watchingBusiness', data: { businessId: data.businessId, success: true } };
  }

  // ─── Broadcasting Methods ────────────────────────────────────────

  /** Called from LocationService whenever a new ping is saved */
  broadcastRiderLocation(
    riderId: string,
    payload: {
      latitude: number;
      longitude: number;
      speed?: number;
      accuracy?: number;
      orderId?: string;
      recordedAt: string;
    },
  ) {
    // Emit to anyone watching this rider
    this.server.to(`rider:${riderId}`).emit('rider:location', {
      riderId,
      ...payload,
    });

    // Emit to anyone watching this specific order
    if (payload.orderId) {
      this.server.to(`order:${payload.orderId}`).emit('order:location', {
        riderId,
        ...payload,
      });
    }

    // Global broadcast for dashboard / maps
    this.server.emit('location:update', {
      riderId,
      ...payload,
    });
  }

  /** Called from OrdersService when order status changes */
  broadcastOrderStatus(
    orderId: string,
    payload: {
      status: string;
      riderId?: string;
      riderName?: string;
      note?: string;
      dropAddress?: string;
      updatedAt: string;
    },
  ) {
    // Emit to anyone watching this specific order
    this.server.to(`order:${orderId}`).emit('order:status', {
      orderId,
      ...payload,
    });

    // Emit to the customer who owns this order
    // (customerId will be included if available)
    if (payload.riderId) {
      this.server.to(`rider:${payload.riderId}`).emit('rider:orderUpdate', {
        orderId,
        ...payload,
      });
    }

    // Global broadcast for dashboard
    this.server.emit('order:update', {
      orderId,
      ...payload,
    });

    console.log(`[WS] Order ${orderId} status → ${payload.status}`);
  }

  /** Called from OrdersService when a rider is assigned */
  broadcastRiderAssigned(
    orderId: string,
    payload: {
      riderId: string;
      riderName: string;
      riderPhone?: string;
      vehicleType?: string;
      updatedAt: string;
    },
  ) {
    this.server.to(`order:${orderId}`).emit('order:riderAssigned', {
      orderId,
      ...payload,
    });

    this.server.emit('order:update', {
      orderId,
      status: 'assigned',
      ...payload,
    });

    console.log(`[WS] Rider ${payload.riderId} assigned to order ${orderId}`);
  }

  /** Push live updates into a business's private room */
  broadcastNewOrderToBusiness(order: any) {
    if (!order?.businessId) return;
    this.server.to(`business:${order.businessId}`).emit('business:newOrder', {
      orderId: order.id,
      status: order.status,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      dropAddress: order.dropAddress,
      fare: order.fare,
      items: order.items,
      paymentMethod: order.paymentMethod,
      createdAt: order.createdAt,
    });
    console.log(`[WS] Business ${order.businessId} notified of order ${order.id}`);
  }

  /** Push live updates into a customer's private room */
  broadcastToCustomer(customerId: string | undefined | null, payload: any) {
    if (!customerId) return;
    this.server.to(`customer:${customerId}`).emit('customer:orderUpdate', payload);
  }

  /** Broadcast new order to all online riders */
  broadcastNewOrderToRiders(order: any) {
    this.server.emit('order:newAvailable', {
      orderId: order.id,
      pickupAddress: order.pickupAddress,
      dropAddress: order.dropAddress,
      fare: order.fare,
      createdAt: order.createdAt,
    });
    console.log(`[WS] New order ${order.id} broadcast to all riders`);
  }

  /**
   * A business's menu changed (item added/updated/deleted/toggled).
   * Broadcast globally — customers browsing that business's list or
   * detail screen aren't in any per-business room, so this is a plain
   * "hey, refresh if you care about this businessId" signal.
   */
  broadcastMenuUpdated(businessId: string) {
    this.server.emit('business:menuUpdated', {
      businessId,
      updatedAt: new Date().toISOString(),
    });
    console.log(`[WS] Menu updated for business ${businessId}`);
  }

  // ─── Chat ────────────────────────────────────────────────────────

  /**
   * Real-time chat inside an order room. Persists the message, then
   * broadcasts it to everyone in `order:{orderId}` (customer + rider).
   */
  @SubscribeMessage('chat:send')
  async handleChatSend(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: {
      orderId: string;
      message: string;
      senderRole: string;
      senderName?: string;
      imageUrl?: string;
    },
  ) {
    try {
      if (!data?.orderId || (!data?.message?.trim() && !data?.imageUrl)) {
        throw new WsValidationException('orderId and message/imageUrl are required');
      }
      // Normalize image URL: accept absolute URLs as-is, prefix server-relative
      // ones with nothing (clients resolve against the API origin).
      const imageUrl =
        typeof data.imageUrl === 'string' && data.imageUrl.trim().length > 0
          ? data.imageUrl.trim().slice(0, 500)
          : undefined;

      const saved = await this.chatService.save({
        orderId: data.orderId,
        senderRole: data.senderRole ?? 'customer',
        senderName: data.senderName,
        message: (data.message ?? '').trim().slice(0, 2000),
        imageUrl,
      });

      const payload = {
        id: saved.id,
        orderId: saved.orderId,
        message: saved.message,
        senderRole: saved.senderRole,
        senderName: saved.senderName,
        imageUrl: saved.imageUrl,
        createdAt: saved.createdAt,
      };

      // Everyone in the order room receives it (sender echo is deduped client-side by id)
      this.server.to(`order:${data.orderId}`).emit('chat:message', payload);
      console.log(`[WS] Chat ${saved.senderRole} → order ${data.orderId}`);
      return { event: 'chat:sent', data: payload };
    } catch (err) {
      return catchWsError(err, 'chat:send failed');
    }
  }

  /** Typing indicator broadcast (not persisted) */
  @SubscribeMessage('chat:typing')
  handleChatTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { orderId: string; senderRole: string; isTyping: boolean },
  ) {
    if (!data?.orderId) return;
    client.to(`order:${data.orderId}`).emit('chat:typing', {
      orderId: data.orderId,
      senderRole: data.senderRole,
      isTyping: !!data.isTyping,
    });
  }

  /** Notify specific rider of new order */
  notifyRiderOfOrder(riderId: string, order: any) {
    this.server.to(`rider:${riderId}`).emit('order:newAssigned', {
      orderId: order.id,
      pickupAddress: order.pickupAddress,
      dropAddress: order.dropAddress,
      fare: order.fare,
      status: order.status,
    });
    console.log(`[WS] Rider ${riderId} notified of order ${order.id}`);
  }
}