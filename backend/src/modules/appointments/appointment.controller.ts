import { Response, NextFunction } from 'express';
import { AppointmentService } from './appointment.service';
import { AuthenticatedRequest } from '@shared/types';
import { NotFoundError } from '@shared/utils/errors';
import prisma from '@shared/database/prisma';

const appointmentService = new AppointmentService();

export class AppointmentController {
  async book(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const patient = await prisma.patient.findUnique({ where: { userId: req.user!.userId } });
      if (!patient) throw new NotFoundError('Patient profile not found');
      const appointment = await appointmentService.book({ ...req.body, patientId: patient.id });
      res.status(201).json({ success: true, data: appointment });
    } catch (error) { next(error); }
  }

  async approve(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointment = await appointmentService.approve(req.user!.userId, req.user!.role, req.params.id as string);
      res.json({ success: true, data: appointment });
    } catch (error) { next(error); }
  }

  async confirm(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointment = await appointmentService.confirm(req.user!.userId, req.user!.role, req.params.id as string);
      res.json({ success: true, data: appointment });
    } catch (error) { next(error); }
  }

  async cancel(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointment = await appointmentService.cancel(req.user!.userId, req.user!.role, req.params.id as string, req.body.reason);
      res.json({ success: true, data: appointment });
    } catch (error) { next(error); }
  }

  async reschedule(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointment = await appointmentService.reschedule(req.user!.userId, req.user!.role, req.params.id as string, req.body);
      res.json({ success: true, data: appointment });
    } catch (error) { next(error); }
  }

  async complete(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointment = await appointmentService.complete(req.user!.userId, req.user!.role, req.params.id as string);
      res.json({ success: true, data: appointment });
    } catch (error) { next(error); }
  }

  async markNoShow(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointment = await appointmentService.markNoShow(req.user!.userId, req.user!.role, req.params.id as string);
      res.json({ success: true, data: appointment });
    } catch (error) { next(error); }
  }

  async getById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointment = await appointmentService.getById(req.user!.userId, req.user!.role, req.params.id as string);
      res.json({ success: true, data: appointment });
    } catch (error) { next(error); }
  }

  async getUpcoming(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointments = await appointmentService.getUpcoming(req.user!.userId, req.user!.role);
      res.json({ success: true, data: appointments });
    } catch (error) { next(error); }
  }

  async getAvailableSlots(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const doctorId = req.query.doctorId as string;
      const date = req.query.date ? new Date(req.query.date as string) : new Date();
      const slots = await appointmentService.getAvailableSlots(doctorId, date);
      res.json({ success: true, data: slots });
    } catch (error) { next(error); }
  }
}
