import { PrescriptionRepository } from './prescription.repository';
import { NotFoundError, ForbiddenError } from '@shared/utils/errors';
import prisma from '@shared/database/prisma';

export class PrescriptionService {
  private repository = new PrescriptionRepository();

  async create(userId: string, role: string, data: {
    patientId: string;
    consultationId?: string;
    medicationName: string;
    dosage: string;
    frequency: string;
    duration: string;
    route?: string;
    instructions?: string;
    refills?: number;
    pharmacyName?: string;
    signature?: Record<string, unknown>;
    signedAt?: Date;
  }) {
    if (role !== 'doctor') throw new ForbiddenError('Only doctors can create prescriptions');
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    if (data.consultationId) {
      const consultation = await prisma.consultation.findUnique({
        where: { id: data.consultationId },
        select: { id: true, patientId: true, doctorId: true },
      });
      if (!consultation) throw new NotFoundError('Consultation not found');
      if (consultation.patientId !== data.patientId || consultation.doctorId !== doctor.id) {
        throw new ForbiddenError('Consultation does not match this patient/doctor');
      }
    }
    return this.repository.create({ ...data, doctorId: doctor.id });
  }

  async getById(id: string) {
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('Prescription not found');
    return record;
  }

  async update(userId: string, role: string, id: string, data: Record<string, unknown>) {
    if (role !== 'doctor') throw new ForbiddenError('Only doctors can update prescriptions');
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('Prescription not found');
    return this.repository.update(id, data);
  }

  async fulfill(userId: string, role: string, id: string) {
    if (role !== 'doctor' && role !== 'admin') throw new ForbiddenError('Only doctors can fulfill prescriptions');
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('Prescription not found');
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (role === 'doctor' && doctor && record.doctorId !== doctor.id) {
      throw new ForbiddenError('Not your prescription');
    }
    if (record.isFulfilled) throw new Error('Prescription already fulfilled');
    return this.repository.fulfill(id);
  }

  async getByPatient(patientId: string) {
    return this.repository.findByPatientId(patientId);
  }

  async getByDoctor(userId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.findByDoctorId(doctor.id);
  }

  // Patient marks a medication as done (or undoes it). Only the owning patient
  // may mutate their own prescription's completion state.
  async setCompleted(userId: string, role: string, id: string, completed: boolean) {
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('Prescription not found');
    if (role === 'patient') {
      const patient = await prisma.patient.findUnique({ where: { userId } });
      if (!patient || patient.id !== record.patientId) {
        throw new ForbiddenError('Not your prescription');
      }
    } else if (role === 'doctor') {
      const doctor = await prisma.doctor.findUnique({ where: { userId } });
      if (!doctor || doctor.id !== record.doctorId) {
        throw new ForbiddenError('Not your prescription');
      }
    } else {
      throw new ForbiddenError('Only patients or the prescribing doctor can update completion');
    }
    return completed ? this.repository.complete(id) : this.repository.undoComplete(id);
  }
}
