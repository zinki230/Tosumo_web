import { Response, NextFunction } from 'express';
import { AuditService } from './audit.service';
import { AuthenticatedRequest } from '@shared/types';

const auditService = new AuditService();

export class AuditController {
  async getLogs(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const logs = await auditService.getLogs(req.user!.userId);
      res.json({ success: true, data: logs });
    } catch (error) { next(error); }
  }
}
