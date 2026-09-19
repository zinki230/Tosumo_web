import { Response, NextFunction } from 'express';
import { DoctorService } from './doctor.service';
import { AuthenticatedRequest } from '@shared/types';

const doctorService = new DoctorService();

export class DoctorController {
  async getAll(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const institutionId = req.user!.role === 'institution_admin' ? req.user!.institutionId : undefined;
      const doctors = await doctorService.getAll(institutionId);
      res.json({ success: true, data: doctors });
    } catch (error) { next(error); }
  }

  async getById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const doctor = await doctorService.getById(req.params.id as string);
      res.json({ success: true, data: doctor });
    } catch (error) { next(error); }
  }

  async register(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const doctor = await doctorService.register(req.user!.userId, req.body);
      res.status(201).json({ success: true, data: doctor });
    } catch (error) { next(error); }
  }

  async getProfile(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const profile = await doctorService.getProfile(req.user!.userId);
      res.json({ success: true, data: profile });
    } catch (error) { next(error); }
  }

  async updateProfile(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const profile = await doctorService.updateProfile(req.user!.userId, req.body);
      res.json({ success: true, data: profile });
    } catch (error) { next(error); }
  }

  async getAvailability(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const availability = await doctorService.getAvailability(req.user!.userId);
      res.json({ success: true, data: availability });
    } catch (error) { next(error); }
  }

  async setAvailability(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const availability = await doctorService.setAvailability(req.user!.userId, req.body.slots);
      res.json({ success: true, data: availability });
    } catch (error) { next(error); }
  }

  async getWorkingHours(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const date = req.query.date ? new Date(req.query.date as string) : new Date();
      const hours = await doctorService.getWorkingHours(req.user!.userId, date);
      res.json({ success: true, data: hours });
    } catch (error) { next(error); }
  }

  async setWorkingHours(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const hours = await doctorService.setWorkingHours(req.user!.userId, req.body.hours);
      res.json({ success: true, data: hours });
    } catch (error) { next(error); }
  }

  async getAppointments(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointments = await doctorService.getAppointments(req.user!.userId, req.query.status as string);
      res.json({ success: true, data: appointments });
    } catch (error) { next(error); }
  }

  async getPatients(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const patients = await doctorService.getPatients(req.user!.userId);
      res.json({ success: true, data: patients });
    } catch (error) { next(error); }
  }

  async searchPatients(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const patients = await doctorService.searchPatients(
        req.user!.userId,
        req.user!.role,
        req.query.q as string,
      );
      res.json({ success: true, data: patients });
    } catch (error) { next(error); }
  }

  async lookupPatientByQr(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const cardNumber = (req.query.cardNumber as string) ?? (req.query.card as string);
      const token = req.query.token as string | undefined;
      const result = await doctorService.lookupPatientByCard(
        req.user!.userId,
        req.user!.role,
        cardNumber,
        token,
      );
      res.json({ success: true, data: result });
    } catch (error) { next(error); }
  }

  async getDashboard(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const dashboard = await doctorService.getDashboard(req.user!.userId);
      res.json({ success: true, data: dashboard });
    } catch (error) { next(error); }
  }

  async getStats(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const stats = await doctorService.getStats(req.user!.userId);
      res.json({ success: true, data: stats });
    } catch (error) { next(error); }
  }

  async getReviews(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const reviews = await doctorService.getReviews(req.user!.userId);
      res.json({ success: true, data: reviews });
    } catch (error) { next(error); }
  }

  async getInstitutions(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const institutions = await doctorService.getInstitutions(req.user!.userId);
      res.json({ success: true, data: institutions });
    } catch (error) { next(error); }
  }

  async setAvailabilityStatus(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const doctor = await doctorService.setAvailabilityStatus(req.user!.userId, req.body.isAvailable);
      res.json({ success: true, data: doctor });
    } catch (error) { next(error); }
  }

  async changePassword(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { oldPassword, newPassword } = req.body;
      const result = await doctorService.changePassword(req.user!.userId, oldPassword, newPassword);
      res.json({ success: true, data: result, message: result.message });
    } catch (error) { next(error); }
  }
}
