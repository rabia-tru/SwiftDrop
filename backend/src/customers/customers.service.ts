import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { Customer } from './entities/customer.entity';
import { RegisterCustomerDto, CustomerLoginDto, SocialLoginDto } from './dto/customer.dto';
import { UserRole } from '../common/enums';

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer)
    private customerRepository: Repository<Customer>,
    private jwtService: JwtService,
  ) {}

  async register(dto: RegisterCustomerDto) {
    const existing = await this.customerRepository.findOne({
      where: [{ email: dto.email }, { phone: dto.phone }],
    });
    if (existing) {
      throw new ConflictException('Customer with this email or phone already exists');
    }

    const hashedPassword = await bcrypt.hash(dto.password, 10);
    const customer = this.customerRepository.create({
      ...dto,
      password: hashedPassword,
    });
    const saved = await this.customerRepository.save(customer);

    return this.buildAuthResponse(saved);
  }

  async login(dto: CustomerLoginDto) {
    const customer = await this.customerRepository.findOne({
      where: { email: dto.email },
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        password: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!customer) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const passwordMatches = await bcrypt.compare(dto.password, customer.password ?? '');
    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!customer.isActive) {
      throw new UnauthorizedException('Account is deactivated');
    }

    return this.buildAuthResponse(customer);
  }

  /**
   * Google / Facebook sign-in. If the email already exists as an
   * email-password account we LINK the social identity to it (same person,
   * one account). Otherwise we create the account instantly.
   */
  async socialLogin(dto: SocialLoginDto) {
    let customer = await this.customerRepository.findOne({
      where: { email: dto.email },
    });

    if (!customer) {
      // New social user — create account (no password needed)
      customer = this.customerRepository.create({
        name: dto.name,
        email: dto.email,
        phone: dto.phone ?? this.generatePlaceholderPhone(),
        socialProvider: dto.provider,
        socialId: dto.socialId,
        avatarUrl: dto.avatarUrl,
      });
      customer = await this.customerRepository.save(customer);
    } else {
      // Existing account — link social identity if not already linked
      if (!customer.socialProvider) {
        customer.socialProvider = dto.provider;
        customer.socialId = dto.socialId;
        customer.avatarUrl = dto.avatarUrl ?? customer.avatarUrl;
        await this.customerRepository.save(customer);
      }
      if (!customer.isActive) {
        throw new UnauthorizedException('Account is deactivated');
      }
    }

    return this.buildAuthResponse(customer);
  }

  /** Unique placeholder phone for social users who haven't shared one. */
  private generatePlaceholderPhone(): string {
    return `social_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
  }

  async getProfile(customerId: string) {
    const customer = await this.customerRepository.findOne({
      where: { id: customerId },
    });
    if (!customer) {
      throw new UnauthorizedException('Customer not found');
    }
    const { password, ...customerData } = customer;
    return customerData;
  }

  async updateProfile(
    customerId: string,
    updates: { name?: string; phone?: string; address?: string },
  ) {
    try {
      await this.customerRepository.update(customerId, updates);
    } catch {
      throw new ConflictException(
        'This phone number is already registered to another account',
      );
    }
    const customer = await this.customerRepository.findOne({
      where: { id: customerId },
    });
    if (!customer) {
      throw new UnauthorizedException('Customer not found');
    }
    const { password, ...customerData } = customer;
    return customerData;
  }

  private buildAuthResponse(customer: Customer) {
    const payload = {
      sub: customer.id,
      email: customer.email,
      role: UserRole.CUSTOMER,
    };
    const accessToken = this.jwtService.sign(payload);

    const { password, ...customerData } = customer;

    return {
      accessToken,
      customer: customerData,
    };
  }
}
