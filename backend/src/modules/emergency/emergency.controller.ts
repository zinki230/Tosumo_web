import { Response, NextFunction } from 'express';
import { EmergencyService } from './emergency.service';
import { AuthenticatedRequest } from '@shared/types';
import { BadRequestError } from '@shared/utils/errors';

const emergencyService = new EmergencyService();

export class EmergencyController {
  async triggerSOS(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const result = await emergencyService.triggerSOS(req.user!.userId, req.body);
      res.json({ success: true, data: result });
    } catch (error) { next(error); }
  }

  async startSession(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { patientId, justification } = req.body;
      if (!patientId) throw new BadRequestError('patientId is required');
      const session = await emergencyService.startSession(req.user!.userId, patientId, justification);
      res.status(201).json({ success: true, data: session });
    } catch (error) { next(error); }
  }

  async updateSession(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { status } = req.body;
      if (!status) throw new BadRequestError('status is required');
      const session = await emergencyService.updateSession(req.user!.userId, req.params.id as string, status);
      res.json({ success: true, data: session });
    } catch (error) { next(error); }
  }

  async getSessions(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const status = req.query.status as string | undefined;
      const sessions = await emergencyService.getSessionsByDoctor(req.user!.userId, status);
      res.json({ success: true, data: sessions });
    } catch (error) { next(error); }
  }

  async getSessionById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const session = await emergencyService.getSessionByIdForDoctor(req.user!.userId, req.params.id as string);
      res.json({ success: true, data: session });
    } catch (error) { next(error); }
  }

  async getActiveSession(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const session = await emergencyService.getActiveSession(req.user!.userId);
      res.json({ success: true, data: session });
    } catch (error) { next(error); }
  }

  async getCriticalInfoForDoctor(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const patientId = req.params.patientId as string;
      const info = await emergencyService.getCriticalInfoForDoctor(req.user!.userId, patientId);
      res.json({ success: true, data: info });
    } catch (error) { next(error); }
  }

  async getCriticalInfo(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const info = await emergencyService.getCriticalInfo(req.user!.userId);
      res.json({ success: true, data: info });
    } catch (error) { next(error); }
  }

  async getNearbyHospitals(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { latitude, longitude, radiusKm } = req.query;
      const hospitals = await emergencyService.getNearbyHospitals(
        parseFloat(latitude as string),
        parseFloat(longitude as string),
        radiusKm ? parseInt(radiusKm as string) : undefined,
      );
      res.json({ success: true, data: hospitals });
    } catch (error) { next(error); }
  }
}