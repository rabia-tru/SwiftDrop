import {
  Body,
  Controller,
  Get,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { RidersService } from './riders.service';
import { UpdateRiderStatusDto, UpdateRiderProfileDto } from './dto/rider.dto';

@Controller('riders')
@UseGuards(JwtAuthGuard)
export class RidersController {
  constructor(private readonly ridersService: RidersService) {}

  @Get('me')
  getMe(@CurrentUser() user: { riderId: string }) {
    return this.ridersService.me(user.riderId);
  }

  @Patch('me/status')
  updateStatus(
    @CurrentUser() user: { riderId: string },
    @Body() dto: UpdateRiderStatusDto,
  ) {
    return this.ridersService.updateStatus(user.riderId, dto.status);
  }

  @Patch('me/profile')
  updateProfile(
    @CurrentUser() user: { riderId: string },
    @Body() dto: UpdateRiderProfileDto,
  ) {
    return this.ridersService.updateProfile(user.riderId, dto);
  }

  @Get('online')
  getOnlineRiders() {
    return this.ridersService.findAllOnline();
  }
}
