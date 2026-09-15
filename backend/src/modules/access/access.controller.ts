import { Response, NextFunction } from 'express';
import { AccessService } from './access.service';
import { AuthenticatedRequest } from '@shared/types';

const accessService = new AccessService();

export class AccessController {
  async grantAccess(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const access = await accessService.grantAccess(req.user!.userId, req.body);
      res.status(201).json({ success: true, data: access });
    } catch (error) { next(error); }
  }

  async requestAccess(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const data = await accessService.requestAccess(req.user!.userId, req.body);
      res.status(201).json({ success: true, data });
    } catch (error) { next(error); }
  }

  async approveAccess(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const access = await accessService.approveAccess(req.params.id as string);
      res.json({ success: true, data: access });
    } catch (error) { next(error); }
  }

  async revokeAccess(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const access = await accessService.revokeAccess(req.user!.userId, req.params.id as string, req.body.reason);
      res.json({ success: true, data: access });
    } catch (error) { next(error); }
  }

  async getPatientAccesses(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const accesses = await accessService.getPatientAccesses(req.user!.userId);
      res.json({ success: true, data: accesses });
    } catch (error) { next(error); }
  }

  async getDoctorAccesses(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const accesses = await accessService.getDoctorAccesses(req.user!.userId);
      res.json({ success: true, data: accesses });
    } catch (error) { next(error); }
  }

  async checkAccess(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const result = await accessService.checkAccess(req.params.patientUserId as string, req.user!.userId);
      res.json({ success: true, data: result });
    } catch (error) { next(error); }
  }
}
