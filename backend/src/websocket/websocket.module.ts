import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LocationGateway } from './location.gateway';
import { ChatMessage } from '../chat/entities/chat-message.entity';
import { ChatModule } from '../chat/chat.module';
import { LocationLog } from '../location/entities/location-log.entity';
import { ServiceReviveService } from '../location/service-revive.service';

@Module({
  // LocationLog repo lives here (not just LocationModule) because the
  // ServiceReviveService is provided HERE, next to its only consumer
  // (LocationGateway). Providing it from LocationModule instead would
  // force WebsocketModule ↔ LocationModule — a module cycle that needs
  // forwardRef; hosting it here keeps the graph acyclic.
  imports: [TypeOrmModule.forFeature([ChatMessage, LocationLog]), ChatModule],
  providers: [LocationGateway, ServiceReviveService],
  exports: [LocationGateway],
})
export class WebsocketModule {}
