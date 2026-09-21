import {
  ConflictException,
  Injectable,
  UnauthorizedException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Raw } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import * as nodemailer from 'nodemailer';
import { Rider } from '../riders/entities/rider.entity';
import { Customer } from '../customers/entities/customer.entity';
import { Business } from '../businesses/entities/business.entity';
import { RegisterRiderDto, LoginDto } from './dto/auth.dto';
import { UserRole } from '../common/enums';

// Simple in-memory token store (in production, use Redis or DB)
const resetTokens = new Map<string, { token: string; expires: number }>();

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(Rider)
    private riderRepository: Repository<Rider>,
    @InjectRepository(Customer)
    private customerRepository: Repository<Customer>,
    @InjectRepository(Business)
    private businessRepository: Repository<Business>,
    private jwtService: JwtService,
  ) {}

  async registerRider(dto: RegisterRiderDto) {
    const existing = await this.riderRepository.findOne({
      where: [{ email: dto.email }, { phone: dto.phone }],
    });
    if (existing) {
      throw new ConflictException('Rider with this email or phone already exists');
    }

    const hashedPassword = await bcrypt.hash(dto.password, 10);

    const rider = this.riderRepository.create({
      ...dto,
      password: hashedPassword,
    });
    const saved = await this.riderRepository.save(rider);

    return this.buildAuthResponse(saved);
  }

  async login(dto: LoginDto) {
    const rider = await this.riderRepository.findOne({
      where: { email: dto.email },
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        password: true, // explicitly needed here to verify the login
        vehicleType: true,
        vehiclePlateNumber: true,
        status: true,
        lastKnownLat: true,
        lastKnownLng: true,
        lastLocationAt: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!rider) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const passwordMatches = await bcrypt.compare(dto.password, rider.password);
    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!rider.isActive) {
      throw new UnauthorizedException('Account is deactivated');
    }

    return this.buildAuthResponse(rider);
  }

  // ── Forgot Password ────────────────────────────────────────

  /**
   * Gmail SMTP transporter — creds come from .env (SMTP_USER/SMTP_PASS).
   * Created lazily on first use so a missing/unreachable SMTP server
   * never blocks app startup.
   */
  private mailer: nodemailer.Transporter | null = null;

  private getMailer(): nodemailer.Transporter {
    if (!this.mailer) {
      this.mailer = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.SMTP_USER || 'your-email@gmail.com',
          pass: process.env.SMTP_PASS || '',
        },
      });
    }
    return this.mailer;
  }

  private async sendResetCodeEmail(email: string, code: string): Promise<boolean> {
    try {
      await this.getMailer().sendMail({
        from: `"SwiftDrop" <${process.env.SMTP_USER || 'your-email@gmail.com'}>`,
        to: email,
        subject: `SwiftDrop Password Reset Code: ${code}`,
        html: `
          <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;">
            <h2 style="color:#FF6D00;margin:0 0 8px;">SwiftDrop</h2>
            <p style="color:#555;">Your password reset code is:</p>
            <div style="background:#FFF3E0;border-radius:12px;padding:16px;text-align:center;margin:16px 0;">
              <span style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#FF6D00;">${code}</span>
            </div>
            <p style="color:#888;font-size:13px;">This code expires in 15 minutes. If you didn't request a password reset, you can safely ignore this email.</p>
          </div>`,
      });
      return true;
    } catch (e) {
      console.error('[ForgotPassword] Email send failed:', (e as Error).message);
      return false;
    }
  }

  async forgotPassword(email: string, role?: string) {
    const normalized = (email || '').trim().toLowerCase();
    if (!normalized || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalized)) {
      throw new BadRequestException('Please enter a valid email address');
    }

    // Verify the account actually exists for this role — otherwise the
    // user waits for an email that can never arrive. Emails are matched
    // case-insensitively (DB may store mixed case).
    const findAccount = () => {
      switch (role) {
        case 'customer':
          return this.customerRepository.findOne({
            where: { email: Raw((a) => `LOWER(${a}) = :e`, { e: normalized }) },
          });
        case 'business':
          return this.businessRepository.findOne({
            where: { email: Raw((a) => `LOWER(${a}) = :e`, { e: normalized }) },
          });
        default:
          return this.riderRepository.findOne({
            where: { email: Raw((a) => `LOWER(${a}) = :e`, { e: normalized }) },
          });
      }
    };
    const account = await findAccount();
    if (!account) {
      const roleLabel = role === 'customer' ? 'customer' : role === 'business' ? 'business' : 'rider';
      throw new NotFoundException(`No ${roleLabel} account found with this email`);
    }

    // Generate a 6-digit reset code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const key = `${normalized}:${role || 'rider'}`;

    // Store with 15 min expiry
    resetTokens.set(key, {
      token: code,
      expires: Date.now() + 15 * 60 * 1000,
    });

    // Send the real email
    const sent = await this.sendResetCodeEmail(normalized, code);

    return {
      message: sent
        ? 'Reset code sent to your email'
        : 'Could not send email right now — use the demo code shown below',
      // Only exposed when the email could NOT be delivered (local dev /
      // no internet) so the flow remains testable. Never leaks the code
      // when the email went out.
      ...(sent ? {} : { _devCode: code }),
    };
  }

  async resetPassword(email: string, token: string, newPassword: string, role?: string) {
    const normalized = (email || '').trim().toLowerCase();
    if (!newPassword || newPassword.length < 6) {
      throw new BadRequestException('Password must be at least 6 characters');
    }

    const key = `${normalized}:${role || 'rider'}`;
    const stored = resetTokens.get(key);

    if (!stored) {
      throw new UnauthorizedException('No reset request found. Please request a new code.');
    }

    if (stored.expires < Date.now()) {
      resetTokens.delete(key);
      throw new UnauthorizedException('Reset code expired. Please request a new one.');
    }

    if (stored.token !== token) {
      throw new UnauthorizedException('Invalid reset code');
    }

    // Hash new password and update by the account's ID (works even when
    // the DB stores the email in different case than typed).
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    if (role === 'customer') {
      const acc = await this.customerRepository.findOne({ where: { email: Raw((a) => `LOWER(${a}) = :e`, { e: normalized }) } });
      if (acc) await this.customerRepository.update(acc.id, { password: hashedPassword } as any);
    } else if (role === 'business') {
      const acc = await this.businessRepository.findOne({ where: { email: Raw((a) => `LOWER(${a}) = :e`, { e: normalized }) } });
      if (acc) await this.businessRepository.update(acc.id, { password: hashedPassword } as any);
    } else {
      const acc = await this.riderRepository.findOne({ where: { email: Raw((a) => `LOWER(${a}) = :e`, { e: normalized }) } });
      if (acc) await this.riderRepository.update(acc.id, { password: hashedPassword } as any);
    }

    // Clean up token
    resetTokens.delete(key);

    return { message: 'Password reset successful. You can now login with your new password.' };
  }

  private buildAuthResponse(rider: Rider) {
    const payload = {
      sub: rider.id,
      email: rider.email,
      role: UserRole.RIDER,
    };
    const accessToken = this.jwtService.sign(payload);

    const { password, ...riderData } = rider;

    return {
      accessToken,
      rider: riderData,
    };
  }
}
