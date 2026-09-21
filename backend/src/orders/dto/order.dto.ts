import {
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';
import { OrderStatus } from '../../common/enums';

export class OrderItemDto {
  @IsString()
  name: string;

  @IsNumber()
  quantity: number;

  @IsNumber()
  price: number;
}

export class CreateOrderDto {
  @IsNotEmpty()
  @IsString()
  customerName: string;

  @IsNotEmpty()
  @IsString()
  customerPhone: string;

  @IsNotEmpty()
  @IsString()
  pickupAddress: string;

  @IsNumber()
  pickupLat: number;

  @IsNumber()
  pickupLng: number;

  @IsNotEmpty()
  @IsString()
  dropAddress: string;

  @IsNumber()
  dropLat: number;

  @IsNumber()
  dropLng: number;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsNumber()
  fare?: number;

  @IsOptional()
  @IsString()
  businessId?: string;

  @IsOptional()
  @IsString()
  businessName?: string;

  @IsOptional()
  @IsArray()
  items?: OrderItemDto[];

  @IsOptional()
  @IsString()
  paymentMethod?: string;
}

export class AssignOrderDto {
  @IsNotEmpty()
  @IsString()
  riderId: string;
}

export class UpdateOrderStatusDto {
  @IsEnum(OrderStatus)
  status: OrderStatus;

  @IsOptional()
  @IsString()
  note?: string;
}

export class UpdateOrderAddressDto {
  @IsNotEmpty()
  @IsString()
  dropAddress: string;
}
