import { Response, NextFunction } from 'express';
import { ConsultationService } from './consultation.service';
import { LabResultService } from './lab-result.service';
import { ImagingResultService } from './imaging-result.service';
import { PrescriptionService } from './prescription.service';
import { AuthenticatedRequest } from '@shared/types';
import { ForbiddenError, NotFoundError } from '@shared/utils/errors';
import prisma from '@shared/database/prisma';

const consultationService = new ConsultationService();
const labResultService = new LabResultService();
const imagingResultService = new ImagingResultService();
const prescriptionService = new PrescriptionService();

export class MedicalRecordsController {
  /**
   * Doctor-only, access-controlled read of a patient's complete record
   * (consultations, lab results, imaging results, prescriptions).
   * The backend is the final authority: access is granted when the doctor has
   * an active access grant (normal or emergency) or created a record himself.
   */
  async getPatientRecords(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      if (req.user!.role !== 'doctor') throw new ForbiddenError('Only doctors can access patient records');
      const doctor = await prisma.doctor.findUnique({ where: { userId: req.user!.userId } });
      if (!doctor) throw new NotFoundError('Doctor profile not found');

      const patientId = req.params.patientId as string;
      const patient = await prisma.patient.findUnique({ where: { id: patientId } });
      if (!patient) throw new NotFoundError('Patient not found');

      const access = await prisma.accessManagement.findFirst({
        where: {
          patientId,
          grantedToId: req.user!.userId,
          isActive: true,
          deletedAt: null,
          OR: [{ endDate: null }, { endDate: { gte: new Date() } }],
        },
      });
      const session = await prisma.emergencySession.findFirst({
        where: { patientId, doctorId: doctor.id, status: { in: ['acknowledged', 'active'] }, deletedAt: null },
      });
      const createdAny = await prisma.consultation.findFirst({ where: { patientId, doctorId: doctor.id, deletedAt: null } })
        || await prisma.labResult.findFirst({ where: { patientId, doctorId: doctor.id, deletedAt: null } })
        || await prisma.imagingResult.findFirst({ where: { patientId, doctorId: doctor.id, deletedAt: null } })
        || await prisma.prescription.findFirst({ where: { patientId, doctorId: doctor.id, deletedAt: null } });

      if (!access && !session && !createdAny) {
        throw new ForbiddenError('No access authorization for this patient');
      }

      const [consultations, labResults, imagingResults, prescriptions] = await Promise.all([
        consultationService.getByPatient(patientId),
        labResultService.getByPatient(patientId),
        imagingResultService.getByPatient(patientId),
        prescriptionService.getByPatient(patientId),
      ]);

      res.json({ success: true, data: { consultations, labResults, imagingResults, prescriptions } });
    } catch (error) { next(error); }
  }

  // Consultations
  async createConsultation(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      if (req.user!.role !== 'doctor') throw new ForbiddenError('Only doctors can create consultations');
      const doctor = await prisma.doctor.findUnique({ where: { userId: req.user!.userId } });
      if (!doctor) throw new NotFoundError('Doctor profile not found');
      const patientId = req.body?.patientId;
      if (!patientId) throw new NotFoundError('patientId is required');
      const patient = await prisma.patient.findUnique({ where: { id: patientId } });
      if (!patient) throw new NotFoundError('Patient not found');
      const access = await prisma.accessManagement.findFirst({
        where: {
          patientId,
          grantedToId: req.user!.userId,
          isActive: true,
          deletedAt: null,
          OR: [{ endDate: null }, { endDate: { gte: new Date() } }],
        },
      });
      const createdAny = await prisma.consultation.findFirst({ where: { patientId, doctorId: doctor.id, deletedAt: null } })
        || await prisma.labResult.findFirst({ where: { patientId, doctorId: doctor.id, deletedAt: null } })
        || await prisma.imagingResult.findFirst({ where: { patientId, doctorId: doctor.id, deletedAt: null } })
        || await prisma.prescription.findFirst({ where: { patientId, doctorId: doctor.id, deletedAt: null } });
      if (!access && !createdAny) {
        throw new ForbiddenError('No access authorization for this patient');
      }
      const record = await consultationService.create(req.user!.userId, req.user!.role, req.body);
      res.status(201).json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async getConsultations(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      if (req.user!.role === 'doctor') {
        const records = await consultationService.getByDoctor(req.user!.userId);
        return res.json({ success: true, data: records });
      }
      const patient = await prisma.patient.findUnique({ where: { userId: req.user!.userId } });
      if (!patient) return res.status(404).json({ success: false, message: 'Patient profile not found' });
      const records = await consultationService.getByPatient(patient.id);
      return res.json({ success: true, data: records });
    } catch (error) { next(error); }
  }

  async getConsultationById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await consultationService.getById(req.params.id as string);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async updateConsultation(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await consultationService.update(req.user!.userId, req.user!.role, req.params.id as string, req.body);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async deleteConsultation(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await consultationService.delete(req.user!.userId, req.user!.role, req.params.id as string);
      res.json({ success: true, message: 'Consultation deleted' });
    } catch (error) { next(error); }
  }

  // Lab Results
  async getLabResultById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await labResultService.getById(req.params.id as string);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async createLabResult(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await labResultService.create(req.user!.userId, req.user!.role, req.body);
      res.status(201).json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async getLabResults(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      if (req.user!.role === 'doctor') {
        const records = await labResultService.getByDoctor(req.user!.userId);
        return res.json({ success: true, data: records });
      }
      const patient = await prisma.patient.findUnique({ where: { userId: req.user!.userId } });
      if (!patient) return res.status(404).json({ success: false, message: 'Patient profile not found' });
      const records = await labResultService.getByPatient(patient.id);
      return res.json({ success: true, data: records });
    } catch (error) { next(error); }
  }

  async updateLabResult(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await labResultService.update(req.user!.userId, req.user!.role, req.params.id as string, req.body);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  // Imaging Results
  async getImagingResultById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await imagingResultService.getById(req.params.id as string);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async createImagingResult(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await imagingResultService.create(req.user!.userId, req.user!.role, req.body);
      res.status(201).json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async getImagingResults(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      if (req.user!.role === 'doctor') {
        const records = await imagingResultService.getByDoctor(req.user!.userId);
        return res.json({ success: true, data: records });
      }
      const patient = await prisma.patient.findUnique({ where: { userId: req.user!.userId } });
      if (!patient) return res.status(404).json({ success: false, message: 'Patient profile not found' });
      const records = await imagingResultService.getByPatient(patient.id);
      return res.json({ success: true, data: records });
    } catch (error) { next(error); }
  }

  async updateImagingResult(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await imagingResultService.update(req.user!.userId, req.user!.role, req.params.id as string, req.body);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  // Prescriptions
  async getPrescriptionById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await prescriptionService.getById(req.params.id as string);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async createPrescription(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await prescriptionService.create(req.user!.userId, req.user!.role, req.body);
      res.status(201).json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async getPrescriptions(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      if (req.user!.role === 'doctor') {
        const records = await prescriptionService.getByDoctor(req.user!.userId);
        return res.json({ success: true, data: records });
      }
      const patient = await prisma.patient.findUnique({ where: { userId: req.user!.userId } });
      if (!patient) return res.status(404).json({ success: false, message: 'Patient profile not found' });
      const records = await prescriptionService.getByPatient(patient.id);
      return res.json({ success: true, data: records });
    } catch (error) { next(error); }
  }

  async updatePrescription(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await prescriptionService.update(req.user!.userId, req.user!.role, req.params.id as string, req.body);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async fulfillPrescription(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const record = await prescriptionService.fulfill(req.user!.userId, req.user!.role, req.params.id as string);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }

  async completePrescription(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const completed = req.body?.isCompleted !== false;
      const record = await prescriptionService.setCompleted(req.user!.userId, req.user!.role, req.params.id as string, completed);
      res.json({ success: true, data: record });
    } catch (error) { next(error); }
  }
}
