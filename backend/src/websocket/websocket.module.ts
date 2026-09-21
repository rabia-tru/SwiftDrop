import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LocationGateway } from './location.gateway';
import { ChatMessage } from '../chat/entities/chat-message.entity';
import { ChatModule } from '../chat/chat.module';

@Module({
  imports: [TypeOrmModule.forFeature([ChatMessage]), ChatModule],
  providers: [LocationGateway],
  exports: [LocationGateway],
})
export class WebsocketModule {}
