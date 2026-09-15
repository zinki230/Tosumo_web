import { Request } from 'express';

export interface JwtPayload {
  userId: string;
  email: string;
  role: 'patient' | 'doctor' | 'admin' | 'superadmin';
}

export interface AuthenticatedRequest extends Request {
  user?: JwtPayload;
}

export interface PaginationParams {
  page?: number;
  limit?: number;
  sort?: string;
  order?: 'asc' | 'desc';
}

export interface PaginatedResult<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasNext: boolean;
    hasPrev: boolean;
  };
}

export interface SyncEntity {
  id: string;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
  version: number;
  syncVersion: number;
}

export interface SyncRequest {
  lastSyncTimestamp: string;
  entityTypes: string[];
}

export interface SyncResponse {
  [entityType: string]: {
    created: SyncEntity[];
    updated: SyncEntity[];
    deleted: SyncEntity[];
  };
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  message?: string;
  data?: T;
  error?: string;
  errors?: Record<string, string[]>;
}

export interface NotificationPayload {
  userId: string;
  title: string;
  body: string;
  type: string;
  data?: Record<string, unknown>;
  imageUrl?: string;
  actionUrl?: string;
}

export interface SocketEvent {
  event: string;
  room?: string;
  userId?: string;
  data: unknown;
}

export interface UploadResult {
  url: string;
  filename: string;
  mimeType: string;
  size: number;
}

export enum UserRole {
  PATIENT = 'patient',
  DOCTOR = 'doctor',
  ADMIN = 'admin',
  SUPERADMIN = 'superadmin',
}

export enum AppointmentStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  CONFIRMED = 'confirmed',
  RESCHEDULED = 'rescheduled',
  CANCELLED = 'cancelled',
  COMPLETED = 'completed',
  NO_SHOW = 'no_show',
}

export enum AccessLevel {
  READ = 'read',
  WRITE = 'write',
  FULL = 'full',
}

export enum PaymentStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  FAILED = 'failed',
  REFUNDED = 'refunded',
}
