import { Router } from 'express';
import { authenticate } from '@shared/middleware/auth';
import { AuthenticatedRequest } from '@shared/types';
import { Response, NextFunction } from 'express';
import prisma from '@shared/database/prisma';
import { AuditService } from '../audit/audit.service';
import { DoctorService } from '../doctors/doctor.service';
import { authorize } from '@shared/middleware/auth';
import { UserRole } from '@shared/types';
import { AuthService } from '../auth/auth.service';
import { createSystemAdminSchema } from './admin.validation';

const router = Router();
const auditService = new AuditService();
const authService = new AuthService();
const doctorService = new DoctorService();
const dashboardRoles = [UserRole.ADMIN, UserRole.SUPERADMIN, UserRole.INSTITUTION_ADMIN];

router.get('/system-admin-bootstrap', authenticate, authorize(UserRole.INSTITUTION_ADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.user!.institutionId) return res.status(403).json({ success: false, message: 'Institution access is not configured' });
    const count = await prisma.user.count({ where: { role: { in: [UserRole.ADMIN, UserRole.SUPERADMIN] } } });
    res.json({ success: true, data: { available: count === 0 } });
  } catch (error) { next(error); }
});

router.post('/system-admin-bootstrap', authenticate, authorize(UserRole.INSTITUTION_ADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.user!.institutionId) return res.status(403).json({ success: false, message: 'Institution access is not configured' });
    const input = createSystemAdminSchema.parse(req.body);
    const user = await authService.bootstrapSystemAdmin({
      ...input,
      createdByUserId: req.user!.userId,
      ipAddress: req.ip,
      userAgent: req.get('user-agent')?.slice(0, 512),
    });
    res.status(201).json({ success: true, data: user, message: 'System administrator account created' });
  } catch (error) { next(error); }
});

// Get all users
router.get('/users', authenticate, authorize(UserRole.ADMIN, UserRole.SUPERADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const users = await prisma.user.findMany({
      select: { id: true, email: true, phone: true, role: true, isActive: true, isEmailVerified: true, lastLoginAt: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, data: users });
  } catch (error) { next(error); }
});

// Toggle user active status
router.put('/users/:id/toggle-status', authenticate, authorize(UserRole.ADMIN, UserRole.SUPERADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (req.user!.userId === req.params.id) {
      return res.status(400).json({ success: false, message: 'You cannot change your own access status' });
    }
    const user = await prisma.user.findUnique({ where: { id: req.params.id as string } });
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const updated = await prisma.user.update({
      where: { id: req.params.id as string },
      data: { isActive: !user.isActive },
      select: { id: true, email: true, phone: true, role: true, isActive: true },
    });

    await auditService.logRequest(req, {
      userId: req.user!.userId,
      action: user.isActive ? 'deactivate' : 'activate',
      entity: 'user',
      entityId: req.params.id as string,
      description: `${user.isActive ? 'Suspension' : 'Réactivation'} du compte ${updated.email}`,
      metadata: { previousStatus: user.isActive ? 'active' : 'suspended', newStatus: updated.isActive ? 'active' : 'suspended' },
    });

    res.json({ success: true, data: updated });
  } catch (error) { next(error); }
});

// Verify doctor
router.put('/doctors/:id/verify', authenticate, authorize(UserRole.ADMIN, UserRole.SUPERADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const { isVerified, rejectionReason } = req.body;
    const doctor = await doctorService.verifyDoctor(req.params.id as string, isVerified, rejectionReason);

    await auditService.logRequest(req, {
      userId: req.user!.userId,
      action: isVerified ? 'verify_doctor' : 'reject_doctor',
      entity: 'doctor',
      entityId: req.params.id as string,
      description: `${isVerified ? 'Validation' : 'Refus'} du dossier de Dr ${doctor.firstName} ${doctor.lastName}`,
      metadata: {
        isVerified: Boolean(isVerified),
        ...(typeof rejectionReason === 'string' && rejectionReason.trim() ? { rejectionReason: rejectionReason.trim().slice(0, 500) } : {}),
      },
    });

    res.json({ success: true, data: doctor });
  } catch (error) { next(error); }
});

// Get all doctors (admin view)
router.get('/doctors', authenticate, authorize(...dashboardRoles), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const { isVerified, specialty } = req.query;
    const where: Record<string, unknown> = {};
    if (isVerified !== undefined) where.isVerified = isVerified === 'true';
    if (specialty) where.specialty = specialty;
    if (req.user!.role === UserRole.INSTITUTION_ADMIN) {
      if (!req.user!.institutionId) return res.status(403).json({ success: false, message: 'Institution access is not configured' });
      where.institutions = { some: { institutionId: req.user!.institutionId } };
    }

    const doctors = await prisma.doctor.findMany({
      where,
      include: { user: { select: { email: true, phone: true, isActive: true } } },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, data: doctors });
  } catch (error) { next(error); }
});

// Get all appointments (admin view)
router.get('/appointments', authenticate, authorize(...dashboardRoles), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const { status, startDate, endDate } = req.query;
    const where: Record<string, unknown> = {};
    if (status) where.status = status;
    if (startDate && endDate) {
      const inclusiveEndDate = new Date(endDate as string);
      inclusiveEndDate.setHours(23, 59, 59, 999);
      where.appointmentDate = { gte: new Date(startDate as string), lte: inclusiveEndDate };
    }
    if (req.user!.role === UserRole.INSTITUTION_ADMIN) {
      if (!req.user!.institutionId) return res.status(403).json({ success: false, message: 'Institution access is not configured' });
      where.institutionId = req.user!.institutionId;
    }

    const appointments = await prisma.appointment.findMany({
      where,
      include: { patient: { include: { user: { select: { email: true } } } }, doctor: true, institution: true },
      orderBy: { appointmentDate: 'desc' },
    });
    res.json({ success: true, data: appointments });
  } catch (error) { next(error); }
});

