import {
  Controller,
  Post,
  UseInterceptors,
  UploadedFile,
  Body,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { existsSync, mkdirSync } from 'fs';

const UPLOAD_DIR = './uploads';

// Ensure the uploads directory exists at boot
if (!existsSync(UPLOAD_DIR)) {
  mkdirSync(UPLOAD_DIR, { recursive: true });
}

const IMAGE_EXT = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.jfif', '.heic', '.heif', '.bmp', '.svg'];

@Controller('upload')
export class UploadController {
  @Post('image')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: (req, file, cb) => {
          if (!existsSync(UPLOAD_DIR)) mkdirSync(UPLOAD_DIR, { recursive: true });
          cb(null, UPLOAD_DIR);
        },
        filename: (req, file, cb) => {
          // Random-ish unique name, keeps original extension
          const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
          const ext = extname(file.originalname || '').toLowerCase();
          cb(null, `${unique}${ext || '.jpg'}`);
        },
      }),
      limits: { fileSize: 8 * 1024 * 1024 }, // 8 MB max
      fileFilter: (req, file, cb) => {
        const ext = extname(file.originalname || '').toLowerCase();
        // Accept if MIME type starts with image/ OR extension is known.
        // Some Android gallery apps send weird MIME types for .webp/.jfif.
        const okMime = !!file.mimetype && file.mimetype.startsWith('image/');
        const okExt = IMAGE_EXT.includes(ext);
        if (!okMime && !okExt) {
          return cb(
            new HttpException(
              'Only image files are allowed (png, jpg, jpeg, gif, webp, jfif, heic)',
              HttpStatus.BAD_REQUEST,
            ) as any,
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  uploadImage(
    @UploadedFile() file: any,
    @Body() body: { type?: string },
  ) {
    if (!file) {
      throw new HttpException(
        'No image file received',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Folder inside /uploads: menu, logo, or chat (default menu)
    const type = ['menu', 'logo', 'chat'].includes(String(body?.type)) ? String(body?.type) : 'menu';
    const finalDir = `${UPLOAD_DIR}/${type}`;
    if (!existsSync(finalDir)) mkdirSync(finalDir, { recursive: true });
    const fs = require('fs');
    fs.renameSync(`${UPLOAD_DIR}/${file.filename}`, `${finalDir}/${file.filename}`);

    // Public URL the app (and customers) use to load the image
    const url = `/uploads/${type}/${file.filename}`;
    return { url, filename: file.filename, size: file.size };
  }
}
