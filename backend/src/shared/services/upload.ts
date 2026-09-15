import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { config } from '@shared/config';
import { UploadResult } from '@shared/types';
import fs from 'fs';

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    const dir = config.upload.dir;
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname);
    const name = `${uuidv4()}${ext}`;
    cb(null, name);
  },
});

const fileFilter = (_req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowedMimes = [
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    'application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain', 'text/csv',
  ];
  if (allowedMimes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`File type ${file.mimetype} not allowed`));
  }
};

export const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: config.upload.maxFileSize,
  },
});

export function processUploadResult(file: Express.Multer.File): UploadResult {
  return {
    url: `/uploads/${file.filename}`,
    filename: file.filename,
    mimeType: file.mimetype,
    size: file.size,
  };
}
