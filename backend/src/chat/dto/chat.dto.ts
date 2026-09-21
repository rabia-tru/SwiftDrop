import {
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class SendChatMessageDto {
  @IsNotEmpty()
  @IsString()
  orderId: string;

  @IsNotEmpty()
  @IsString()
  @MaxLength(2000)
  message: string;

  @IsIn(['customer', 'rider'])
  senderRole: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  senderName?: string;

  /** Optional attached image (server-relative /uploads/... URL) */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  imageUrl?: string;
}
