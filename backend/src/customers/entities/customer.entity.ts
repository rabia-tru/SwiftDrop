import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('customers')
export class Customer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ unique: true })
  phone: string;

  @Column({ unique: true })
  email: string;

  @Column({ select: false, nullable: true })
  password: string;

  // Social sign-in (Google / Facebook). Null for email-password accounts.
  @Column({ nullable: true })
  socialProvider: string;

  @Column({ nullable: true })
  socialId: string;

  @Column({ nullable: true })
  avatarUrl: string;

  // Default delivery address for the customer (editable from Profile).
  @Column({ nullable: true })
  address: string;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
