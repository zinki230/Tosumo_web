import { AuditRepository } from './audit.repository';

export class AuditService {
  private repository = new AuditRepository();

  async getLogs(userId: string) {
    return this.repository.findByUserId(userId);
  }

  async getAllLogs(filters?: { action?: string; entity?: string; userId?: string }) {
    return this.repository.findAll(filters);
  }

  async log(data: {
    userId: string;
    action: string;
    entity: string;
    entityId?: string;
    description: string;
    metadata?: Record<string, unknown>;
    ipAddress?: string;
    userAgent?: string;
  }) {
    return this.repository.create(data);
  }
}
