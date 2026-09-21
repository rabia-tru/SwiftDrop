import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatMessage } from './entities/chat-message.entity';

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(ChatMessage)
    private readonly chatRepo: Repository<ChatMessage>,
  ) {}

  /** Persist a chat message. Returns the saved row. */
  async save(dto: {
    orderId: string;
    senderRole: string;
    senderName?: string | null;
    message: string;
    imageUrl?: string | null;
  }): Promise<ChatMessage> {
    const msg = new ChatMessage();
    msg.orderId = dto.orderId;
    msg.senderRole = dto.senderRole;
    msg.senderName = dto.senderName ?? null as any;
    msg.message = dto.message;
    msg.imageUrl = dto.imageUrl ?? null as any;
    return this.chatRepo.save(msg);
  }

  /** Full history for an order, oldest first. */
  async historyForOrder(orderId: string): Promise<ChatMessage[]> {
    return this.chatRepo.find({
      where: { orderId },
      order: { createdAt: 'ASC' },
    });
  }

  /** Validate that the order exists before accepting messages for it. */
  async assertOrderExists(orderId: string): Promise<void> {
    const found = await this.chatRepo.manager
      .getRepository('Order')
      .findOne({ where: { id: orderId } });
    if (!found) throw new NotFoundException('Order not found');
  }
}
