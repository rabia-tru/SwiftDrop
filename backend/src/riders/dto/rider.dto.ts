import { IsEnum, IsNumber, IsOptional, IsString } from 'class-validator';
import { RiderStatus } from '../../common/enums';

export class UpdateRiderStatusDto {
  @IsEnum(RiderStatus)
  status: RiderStatus;
}

export class UpdateRiderLocationDto {
  @IsNumber()
  latitude: number;

  @IsNumber()
  longitude: number;
}

export class UpdateRiderProfileDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  vehicleType?: string;

  @IsOptional()
  @IsString()
  vehiclePlateNumber?: string;
}
