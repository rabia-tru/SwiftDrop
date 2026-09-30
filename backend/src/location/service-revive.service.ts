import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LocationLog } from './entities/location-log.entity';

/**
 * Second-chance recovery channel for the rider tracking pipeline.
 *
 * The client watchdog (WatchdogReceiver.kt) already restarts the killed
 * service from OUTSIDE the process. This service is the backend-side
 * safety net for the cases where that chain itself is broken: OEM deep
 * kills that also clear alarms, Android 12+ FGS-start denials, force-stop.
 *
 * There is no FCM/Firebase in this project, so instead of a silent push
 * the signal travels over the EXISTING socket.io connection: the rider
 * app keeps a WebSocket with auto-reconnection to /tracking. When the
 * backend notices a tracking rider's pings have gone silent, it emits a
 * `service:revive` event into that socket. The client handler restarts
 * the background service (see lib/services/websocket_service.dart).
 *
 * Delivery semantics are "best effort" and intentionally layered:
 *   1. If the app process is alive with only the BG service dead, the
 *      socket is connected → revive lands instantly.
 *   2. If the process is dead, the socket is gone → nothing to deliver;
 *      the client-side watchdog remains the recovery path, and the
 *      socket's own auto-reconnect (2s→10s backoff) re-arms this channel
 *      as soon as Android revives anything of the app.
 */
@Injectable()
export class ServiceReviveService {
  private readonly logger = new Logger(ServiceReviveService.name);

  /** riderId → last revive emission. Prevents spamming a flapping app. */
  private readonly lastReviveAt = new Map<string, number>();

  /** Minimum gap between revives for the same rider. */
  private static readonly REVIVE_THROTTLE_MS = 5 * 60 * 1000;

  /** Staleness threshold — matches the client watchdog's 90s window. */
  private static readonly STALE_MS = 5 * 60 * 1000;

  constructor(
    // Repo injected directly (LocationModule already registers it via
    // TypeOrmModule.forFeature) instead of LocationService — importing
    // LocationService here creates a file-level import cycle:
    //   location.service → location.gateway → service-revive → location.service
    // which leaves Nest's reflected constructor types undefined at boot.
    @InjectRepository(LocationLog)
    private readonly locationLogRepository: Repository<LocationLog>,
  ) {}

  /**
   * Every 2 minutes: find riders whose tracking flags say they should be
   * streaming but whose last location ping is older than the staleness
   * window, and nudge them.
   */
  @Cron('*/2 * * * *')
  async detectAndRevive(): Promise<void> {
    try {
      const staleRiderIds = await this.findStaleTrackingRiders(
        ServiceReviveService.STALE_MS,
      );

      for (const riderId of staleRiderIds) {
        this.reviveRider(riderId, 'stale-pings');
      }
    } catch (e) {
      this.logger.error(`Stale-rider sweep failed: ${e?.message ?? e}`);
    }
  }

  /**
   * Rider ids whose latest location ping is older than [staleMs] AND
   * whose most recent ping belonged to an active delivery (orderId set).
   * Detects a tracking rider that went silent mid-delivery — the case the
   * client watchdog failed to revive. Returns distinct rider ids; empty
   * array when everyone is healthy.
   * (Lives here rather than LocationService to avoid the import cycle —
   * see the constructor note.)
   */
  async findStaleTrackingRiders(staleMs: number): Promise<string[]> {
    const cutoff = new Date(Date.now() - staleMs);
    const rows = await this.locationLogRepository
      .createQueryBuilder('log')
      .select('DISTINCT log.riderId', 'riderId')
      .where('log.orderId IS NOT NULL')
      // per-rider latest ping must be older than the cutoff
      // Raw subquery in the where-clause bypasses TypeORM's escaping, so
      // the camelCase column names MUST be quoted explicitly — Postgres
      // folds bare l2.createdAt to lowercase (l2.createdat) and the query
      // dies with "column does not exist" every cron tick.
      .andWhere(
        `log."createdAt" = (SELECT MAX(l2."createdAt") FROM location_logs l2
                            WHERE l2."riderId" = log."riderId")`,
      )
      .andWhere('log."createdAt" < :cutoff', { cutoff })
      .getRawMany<{ riderId: string }>();
    return rows.map((r) => r.riderId);
  }

  /**
   * Emit the revive signal to the rider's tracking room. The rider app
   * joins `rider:<id>` on its own socket (WebSocketService.watchRider is
   * also called for the rider's own id after connect), so a room emit is
   * the transport-neutral way to reach any socket the rider has open.
   */
  reviveRider(riderId: string, reason: string): boolean {
    const now = Date.now();
    const last = this.lastReviveAt.get(riderId);
    if (last != null && now - last < ServiceReviveService.REVIVE_THROTTLE_MS) {
      return false; // throttled
    }
    this.lastReviveAt.set(riderId, now);

    const payload = { reason, sentAt: new Date().toISOString() };
    this.gateway?.server?.to(`rider:${riderId}`).emit('service:revive', payload);
    this.logger.warn(`Revive signal sent to rider ${riderId} (${reason})`);

    // Opportunistic map cleanup so the throttle map cannot grow forever.
    if (this.lastReviveAt.size > 1000) {
      for (const [id, ts] of this.lastReviveAt) {
        if (now - ts > 24 * 60 * 60 * 1000) this.lastReviveAt.delete(id);
      }
    }
    return true;
  }

  /**
   * Wired by LocationGateway at init so this service can emit without a
   * circular dependency (gateway already depends on ChatService; the
   * revive service only needs the raw io Server).
   */
  private gateway: { server: import('socket.io').Server } | null = null;
  attachGateway(gateway: { server: import('socket.io').Server }) {
    this.gateway = gateway;
  }
}
