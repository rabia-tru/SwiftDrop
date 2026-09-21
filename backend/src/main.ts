import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import { existsSync, mkdirSync } from 'fs';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const config = app.get(ConfigService);

  app.enableCors({ origin: '*' });

  // Serve uploaded images statically: /uploads/menu/xxx.jpg, /uploads/logo/xxx.jpg
  const uploadDir = './uploads';
  if (!existsSync(uploadDir)) mkdirSync(uploadDir, { recursive: true });
  app.useStaticAssets(uploadDir, { prefix: '/uploads' });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  app.setGlobalPrefix('api');

  const port = parseInt(process.env.PORT || '3000', 10) || 3000;
  await app.listen(port, '0.0.0.0');
  console.log(`Delivery Tracker API running on http://localhost:${port}/api`);
}
bootstrap();
