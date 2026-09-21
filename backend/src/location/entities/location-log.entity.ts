import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('location_logs')
@Index(['riderId', 'createdAt'])
export class LocationLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  riderId: string;

  @Column({ type: 'double precision' })
  latitude: number;

  @Column({ type: 'double precision' })
  longitude: number;

  @Column({ type: 'double precision', nullable: true })
  speed: number; // meters/sec, useful for adaptive sampling later

  @Column({ type: 'double precision', nullable: true })
  accuracy: number;

  @Column({ nullable: true })
  orderId: string; // if rider was on an active delivery when this ping happened

  @Column({ type: 'timestamptz' })
  recordedAt: Date; // timestamp from device (not server receive time)

  @CreateDateColumn()
  createdAt: Date; // server receive time
}
