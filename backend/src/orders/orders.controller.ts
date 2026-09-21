import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { OrdersService } from './orders.service';
import {
  AssignOrderDto,
  CreateOrderDto,
  UpdateOrderAddressDto,
  UpdateOrderStatusDto,
} from './dto/order.dto';
import { OrderStatus } from '../common/enums';

@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  // Admin / demo: create any order
  @Post()
  create(@Body() dto: CreateOrderDto) {
    return this.ordersService.create(dto);
  }

  // Customer: create order linked to their account
  @Post('customer')
  createForCustomer(
    @CurrentUser() user: { riderId: string },
    @Body() dto: CreateOrderDto,
  ) {
    return this.ordersService.createForCustomer(dto, user.riderId);
  }

  // Customer: view their own orders
  @Get('customer/mine')
  findForCustomer(@CurrentUser() user: { riderId: string }) {
    return this.ordersService.findForCustomer(user.riderId);
  }

  // Business: view only THIS business's orders
  @Get('business/mine')
  findForBusiness(@CurrentUser() user: { riderId: string }) {
    return this.ordersService.findForBusiness(user.riderId);
  }

  @Get()
  findAll() {
    return this.ordersService.findAll();
  }

  @Get('mine')
  findMine(@CurrentUser() user: { riderId: string }) {
    return this.ordersService.findForRider(user.riderId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.ordersService.findOne(id);
  }

  @Patch(':id/assign')
  assign(@Param('id') id: string, @Body() dto: AssignOrderDto) {
    return this.ordersService.assignRider(id, dto.riderId);
  }

  @Patch(':id/accept')
  accept(@Param('id') id: string, @CurrentUser() user: { riderId: string }) {
    return this.ordersService.updateStatus(id, { status: OrderStatus.ACCEPTED });
  }

  // Business confirms it will prepare this order — separate from the
  // rider's /accept above. See businessAccept() in the service for why.
  @Patch(':id/business-accept')
  businessAccept(@Param('id') id: string) {
    return this.ordersService.businessAccept(id);
  }

  @Patch(':id/address')
  updateAddress(@Param('id') id: string, @Body() dto: UpdateOrderAddressDto) {
    return this.ordersService.updateDropAddress(id, dto.dropAddress);
  }

  @Patch(':id/status')
  updateStatus(@Param('id') id: string, @Body() dto: UpdateOrderStatusDto) {
    return this.ordersService.updateStatus(id, dto);
  }
}