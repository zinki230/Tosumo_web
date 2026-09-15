import { ImagingResultRepository } from './imaging-result.repository';
import { NotFoundError, ForbiddenError } from '@shared/utils/errors';
import prisma from '@shared/database/prisma';

export class ImagingResultService {
  private repository = new ImagingResultRepository();

  async create(userId: string, role: string, data: {
    patientId: string;
    imagingType: string;
    bodyPart?: string;
    reportText?: string;
    reportFileUrl?: string;
    facilityName?: string;
    notes?: string;
    signature?: Record<string, unknown>;
    signedAt?: Date;
  }) {
    if (role !== 'doctor') throw new ForbiddenError('Only doctors can create imaging results');
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.create({ ...data, doctorId: doctor.id });
  }

  async getById(id: string) {
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('Imaging result not found');
    return record;
  }

  async update(userId: string, role: string, id: string, data: Record<string, unknown>) {
    if (role !== 'doctor') throw new ForbiddenError('Only doctors can update imaging results');
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('Imaging result not found');
    return this.repository.update(id, data);
  }

  async getByPatient(patientId: string) {
    return this.repository.findByPatientId(patientId);
  }

  async getByDoctor(userId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.findByDoctorId(doctor.id);
  }
}
