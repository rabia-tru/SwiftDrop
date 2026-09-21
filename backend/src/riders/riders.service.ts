import { Injectable, NotFoundException, Inject, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Rider } from './entities/rider.entity';
import { RiderStatus, OrderStatus } from '../common/enums';
import { OrdersService } from '../orders/orders.service';

@Injectable()
export class RidersService {
  constructor(
    @InjectRepository(Rider)
    private riderRepository: Repository<Rider>,
    @Inject(forwardRef(() => OrdersService))
    private ordersService: OrdersService,
  ) {}

  async findById(id: string) {
    const rider = await this.riderRepository.findOne({ where: { id } });
    if (!rider) throw new NotFoundException('Rider not found');
    return rider;
  }

  async findAllOnline() {
    return this.riderRepository.find({
      where: { status: RiderStatus.ONLINE, isActive: true },
    });
  }

  async updateStatus(riderId: string, status: RiderStatus) {
    await this.riderRepository.update(riderId, { status });

    // When a rider comes ONLINE, hand them any business-confirmed order
    // that has no rider yet. Business-accept already broadcasts to the
    // fleet, but if the rider was offline at that moment (or the WS
    // event was missed), the order sat invisible forever — the rider's
    // own list only contains orders assigned to them.
    if (status === RiderStatus.ONLINE) {
      try {
        // Hand the rider the single oldest confirmed order — one delivery
        // at a time. The next online rider (or their next online toggle)
        // picks up the rest.
        const ready = await this.ordersService.findUnassignedConfirmedOrders(riderId);
        if (ready.length > 0) {
          await this.ordersService.assignRider((ready[0] as any).id, riderId);
        }
      } catch (e) {
        // Never block the online toggle on auto-assign problems.
        console.log('[Riders] Auto-assign on online failed:', (e as Error).message);
      }
    }

    return this.findById(riderId);
  }

  async updateLastKnownLocation(
    riderId: string,
    latitude: number,
    longitude: number,
  ) {
    await this.riderRepository.update(riderId, {
      lastKnownLat: latitude,
      lastKnownLng: longitude,
      lastLocationAt: new Date(),
    });
  }

  async me(riderId: string) {
    const { password, ...rider } = await this.findById(riderId);
    return rider;
  }

  async updateProfile(
    riderId: string,
    updates: { name?: string; phone?: string; vehicleType?: string; vehiclePlateNumber?: string },
  ) {
    await this.riderRepository.update(riderId, updates);
    return this.me(riderId);
  }
}
