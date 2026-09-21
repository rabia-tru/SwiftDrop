import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LocationLog } from './entities/location-log.entity';
import { LocationService } from './location.service';
import { LocationController } from './location.controller';
import { RidersModule } from '../riders/riders.module';
import { WebsocketModule } from '../websocket/websocket.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([LocationLog]),
    RidersModule,
    WebsocketModule,
    AuthModule,
  ],
  controllers: [LocationController],
  providers: [LocationService],
})
export class LocationModule {}
