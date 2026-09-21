import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LocationLog } from './entities/location-log.entity';
import { SyncLocationBatchDto } from './dto/location.dto';
import { RidersService } from '../riders/riders.service';
import { LocationGateway } from '../websocket/location.gateway';

@Injectable()
export class LocationService {
  constructor(
    @InjectRepository(LocationLog)
    private locationLogRepository: Repository<LocationLog>,
    private ridersService: RidersService,
    private locationGateway: LocationGateway,
  ) {}

  // Handles batch sync from the rider app's background service.
  // Because the mobile app queues pings locally when offline, a single
  // sync call may contain many pings recorded over the last few minutes/hours.
  async syncBatch(riderId: string, dto: SyncLocationBatchDto) {
    if (!dto.pings || dto.pings.length === 0) {
      return { saved: 0 };
    }

    const logs = dto.pings.map((ping) =>
      this.locationLogRepository.create({
        riderId,
        latitude: ping.latitude,
        longitude: ping.longitude,
        speed: ping.speed,
        accuracy: ping.accuracy,
        orderId: ping.orderId,
        recordedAt: new Date(ping.recordedAt),
      }),
    );

    await this.locationLogRepository.save(logs);

    // Sort so we update rider's "last known" with the most recent ping only
    const latest = [...dto.pings].sort(
      (a, b) => new Date(b.recordedAt).getTime() - new Date(a.recordedAt).getTime(),
    )[0];

    await this.ridersService.updateLastKnownLocation(
      riderId,
      latest.latitude,
      latest.longitude,
    );

    // Push live update to anyone watching this rider/order right now
    this.locationGateway.broadcastRiderLocation(riderId, {
      latitude: latest.latitude,
      longitude: latest.longitude,
      speed: latest.speed,
      orderId: latest.orderId,
      recordedAt: latest.recordedAt,
    });

    return { saved: logs.length };
  }

  async getHistoryForOrder(orderId: string) {
    return this.locationLogRepository.find({
      where: { orderId },
      order: { recordedAt: 'ASC' },
    });
  }

  async getRecentForRider(riderId: string, limit = 50) {
    return this.locationLogRepository.find({
      where: { riderId },
      order: { recordedAt: 'DESC' },
      take: limit,
    });
  }
}
