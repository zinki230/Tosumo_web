import { Response, NextFunction } from 'express';
import { PatientService } from './patient.service';
import { AuthenticatedRequest } from '@shared/types';
import { ForbiddenError, NotFoundError } from '@shared/utils/errors';
import prisma from '@shared/database/prisma';

const patientService = new PatientService();

export class PatientController {
  async getProfile(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const profile = await patientService.getProfile(req.user!.userId);
      res.json({ success: true, data: profile });
    } catch (error) { next(error); }
  }

  async updateProfile(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const profile = await patientService.updateProfile(req.user!.userId, req.body);
      res.json({ success: true, data: profile });
    } catch (error) { next(error); }
  }

  async updateByDoctor(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      if (req.user!.role !== 'doctor') {
        throw new ForbiddenError('Only doctors can update patient records');
      }
      const patientId = String(req.params.id);
      const updated = await patientService.updateByDoctor(patientId, req.body);
      res.json({ success: true, data: updated });
    } catch (error) { next(error); }
  }

  async onboard(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const result = await patientService.onboardPatient(req.user!.userId, req.body);
      res.json({ success: true, data: result });
    } catch (error) { next(error); }
  }

  async getMedicalCard(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const card = await patientService.getMedicalCard(req.user!.userId);
      res.json({ success: true, data: card });
    } catch (error) { next(error); }
  }

  async getEmergencyContacts(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const contacts = await patientService.getEmergencyContacts(req.user!.userId);
      res.json({ success: true, data: contacts });
    } catch (error) { next(error); }
  }

  async addEmergencyContact(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const contact = await patientService.addEmergencyContact(req.user!.userId, req.body);
      res.status(201).json({ success: true, data: contact });
    } catch (error) { next(error); }
  }

  async updateEmergencyContact(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const contact = await patientService.updateEmergencyContact(req.user!.userId, req.params.contactId as string, req.body);
      res.json({ success: true, data: contact });
    } catch (error) { next(error); }
  }

  async deleteEmergencyContact(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await patientService.deleteEmergencyContact(req.user!.userId, req.params.contactId as string);
      res.json({ success: true, message: 'Emergency contact deleted' });
    } catch (error) { next(error); }
  }

  async getMedicalBooklets(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const booklets = await patientService.getMedicalBooklets(req.user!.userId);
      res.json({ success: true, data: booklets });
    } catch (error) { next(error); }
  }

  async addMedicalBooklet(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const booklet = await patientService.addMedicalBooklet(req.user!.userId, req.body);
      res.status(201).json({ success: true, data: booklet });
    } catch (error) { next(error); }
  }

  async deleteMedicalBooklet(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await patientService.deleteMedicalBooklet(req.user!.userId, req.params.bookletId as string);
      res.json({ success: true, message: 'Medical booklet deleted' });
    } catch (error) { next(error); }
  }

  async getJourney(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const journey = await patientService.getJourney(req.user!.userId);
      res.json({ success: true, data: journey });
    } catch (error) { next(error); }
  }

  async getAppointments(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const appointments = await patientService.getAppointments(req.user!.userId);
      res.json({ success: true, data: appointments });
    } catch (error) { next(error); }
  }

  async getMedicalRecords(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const records = await patientService.getMedicalRecords(req.user!.userId);
      res.json({ success: true, data: records });
    } catch (error) { next(error); }
  }

  async getPatientByIdOrUserId(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const id = req.params.id as string;
      const patient = await patientService.getPatientByIdOrUserId(id);
      if (!patient) {
        return res.status(404).json({ success: false, message: 'Patient not found' });
      }
      if (req.user!.role === 'doctor') {
        const doctor = await prisma.doctor.findUnique({ where: { userId: req.user!.userId } });
        const access = await prisma.accessManagement.findFirst({
          where: {
            patientId: patient.id,
            grantedToId: req.user!.userId,
            isActive: true,
            deletedAt: null,
            OR: [{ endDate: null }, { endDate: { gte: new Date() } }],
          },
        });
        const session = doctor ? await prisma.emergencySession.findFirst({
          where: { patientId: patient.id, doctorId: doctor.id, status: { in: ['acknowledged', 'active'] }, deletedAt: null },
        }) : null;
        const createdAny = doctor ? (await prisma.consultation.findFirst({ where: { patientId: patient.id, doctorId: doctor.id, deletedAt: null } })
          || await prisma.labResult.findFirst({ where: { patientId: patient.id, doctorId: doctor.id, deletedAt: null } })
          || await prisma.imagingResult.findFirst({ where: { patientId: patient.id, doctorId: doctor.id, deletedAt: null } })
          || await prisma.prescription.findFirst({ where: { patientId: patient.id, doctorId: doctor.id, deletedAt: null } })) : null;
        if (!access && !session && !createdAny) {
          throw new ForbiddenError('No access authorization for this patient');
        }
      }
      res.json({ success: true, data: patient });
    } catch (error) { next(error); }
  }

  async createPatient(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const patient = await patientService.onboardPatient(req.user!.userId, req.body);
      res.status(201).json({ success: true, data: patient });
    } catch (error) { next(error); }
  }
}
