import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

/**
 * A single chat message exchanged inside an order room
 * between the customer and the assigned rider.
 */
@Entity('chat_messages')
@Index(['orderId', 'createdAt'])
export class ChatMessage {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Order this message belongs to — chat room key */
  @Column('uuid')
  @Index()
  orderId: string;

  /** 'customer' | 'rider' */
  @Column('varchar', { length: 20 })
  senderRole: string;

  /** Display name of the sender at send time */
  @Column('varchar', { length: 120, nullable: true })
  senderName: string;

  @Column('text')
  message: string;

  /**
   * Optional image attached to this message (e.g. delivery photo from
   * rider, receipt from customer). Server-relative URL like
   * `/uploads/chat/xxx.jpg` — clients resolve it against the API origin.
   */
  @Column('varchar', { length: 500, nullable: true })
  imageUrl: string;

  @CreateDateColumn()
  createdAt: Date;
}