// Get audit logs (admin)
router.get('/audit-logs', authenticate, authorize(UserRole.ADMIN, UserRole.SUPERADMIN, UserRole.INSTITUTION_ADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const queryString = (key: string) => typeof req.query[key] === 'string' ? (req.query[key] as string).trim() : '';
    const page = Math.max(1, Math.floor(Number(queryString('page')) || 1));
    const limit = Math.min(100, Math.max(1, Math.floor(Number(queryString('limit')) || 50)));
    const fromValue = queryString('from');
    const toValue = queryString('to');
    const from = fromValue ? new Date(`${fromValue}T00:00:00.000Z`) : undefined;
    const to = toValue ? new Date(`${toValue}T23:59:59.999Z`) : undefined;
    if (req.user!.role === UserRole.INSTITUTION_ADMIN && !req.user!.institutionId) {
      return res.status(403).json({ success: false, message: 'Institution access is not configured' });
    }
    if ((from && Number.isNaN(from.getTime())) || (to && Number.isNaN(to.getTime()))) {
      return res.status(400).json({ success: false, message: 'Invalid audit date filter' });
    }
    const result = await auditService.getAllLogs({
      action: queryString('action') || undefined,
      entity: queryString('entity') || undefined,
      userId: queryString('userId') || undefined,
      institutionId: req.user!.role === UserRole.INSTITUTION_ADMIN ? req.user!.institutionId : undefined,
      search: queryString('search').slice(0, 120) || undefined,
      from,
      to,
      page,
      limit,
    });
    res.json({ success: true, data: result });
  } catch (error) { next(error); }
});

// Dashboard stats (admin)
router.get('/dashboard', authenticate, authorize(UserRole.ADMIN, UserRole.SUPERADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const [
      totalUsers,
      totalPatients,
      totalDoctors,
      totalAppointments,
      pendingVerifications,
      revenue,
    ] = await Promise.all([
      prisma.user.count({ where: { isActive: true } }),
      prisma.patient.count(),
      prisma.doctor.count(),
      prisma.appointment.count({ where: { deletedAt: null } }),
      prisma.doctor.count({ where: { isVerified: false } }),
      prisma.paymentTransaction.aggregate({ _sum: { amount: true }, where: { status: 'completed' } }),
    ]);

    res.json({
      success: true,
      data: {
        stats: { totalUsers, totalPatients, totalDoctors, totalAppointments, pendingVerifications },
        revenue: revenue._sum.amount || 0,
      },
    });
  } catch (error) { next(error); }
});

router.get('/stats', authenticate, authorize(...dashboardRoles), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const isInstitutionAdmin = req.user!.role === 'institution_admin';
    const institutionId = isInstitutionAdmin ? req.user!.institutionId : undefined;
    if (isInstitutionAdmin && !institutionId) {
      return res.status(403).json({ success: false, message: 'Institution access is not configured' });
    }

    // Base queries with institution filtering when needed
    const doctorWhere = institutionId ? {
      deletedAt: null,
      institutions: { some: { institutionId } }
    } : { deletedAt: null };

    const patientWhere = institutionId ? {
      deletedAt: null,
      appointments: { some: {
        deletedAt: null,
        OR: [
          { institutionId },
          { doctor: { institutions: { some: { institutionId } } } },
        ],
      } }
    } : { deletedAt: null };

    const appointmentWhere = institutionId ? {
      deletedAt: null,
      OR: [
        { institutionId },
        { doctor: { institutions: { some: { institutionId } } } },
      ],
    } : { deletedAt: null };

    const todayAppointmentWhere = institutionId ? {
      deletedAt: null,
      OR: [
        { institutionId },
        { doctor: { institutions: { some: { institutionId } } } },
      ],
      appointmentDate: { gte: today, lt: tomorrow }
    } : {
      deletedAt: null,
      appointmentDate: { gte: today, lt: tomorrow }
    };

    const verifiedPatientWhere = institutionId ? {
      deletedAt: null,
      isVerified: true,
      appointments: { some: {
        deletedAt: null,
        OR: [
          { institutionId },
          { doctor: { institutions: { some: { institutionId } } } },
        ],
      } }
    } : {
      deletedAt: null,
      isVerified: true
    };

    const appointmentsForRelationships = prisma.appointment.findMany({
      where: appointmentWhere,
      select: { doctorId: true, patientId: true },
    });

    const [
      totalDoctors,
      totalPatients,
      totalAppointments,
      todayAppointments,
      verifiedPatients,
      relationships,
    ] = await Promise.all([
      prisma.doctor.count({ where: doctorWhere }),
      prisma.patient.count({ where: patientWhere }),
      prisma.appointment.count({ where: appointmentWhere }),
      prisma.appointment.count({ where: todayAppointmentWhere }),
      prisma.patient.count({ where: verifiedPatientWhere }),
      appointmentsForRelationships,
    ]);

    res.json({
      success: true,
      data: {
        totalDoctors,
        totalPatients,
        totalAppointments,
        todayAppointments,
        verifiedPatients,
        activeRelationships: new Set(relationships.map((a) => `${a.doctorId}::${a.patientId}`)).size,
      },
    });
  } catch (error) {
    next(error);
  }
});
export default router;
