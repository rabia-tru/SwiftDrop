import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { MenuItem } from './menu-item.entity';

@Entity('businesses')
export class Business {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ unique: true })
  phone: string;

  @Column({ unique: true })
  email: string;

  @Column({ select: false })
  password: string;

  @Column({ nullable: true })
  category: string; // restaurant, grocery, pharmacy, bakery, etc.

  @Column({ nullable: true })
  address: string;

  @Column({ type: 'double precision', nullable: true })
  latitude: number;

  @Column({ type: 'double precision', nullable: true })
  longitude: number;

  @Column({ nullable: true })
  logoUrl: string;

  @Column({ nullable: true })
  description: string;

  @Column({ nullable: true })
  openingHours: string; // e.g. "9:00 AM - 10:00 PM"

  @Column({ default: true })
  isOpen: boolean; // Currently accepting orders

  @Column({ default: true })
  isActive: boolean;

  @Column({ default: 0 })
  totalOrders: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0 })
  totalRevenue: number;

  @OneToMany(() => MenuItem, (item) => item.business, { cascade: true })
  menuItems: MenuItem[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
