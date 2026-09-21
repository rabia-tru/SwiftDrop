import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { RiderStatus } from '../../common/enums';
import { Order } from '../../orders/entities/order.entity';

@Entity('riders')
export class Rider {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ unique: true })
  phone: string;

  @Column({ unique: true })
  email: string;

  // select: false means password is never returned by default queries
  // (find, findOne, relations) — must be explicitly selected when needed,
  // e.g. login. This prevents accidental leaks like in order.rider responses.
  @Column({ select: false })
  password: string;

  @Column({ nullable: true })
  vehicleType: string; // bike, car, van

  @Column({ nullable: true })
  vehiclePlateNumber: string;

  @Column({
    type: 'enum',
    enum: RiderStatus,
    default: RiderStatus.OFFLINE,
  })
  status: RiderStatus;

  @Column({ type: 'double precision', nullable: true })
  lastKnownLat: number;

  @Column({ type: 'double precision', nullable: true })
  lastKnownLng: number;

  @Column({ type: 'timestamptz', nullable: true })
  lastLocationAt: Date;

  @Column({ default: true })
  isActive: boolean;

  @OneToMany(() => Order, (order) => order.rider)
  orders: Order[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
