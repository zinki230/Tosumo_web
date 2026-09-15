import prisma from '@shared/database/prisma';

export class DoctorRepository {
  async findByUserId(userId: string) {
    return prisma.doctor.findUnique({
      where: { userId },
      include: {
        availability: true,
        workingHours: true,
        institutions: { include: { institution: true } },
      },
    });
  }

  async findById(id: string) {
    return prisma.doctor.findUnique({
      where: { id },
      include: {
        availability: true,
        workingHours: true,
        institutions: { include: { institution: true } },
      },
    });
  }

  async findAll() {
    return prisma.doctor.findMany({
      where: { isVerified: true, deletedAt: null },
      include: { user: true, availability: true, workingHours: true, institutions: { include: { institution: true } } },
      orderBy: { averageRating: 'desc' },
    });
  }

  async findByLicenseNumber(licenseNumber: string) {
    return prisma.doctor.findUnique({ where: { licenseNumber } });
  }

  async create(data: {
    userId: string;
    firstName: string;
    lastName: string;
    specialty: string;
    licenseNumber: string;
    yearsOfExperience?: number;
    consultationFee?: number;
    bio?: string;
    title?: string;
    languages?: string[];
    city?: string;
    region?: string;
  }) {
    return prisma.doctor.create({ data });
  }

  private readonly allowedProfileFields = [
    'title', 'firstName', 'lastName', 'specialty', 'bio', 'profilePhotoUrl',
    'consultationFee', 'languages', 'address', 'city', 'region', 'education',
    'certifications', 'documents',
  ];

  async update(doctorId: string, data: Record<string, unknown>) {
    const filtered: Record<string, unknown> = {};
    for (const key of this.allowedProfileFields) {
      if (key in data) filtered[key] = data[key];
    }
    return prisma.doctor.update({
      where: { id: doctorId },
      data: { ...filtered, version: { increment: 1 } },
    });
  }

  async getAvailability(doctorId: string) {
    return prisma.doctorAvailability.findMany({ where: { doctorId } });
  }

  async setAvailability(doctorId: string, slots: Array<{
    dayOfWeek: number;
    startTime: string;
    endTime: string;
    isAvailable?: boolean;
    slotDuration?: number;
  }>) {
    await prisma.doctorAvailability.deleteMany({ where: { doctorId } });
    return prisma.doctorAvailability.createMany({
      data: slots.map(s => ({ ...s, doctorId })),
    });
  }

  async getWorkingHours(doctorId: string, date: Date) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);
    return prisma.workingHours.findMany({
      where: {
        doctorId,
        date: { gte: startOfDay, lte: endOfDay },
      },
    });
  }

  async setWorkingHours(doctorId: string, hours: Array<{
    date: Date;
    startTime: string;
    endTime: string;
    isAvailable?: boolean;
    reason?: string;
  }>) {
    for (const h of hours) {
      const startOfDay = new Date(h.date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(h.date);
      endOfDay.setHours(23, 59, 59, 999);
      await prisma.workingHours.deleteMany({
        where: { doctorId, date: { gte: startOfDay, lte: endOfDay } },
      });
      await prisma.workingHours.create({ data: { ...h, doctorId } });
    }
  }

  async getAppointments(doctorId: string, status?: string) {
    const where: Record<string, unknown> = { doctorId, deletedAt: null };
    if (status) where.status = status;
    return prisma.appointment.findMany({
      where,
      include: { patient: true, institution: true },
      orderBy: { appointmentDate: 'desc' },
    });
  }

  async getPatients(doctorId: string) {
    const appointments = await prisma.appointment.findMany({
      where: { doctorId, deletedAt: null },
      select: { patientId: true },
      distinct: ['patientId'],
    });
    const patientIds = appointments.map(a => a.patientId);
    return prisma.patient.findMany({
      where: { id: { in: patientIds } },
      include: { user: true, medicalCard: true },
    });
  }

  async searchPatients(q: string) {
    return prisma.patient.findMany({
      where: {
        deletedAt: null,
        OR: [
          { firstName: { contains: q, mode: 'insensitive' } },
          { lastName: { contains: q, mode: 'insensitive' } },
          { nin: { contains: q, mode: 'insensitive' } },
          { user: { is: { phone: { contains: q, mode: 'insensitive' } } } },
          { medicalCard: { is: { cardNumber: { contains: q, mode: 'insensitive' } } } },
        ],
      },
      include: { user: true, medicalCard: true },
      take: 20,
      orderBy: { updatedAt: 'desc' },
    });
  }

  async findPatientByCard(cardNumber: string) {
    const card = await prisma.medicalCard.findFirst({
      where: {
        deletedAt: null,
        OR: [{ cardNumber }, { qrCodeHash: cardNumber }],
      },
      include: { patient: { include: { user: true, emergencyInfos: true } } },
    });
    return card?.patient ?? null;
  }

  async getDashboard(doctorId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const [
      totalAppointments,
      todayAppointments,
      pendingApprovals,
      totalPatients,
      recentAppointments,
      upcomingAppointments,
    ] = await Promise.all([
      prisma.appointment.count({ where: { doctorId, deletedAt: null } }),
      prisma.appointment.count({
        where: {
          doctorId,
          appointmentDate: { gte: today, lt: tomorrow },
          deletedAt: null,
        },
      }),
      prisma.appointment.count({
        where: { doctorId, status: 'pending', deletedAt: null },
      }),
      prisma.appointment.findMany({
        where: { doctorId, deletedAt: null },
        select: { patientId: true },
        distinct: ['patientId'],
      }).then(a => a.length),
      prisma.appointment.findMany({
        where: { doctorId, deletedAt: null },
        orderBy: { createdAt: 'desc' },
        take: 5,
        include: { patient: true },
      }),
      prisma.appointment.findMany({
        where: {
          doctorId,
          appointmentDate: { gte: today },
          status: { in: ['approved', 'confirmed'] },
          deletedAt: null,
        },
        orderBy: { appointmentDate: 'asc' },
        take: 10,
        include: { patient: true, institution: true },
      }),
    ]);

    return {
      stats: { totalAppointments, todayAppointments, pendingApprovals, totalPatients },
      recentAppointments,
      upcomingAppointments,
    };
  }

  async getStats(doctorId: string) {
    const [
      totalAppointments,
      completedAppointments,
      cancelledAppointments,
      averageRating,
    ] = await Promise.all([
      prisma.appointment.count({ where: { doctorId, deletedAt: null } }),
      prisma.appointment.count({ where: { doctorId, status: 'completed', deletedAt: null } }),
      prisma.appointment.count({ where: { doctorId, status: 'cancelled', deletedAt: null } }),
      prisma.doctor.findUnique({ where: { id: doctorId }, select: { averageRating: true } }),
    ]);
    return { totalAppointments, completedAppointments, cancelledAppointments, averageRating: averageRating?.averageRating || 0 };
  }

  async getReviews(doctorId: string) {
    return prisma.doctorReview.findMany({
      where: { doctorId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getInstitutions(doctorId: string) {
    return prisma.doctorInstitution.findMany({
      where: { doctorId },
      include: { institution: true },
    });
  }
}
