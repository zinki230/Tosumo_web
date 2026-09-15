import prisma from '@shared/database/prisma';

export class EmergencyRepository {
  async getPatientCriticalInfo(patientId: string) {
    const patient = await prisma.patient.findUnique({
      where: { id: patientId },
      select: {
        bloodType: true,
        allergies: true,
        chronicDiseases: true,
        emergencyContactName: true,
        emergencyContactPhone: true,
        medicalCard: { select: { cardNumber: true } },
      },
    });
    return patient;
  }

  async getNearbyHospitals(latitude: number, longitude: number, radiusKm = 10) {
    const hospitals = await prisma.institution.findMany({
      where: {
        type: 'hospital',
        isVerified: true,
        latitude: { not: null },
        longitude: { not: null },
      },
    });

    return hospitals.filter(h => {
      if (!h.latitude || !h.longitude) return false;
      const distance = this.haversineDistance(
        latitude, longitude,
        h.latitude, h.longitude,
      );
      return distance <= radiusKm;
    });
  }

  async findIncomingSessionForPatient(patientId: string) {
    return prisma.emergencySession.findFirst({
      where: { patientId, status: 'incoming', deletedAt: null },
      include: { patient: { include: { user: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createSession(data: {
    patientId: string;
    message?: string;
    chiefComplaint?: string;
    location?: unknown;
    criticalInfo?: unknown;
  }) {
    return prisma.emergencySession.create({
      data: {
        patientId: data.patientId,
        message: data.message,
        chiefComplaint: data.chiefComplaint,
        location: data.location as never,
        criticalInfo: data.criticalInfo as never,
        startedAt: new Date(),
        status: 'incoming',
      },
      include: { patient: { include: { user: true } } },
    });
  }

  async acknowledgeSession(sessionId: string, doctorId: string) {
    return prisma.emergencySession.update({
      where: { id: sessionId },
      data: {
        doctorId,
        status: 'acknowledged',
        acknowledgedAt: new Date(),
      },
      include: { patient: { include: { user: true } }, doctor: true },
    });
  }

  async transition(sessionId: string, status: string) {
    const data: Record<string, unknown> = { status };
    if (status === 'active') {
      data.acknowledgedAt = new Date();
    }
    if (status === 'resolved' || status === 'ended') {
      data.resolvedAt = new Date();
    }
    return prisma.emergencySession.update({
      where: { id: sessionId },
      data,
      include: { patient: { include: { user: true } }, doctor: true },
    });
  }

  async findByDoctor(doctorId: string, status?: string) {
    const where: Record<string, unknown> = { doctorId, deletedAt: null };
    if (status) where.status = status;
    return prisma.emergencySession.findMany({
      where,
      include: { patient: { include: { user: true } }, doctor: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findActiveByDoctor(doctorId: string) {
    return prisma.emergencySession.findFirst({
      where: {
        doctorId,
        status: { in: ['incoming', 'acknowledged', 'active'] },
        deletedAt: null,
      },
      include: { patient: { include: { user: true } }, doctor: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findById(sessionId: string) {
    return prisma.emergencySession.findUnique({
      where: { id: sessionId },
      include: { patient: { include: { user: true } }, doctor: true },
    });
  }

  async findActiveDoctorIdsForPatient(patientId: string): Promise<string[]> {
    const sessions = await prisma.emergencySession.findMany({
      where: { patientId, doctorId: { not: null }, deletedAt: null },
      select: { doctorId: true },
    });
    return sessions.map(s => s.doctorId!).filter(Boolean);
  }

  private haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2 +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}