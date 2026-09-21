import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterRiderDto, LoginDto } from './dto/auth.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('rider/register')
  register(@Body() dto: RegisterRiderDto) {
    return this.authService.registerRider(dto);
  }

  @Post('rider/login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  forgotPassword(@Body() body: { email: string; role?: string }) {
    return this.authService.forgotPassword(body.email, body.role);
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  resetPassword(@Body() body: { email: string; token: string; newPassword: string; role?: string }) {
    return this.authService.resetPassword(body.email, body.token, body.newPassword, body.role);
  }
}
