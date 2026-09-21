import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
} from '@nestjs/common';
import { ChatService } from './chat.service';
import { SendChatMessageDto } from './dto/chat.dto';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * REST endpoints for chat history persistence.
 * Live delivery happens over WebSocket (see LocationGateway);
 * this controller only handles the history read/write.
 */
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  /** Fetch persisted chat history for an order (oldest first). */
  @Get('order/:orderId')
  async history(@Param('orderId') orderId: string) {
    if (!UUID_RE.test(orderId)) {
      throw new BadRequestException('Invalid order id');
    }
    return this.chatService.historyForOrder(orderId);
  }

  /** Save a message via REST (used as a fallback when WS is down). */
  @Post('send')
  async send(@Body() dto: SendChatMessageDto) {
    if (!UUID_RE.test(dto.orderId)) {
      throw new BadRequestException('Invalid order id');
    }
    await this.chatService.assertOrderExists(dto.orderId);
    return this.chatService.save({
      orderId: dto.orderId,
      senderRole: dto.senderRole,
      senderName: dto.senderName,
      message: dto.message,
      imageUrl: dto.imageUrl,
    });
  }
}
