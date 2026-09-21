import {
  IsArray,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class LocationPingDto {
  @IsNumber()
  latitude: number;

  @IsNumber()
  longitude: number;

  @IsOptional()
  @IsNumber()
  speed?: number;

  @IsOptional()
  @IsNumber()
  accuracy?: number;

  @IsOptional()
  @IsString()
  orderId?: string;

  @IsDateString()
  recordedAt: string;
}

// Rider app queues pings locally (SQLite) when offline, then batch-uploads
// this array once network is back. This is the key to "no data loss".
export class SyncLocationBatchDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => LocationPingDto)
  pings: LocationPingDto[];
}
