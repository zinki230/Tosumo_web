import { v4 as uuidv4 } from 'uuid';
import { config } from '@shared/config';

export function generateId(): string {
  return uuidv4();
}

export function generateCardNumber(): string {
  const prefix = 'TOS';
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `${prefix}-${timestamp}-${random}`;
}

export function generateNfcUid(): string {
  const hex = '0123456789ABCDEF';
  let uid = '04';
  for (let i = 0; i < 6; i++) {
    uid += hex[Math.floor(Math.random() * 16)];
  }
  return uid;
}

export function calculatePagination(page: number = 1, limit: number = 20) {
  const safePage = Math.max(1, page);
  const safeLimit = Math.min(Math.max(1, limit), 100);
  const skip = (safePage - 1) * safeLimit;
  return { skip, take: safeLimit, page: safePage, limit: safeLimit };
}

export function buildPaginationResult<T>(
  data: T[],
  total: number,
  page: number,
  limit: number,
) {
  const totalPages = Math.ceil(total / limit);
  return {
    data,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNext: page < totalPages,
      hasPrev: page > 1,
    },
  };
}

export function sanitizeUser(user: { passwordHash?: string; refreshToken?: string; [key: string]: unknown }) {
  const sanitized = { ...user };
  delete sanitized.passwordHash;
  delete sanitized.refreshToken;
  return sanitized;
}

export function isExpired(date: Date): boolean {
  return new Date() > date;
}

export function daysBetween(start: Date, end: Date): number {
  const diff = end.getTime() - start.getTime();
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
}

export function parseTimeToDate(date: Date, time: string): Date {
  const [hours, minutes] = time.split(':').map(Number);
  const result = new Date(date);
  result.setHours(hours, minutes, 0, 0);
  return result;
}

export function hasTimeConflict(
  start1: string,
  end1: string,
  start2: string,
  end2: string,
): boolean {
  return start1 < end2 && start2 < end1;
}

export function chunkArray<T>(array: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}
