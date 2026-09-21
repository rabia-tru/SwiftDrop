import { Body, Controller, Get, Post, Patch, Delete, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { BusinessService } from './business.service';
import { RegisterBusinessDto, LoginBusinessDto, UpdateBusinessDto, CreateMenuItemDto, UpdateMenuItemDto } from './dto/business.dto';

@Controller('business')
export class BusinessController {
  constructor(private readonly businessService: BusinessService) {}

  // ── Auth (public) ──────────────────────────────────────────

  @Post('register')
  register(@Body() dto: RegisterBusinessDto) {
    return this.businessService.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginBusinessDto) {
    return this.businessService.login(dto);
  }

  // ── Profile ────────────────────────────────────────────────

  @Get('me')
  @UseGuards(JwtAuthGuard)
  getProfile(@CurrentUser() user: { sub: string }) {
    return this.businessService.getProfile(user.sub);
  }

  @Patch('me')
  @UseGuards(JwtAuthGuard)
  updateProfile(@CurrentUser() user: { sub: string }, @Body() dto: UpdateBusinessDto) {
    return this.businessService.updateProfile(user.sub, dto);
  }

  @Get('me/stats')
  @UseGuards(JwtAuthGuard)
  getStats(@CurrentUser() user: { sub: string }) {
    return this.businessService.getStats(user.sub);
  }

  // ── Menu Items ─────────────────────────────────────────────

  @Get('me/menu')
  @UseGuards(JwtAuthGuard)
  getMenu(@CurrentUser() user: { sub: string }) {
    return this.businessService.getMenuItems(user.sub);
  }

  @Post('me/menu')
  @UseGuards(JwtAuthGuard)
  addMenuItem(@CurrentUser() user: { sub: string }, @Body() dto: CreateMenuItemDto) {
    return this.businessService.addMenuItem(user.sub, dto);
  }

  @Patch('me/menu/:itemId')
  @UseGuards(JwtAuthGuard)
  updateMenuItem(
    @CurrentUser() user: { sub: string },
    @Param('itemId') itemId: string,
    @Body() dto: UpdateMenuItemDto,
  ) {
    return this.businessService.updateMenuItem(itemId, user.sub, dto);
  }

  @Delete('me/menu/:itemId')
  @UseGuards(JwtAuthGuard)
  deleteMenuItem(@CurrentUser() user: { sub: string }, @Param('itemId') itemId: string) {
    return this.businessService.deleteMenuItem(itemId, user.sub);
  }

  @Patch('me/menu/:itemId/toggle')
  @UseGuards(JwtAuthGuard)
  toggleAvailability(@CurrentUser() user: { sub: string }, @Param('itemId') itemId: string) {
    return this.businessService.toggleAvailability(itemId, user.sub);
  }

  // ── Public: View all businesses (for customers) ─────────────

  @Get('list')
  listAllBusinesses() {
    return this.businessService.listAllBusinesses();
  }

  @Get(':id/menu')
  getPublicMenu(@Param('id') id: string) {
    return this.businessService.getMenuItems(id);
  }
}
