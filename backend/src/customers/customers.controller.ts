import { Body, Controller, Get, HttpCode, HttpStatus, Patch, Post, UseGuards } from '@nestjs/common';
import { CustomersService } from './customers.service';
import { RegisterCustomerDto, CustomerLoginDto, SocialLoginDto, UpdateCustomerProfileDto } from './dto/customer.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('customers')
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @Post('register')
  register(@Body() dto: RegisterCustomerDto) {
    return this.customersService.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: CustomerLoginDto) {
    return this.customersService.login(dto);
  }

  @Post('social')
  @HttpCode(HttpStatus.OK)
  socialLogin(@Body() dto: SocialLoginDto) {
    return this.customersService.socialLogin(dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  getMe(@CurrentUser() user: { riderId: string }) {
    return this.customersService.getProfile(user.riderId);
  }

  @Patch('me')
  @UseGuards(JwtAuthGuard)
  updateMe(
    @CurrentUser() user: { riderId: string },
    @Body() dto: UpdateCustomerProfileDto,
  ) {
    return this.customersService.updateProfile(user.riderId, dto);
  }
}
