import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { OrderStatus } from '../../common/enums';
import { Rider } from '../../riders/entities/rider.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { OrderStatusHistory } from './order-status-history.entity';

@Entity('orders')
export class Order {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  customerName: string;

  @Column()
  customerPhone: string;

  @Column()
  pickupAddress: string;

  @Column({ type: 'double precision' })
  pickupLat: number;

  @Column({ type: 'double precision' })
  pickupLng: number;

  @Column()
  dropAddress: string;

  @Column({ type: 'double precision' })
  dropLat: number;

  @Column({ type: 'double precision' })
  dropLng: number;

  @Column({
    type: 'enum',
    enum: OrderStatus,
    default: OrderStatus.PENDING,
  })
  status: OrderStatus;

  @ManyToOne(() => Rider, (rider) => rider.orders, { nullable: true })
  @JoinColumn({ name: 'riderId' })
  rider: Rider;

  @Column({ nullable: true })
  riderId: string;

  @ManyToOne(() => Customer, { nullable: true })
  @JoinColumn({ name: 'customerId' })
  customer: Customer;

  @Column({ nullable: true })
  customerId: string;

  @Column({ nullable: true, type: 'text' })
  notes: string;

  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  fare: number;

  // Business has confirmed / accepted this order for preparation. This is
  // deliberately separate from `status` — the rider pipeline's ACCEPTED
  // status already means "rider accepted the assigned delivery", so
  // reusing it for "business confirmed the order" made the two actions
  // collide (whichever side tapped Accept first silently overwrote the
  // other's step, and it also blocked accepting a still-PENDING order
  // since PENDING can't transition straight to ACCEPTED).
  @Column({ default: false })
  businessConfirmed: boolean;

  @Column({ nullable: true })
  businessConfirmedAt: Date;

  // Business marked the food as PREPARED and the rider has been told to
  // come pick it up. Distinct from businessConfirmed: that means "we took
  // the order", this means "the rider's food is ready NOW".
  @Column({ type: 'timestamptz', nullable: true, default: null })
  readyNotifiedAt: Date;

  // ─── Business link: which restaurant/store this order belongs to ───
  @Column({ nullable: true })
  businessId: string;

  @Column({ nullable: true })
  businessName: string;

  // Ordered items snapshot (name, qty, price at purchase time)
  @Column({ nullable: true, type: 'jsonb' })
  items: { name: string; quantity: number; price: number }[];

  // Payment method chosen by the customer
  @Column({ nullable: true })
  paymentMethod: string;

  @OneToMany(() => OrderStatusHistory, (history) => history.order)
  statusHistory: OrderStatusHistory[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}