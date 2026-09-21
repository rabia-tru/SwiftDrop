import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { LocationService } from './location.service';
import { SyncLocationBatchDto } from './dto/location.dto';

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

  @Get('order/:orderId/history')
  getOrderHistory(@Param('orderId') orderId: string) {
    return this.locationService.getHistoryForOrder(orderId);
  }

  @Get('rider/:riderId/recent')
  getRiderRecent(@Param('riderId') riderId: string) {
    return this.locationService.getRecentForRider(riderId);
  }
}
