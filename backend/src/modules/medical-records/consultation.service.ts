import { ConsultationRepository } from './consultation.repository';
import { NotFoundError, ForbiddenError } from '@shared/utils/errors';
import prisma from '@shared/database/prisma';

export class ConsultationService {
  private repository = new ConsultationRepository();

  async create(userId: string, role: string, data: {
    patientId: string;
    appointmentId?: string;
    chiefComplaint: string;
    historyOfPresentIllness?: string;
    diagnosis?: string;
    symptoms?: string[];
    vitalSigns?: Record<string, unknown>;
    assessment?: string;
    plan?: string;
    notes?: string;
    orderedExams?: unknown;
  }) {
    if (role !== 'doctor') throw new ForbiddenError('Only doctors can create consultations');
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.create({ ...data, doctorId: doctor.id });
  }

  async update(userId: string, role: string, id: string, data: Record<string, unknown>) {
    const consultation = await this.repository.findById(id);
    if (!consultation) throw new NotFoundError('Consultation not found');

    if (role === 'doctor') {
      const doctor = await prisma.doctor.findUnique({ where: { userId } });
      if (doctor && consultation.doctorId !== doctor.id) throw new ForbiddenError('Not your consultation');
      return this.repository.update(id, data);
    }

    if (role === 'patient') {
      const patient = await prisma.patient.findUnique({ where: { userId } });
      if (!patient || consultation.patientId !== patient.id) {
        throw new ForbiddenError('Not your consultation');
      }
      // Patients may only attach exam result files to their consultation.
      const allowed = ['orderedExams'];
      const filtered: Record<string, unknown> = {};
      for (const key of allowed) {
        if (key in data) filtered[key] = data[key];
      }
      return this.repository.update(id, filtered);
    }

    throw new ForbiddenError('Unauthorized');
  }

  async delete(userId: string, role: string, id: string) {
    if (role !== 'doctor') throw new ForbiddenError('Only doctors can delete consultations');
    const consultation = await this.repository.findById(id);
    if (!consultation) throw new NotFoundError('Consultation not found');
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (doctor && consultation.doctorId !== doctor.id) throw new ForbiddenError('Not your consultation');
    return this.repository.delete(id);
  }

  async getByPatient(patientId: string) {
    return this.repository.findByPatientId(patientId);
  }

  async getByDoctor(userId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.findByDoctorId(doctor.id);
  }

  async getById(id: string) {
    const consultation = await this.repository.findById(id);
    if (!consultation) throw new NotFoundError('Consultation not found');
    return consultation;
  }
}
