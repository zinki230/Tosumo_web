import { AuditRepository } from './audit.repository';
import { AuthenticatedRequest } from '@shared/types';

export interface AuditLogInput {
  userId: string;
  action: string;
  entity: string;
  entityId?: string;
  description: string;
  metadata?: Record<string, unknown>;
}

export class AuditService {
  private repository = new AuditRepository();

  async getLogs(userId: string) {
    return this.repository.findByUserId(userId);
  }

  async getAllLogs(filters: {
    action?: string;
    entity?: string;
    userId?: string;
    search?: string;
    from?: Date;
    to?: Date;
    page: number;
    limit: number;
  }) {
    return this.repository.findAll(filters);
  }

  async log(data: AuditLogInput & { ipAddress?: string; userAgent?: string }) {
    return this.repository.create(data);
  }

  async logRequest(req: AuthenticatedRequest, data: AuditLogInput) {
    return this.log({
      ...data,
      ipAddress: req.ip,
      userAgent: req.get('user-agent')?.slice(0, 512),
    });
  }
}
