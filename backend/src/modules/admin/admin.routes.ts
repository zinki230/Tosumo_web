import { Router } from 'express';
import { authenticate } from '@shared/middleware/auth';
import { AuthenticatedRequest } from '@shared/types';
import { Response, NextFunction } from 'express';
import prisma from '@shared/database/prisma';
import { AuditService } from '../audit/audit.service';
import { DoctorService } from '../doctors/doctor.service';
import { authorize } from '@shared/middleware/auth';
import { UserRole } from '@shared/types';

const router = Router();
const auditService = new AuditService();
const doctorService = new DoctorService();
const dashboardRoles = [UserRole.ADMIN, UserRole.SUPERADMIN, UserRole.INSTITUTION_ADMIN];

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
    const user = await prisma.user.findUnique({ where: { id: req.params.id as string } });
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    const updated = await prisma.user.update({
      where: { id: req.params.id as string },
      data: { isActive: !user.isActive },
    });

    await auditService.log({
      userId: req.user!.userId,
      action: user.isActive ? 'deactivate' : 'activate',
      entity: 'user',
      entityId: req.params.id as string,
      description: `${user.isActive ? 'Deactivated' : 'Activated'} user ${updated.email}`,
    });

    res.json({ success: true, data: updated });
  } catch (error) { next(error); }
});

// Verify doctor
router.put('/doctors/:id/verify', authenticate, authorize(UserRole.ADMIN, UserRole.SUPERADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const { isVerified, rejectionReason } = req.body;
    const doctor = await doctorService.verifyDoctor(req.params.id as string, isVerified, rejectionReason);

    await auditService.log({
      userId: req.user!.userId,
      action: isVerified ? 'verify_doctor' : 'reject_doctor',
      entity: 'doctor',
      entityId: req.params.id as string,
      description: `${isVerified ? 'Verified' : 'Rejected'} doctor ${doctor.firstName} ${doctor.lastName}`,
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
      where.appointmentDate = { gte: new Date(startDate as string), lte: new Date(endDate as string) };
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
router.get('/audit-logs', authenticate, authorize(UserRole.ADMIN, UserRole.SUPERADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const filters = req.query as { action?: string; entity?: string; userId?: string };
    const logs = await auditService.getAllLogs(filters);
    res.json({ success: true, data: logs });
  } catch (error) { next(error); }
});

// Dashboard stats (admin)
router.get('/dashboard', authenticate, authorize(...dashboardRoles), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
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

router.get('/stats', authenticate, authorize(...dashboardRoles), async (_req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const appointmentsForRelationships = prisma.appointment.findMany({
      where: { deletedAt: null },
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
      prisma.doctor.count({ where: { deletedAt: null } }),
      prisma.patient.count({ where: { deletedAt: null } }),
      prisma.appointment.count({ where: { deletedAt: null } }),
      prisma.appointment.count({
        where: { deletedAt: null, appointmentDate: { gte: today, lt: tomorrow } },
      }),
      prisma.patient.count({ where: { deletedAt: null, isVerified: true } }),
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
