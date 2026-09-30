import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { LocationService } from './location.service';
import { SyncLocationBatchDto } from './dto/location.dto';
import { IsInt, IsOptional, Min } from 'class-validator';

@Controller('location')
@UseGuards(JwtAuthGuard)
export class LocationController {
  constructor(private readonly locationService: LocationService) {}

  // This is the endpoint the Flutter background service hits every
  // sync interval. Accepts a batch so queued/offline pings can catch up.
  @Post('sync')
  sync(
    @CurrentUser() user: { riderId: string },
    @Body() dto: SyncLocationBatchDto,
  ) {
    return this.locationService.syncBatch(user.riderId, dto);
  }

  // Client watchdog telemetry: the app reports when the OS has killed the
  // background service repeatedly within one tracking session. Logged for
  // ops visibility (OEM kill-loop detection); no PII beyond the rider id.
  @Post('service-kills')
  reportServiceKills(
    @CurrentUser() user: { riderId: string },
    @Body() dto: { killCount?: number; windowMinutes?: number },
  ) {
    const killCount = dto?.killCount ?? 0;
    const windowMinutes = dto?.windowMinutes ?? 0;
    // Structural validation without a dedicated DTO class: both fields
    // must be non-negative integers when present.
    if (!Number.isInteger(killCount) || killCount < 0 ||
        !Number.isInteger(windowMinutes) || windowMinutes < 0) {
      return { acknowledged: false };
    }
    return this.locationService.logServiceKills(user.riderId, killCount, windowMinutes);
  }

  @Get('order/:orderId/history')
  getOrderHistory(@Param('orderId') orderId: string) {
    return this.locationService.getHistoryForOrder(orderId);
  }

  @Get('rider/:riderId/recent')
  getRiderRecent(@Param('riderId') riderId: string) {
    return this.locationService.getRecentForRider(riderId);
  }
}
