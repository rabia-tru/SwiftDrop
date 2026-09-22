import { Injectable, ConflictException, UnauthorizedException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { Business } from './entities/business.entity';
import { MenuItem } from './entities/menu-item.entity';
import { RegisterBusinessDto, LoginBusinessDto, UpdateBusinessDto, CreateMenuItemDto, UpdateMenuItemDto } from './dto/business.dto';
import { LocationGateway } from '../websocket/location.gateway';

@Injectable()
export class BusinessService {
  constructor(
    @InjectRepository(Business)
    private businessRepo: Repository<Business>,
    @InjectRepository(MenuItem)
    private menuItemRepo: Repository<MenuItem>,
    private jwtService: JwtService,
    private locationGateway: LocationGateway,
  ) {}

  async register(dto: RegisterBusinessDto) {
    // Check duplicate email/phone
    const exists = await this.businessRepo.findOne({
      where: [{ email: dto.email }, { phone: dto.phone }],
    });
    if (exists) {
      throw new ConflictException('Business with this email or phone already exists');
    }

    const hashedPassword = await bcrypt.hash(dto.password, 10);
    const business = this.businessRepo.create({ ...dto, password: hashedPassword });
    const saved = await this.businessRepo.save(business);

    // Tell every connected customer so their home screens show the new
    // restaurant live (no app restart needed).
    this.locationGateway.broadcastNewBusiness(saved);

    const token = this.jwtService.sign({
      sub: saved.id,
      email: saved.email,
      role: 'business',
    });

    const { password, ...result } = saved;
    return { accessToken: token, business: result };
  }

  async login(dto: LoginBusinessDto) {
    const business = await this.businessRepo
      .createQueryBuilder('b')
      .addSelect('b.password')
      .where('b.email = :email', { email: dto.email })
      .getOne();
    if (!business) {
      throw new UnauthorizedException('No business found with this email');
    }

    const valid = await bcrypt.compare(dto.password, business.password);
    if (!valid) {
      throw new UnauthorizedException('Incorrect password');
    }

    const token = this.jwtService.sign({
      sub: business.id,
      email: business.email,
      role: 'business',
    });

    const { password, ...result } = business;
    return { accessToken: token, business: result };
  }

  async getProfile(businessId: string) {
    const business = await this.businessRepo.findOne({ where: { id: businessId } });
    if (!business) throw new NotFoundException('Business not found');
    return business;
  }

  async updateProfile(businessId: string, dto: UpdateBusinessDto) {
    await this.businessRepo.update(businessId, dto);
    return this.getProfile(businessId);
  }

  // ── Menu Items ──────────────────────────────────────────────

  async getMenuItems(businessId: string) {
    return this.menuItemRepo.find({
      where: { businessId },
      order: { category: 'ASC', name: 'ASC' },
    });
  }

  async addMenuItem(businessId: string, dto: CreateMenuItemDto) {
    const item = this.menuItemRepo.create({ ...dto, businessId });
    const saved = await this.menuItemRepo.save(item);
    this.locationGateway.broadcastMenuUpdated(businessId);
    return saved;
  }

  async updateMenuItem(itemId: string, businessId: string, dto: UpdateMenuItemDto) {
    const item = await this.menuItemRepo.findOne({ where: { id: itemId, businessId } });
    if (!item) throw new NotFoundException('Menu item not found');
    Object.assign(item, dto);
    const saved = await this.menuItemRepo.save(item);
    this.locationGateway.broadcastMenuUpdated(businessId);
    return saved;
  }

  async deleteMenuItem(itemId: string, businessId: string) {
    const item = await this.menuItemRepo.findOne({ where: { id: itemId, businessId } });
    if (!item) throw new NotFoundException('Menu item not found');
    await this.menuItemRepo.remove(item);
    this.locationGateway.broadcastMenuUpdated(businessId);
    return { deleted: true };
  }

  async toggleAvailability(itemId: string, businessId: string) {
    const item = await this.menuItemRepo.findOne({ where: { id: itemId, businessId } });
    if (!item) throw new NotFoundException('Menu item not found');
    item.isAvailable = !item.isAvailable;
    const saved = await this.menuItemRepo.save(item);
    this.locationGateway.broadcastMenuUpdated(businessId);
    return saved;
  }

  // ── Public: List all businesses ────────────────────────────

  async listAllBusinesses() {
    const businesses = await this.businessRepo.find({
      order: { name: 'ASC' },
    });

    // Attach menu items and stats for each business
    const results = await Promise.all(
      businesses.map(async (biz) => {
        const menuItems = await this.menuItemRepo.find({
          where: { businessId: biz.id, isAvailable: true },
          order: { category: 'ASC', name: 'ASC' },
        });
        return {
          ...biz,
          menuItems,
          menuItemCount: menuItems.length,
        };
      }),
    );

    return results;
  }

  // ── Stats ──────────────────────────────────────────────────

  async getStats(businessId: string) {
    const business = await this.businessRepo.findOne({ where: { id: businessId } });
    const menuCount = await this.menuItemRepo.count({ where: { businessId } });
    const availableCount = await this.menuItemRepo.count({ where: { businessId, isAvailable: true } });

    return {
      totalOrders: business?.totalOrders || 0,
      totalRevenue: business?.totalRevenue || 0,
      menuItems: menuCount,
      availableItems: availableCount,
      isOpen: business?.isOpen || false,
    };
  }
}