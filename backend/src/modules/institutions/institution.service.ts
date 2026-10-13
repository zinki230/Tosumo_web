import { InstitutionRepository } from './institution.repository';
import { BadRequestError, NotFoundError, ConflictError, ForbiddenError } from '@shared/utils/errors';
import { hashPassword } from '@shared/utils/password';
import { normalizeCameroonPhone } from '@shared/utils/phone';
import prisma from '@shared/database/prisma';
import { Prisma } from '@prisma/client';
import crypto from 'crypto';

function generateTemporaryPassword(): string {
  // Generate a secure random 8-character password
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  let password = '';
  for (let i = 0; i < 8; i++) {
    password += chars.charAt(crypto.randomInt(0, chars.length));
  }
  return password;
}

function placeholderEmailForPhone(phone: string): string {
  const digits = (phone || '').replace(/\D/g, '');
  return `phone-${digits}@tosumo.cm`;
}

export class InstitutionService {
  private repository = new InstitutionRepository();

  async getAll(filters?: { type?: string; city?: string; region?: string }) {
    return this.repository.findAll(filters);
  }

  async getById(id: string) {
    const institution = await this.repository.findById(id);
    if (!institution) throw new NotFoundError('Institution not found');
    return institution;
  }

  async create(data: Record<string, unknown>) {
    return this.repository.create(data as any);
  }

  async createDoctor(institutionAdminUserId: string, data: {
    firstName: string;
    lastName: string;
    phone: string;
    specialty: string;
    licenseNumber: string;
    email?: string;
  }) {
    // Verify the admin belongs to an institution
    const admin = await prisma.user.findUnique({
      where: { id: institutionAdminUserId },
      include: { createdInstitutions: true }
    });

    if (!admin || admin.role !== 'institution_admin') {
      throw new ForbiddenError('Only institution admins can create doctor accounts');
    }

    if (!admin.createdInstitutions || admin.createdInstitutions.length === 0) {
      throw new ForbiddenError('No institution found for this admin');
    }

    const institutionId = admin.createdInstitutions[0].id;

    // Normalize phone
    const phone = normalizeCameroonPhone(data.phone);
    if (!phone) {
      throw new BadRequestError('Invalid Cameroon phone number');
    }

    const email = data.email?.trim().toLowerCase() || placeholderEmailForPhone(phone);

    // Check if phone already exists
    const existingUser = await prisma.user.findUnique({ where: { phone } });
    if (existingUser) {
      throw new ConflictError('This phone number is already registered');
    }

    // Email is unique in the shared User collection too. Check it before the
    // transaction so the portal gets a useful 409 instead of an opaque 500.
    const existingEmail = await prisma.user.findUnique({ where: { email } });
    if (existingEmail) {
      throw new ConflictError('This email address is already registered');
    }

    // Check if license number already exists
    const existingLicense = await prisma.doctor.findUnique({ 
      where: { licenseNumber: data.licenseNumber } 
    });
    if (existingLicense) {
      throw new ConflictError('This license number is already registered');
    }

    // Generate temporary password
    const temporaryPassword = generateTemporaryPassword();
    const passwordHash = await hashPassword(temporaryPassword);

    // Create user, doctor profile, and institution link in transaction
    let result;
    try {
      result = await prisma.$transaction(async (tx) => {
        const user = await tx.user.create({
          data: {
            email,
            phone,
            passwordHash,
            role: 'doctor',
            isActive: true,
          }
        });

        const doctor = await tx.doctor.create({
          data: {
            userId: user.id,
            firstName: data.firstName,
            lastName: data.lastName,
            specialty: data.specialty,
            licenseNumber: data.licenseNumber,
            isVerified: true, // Auto-verified since created by institution
          }
        });

        await tx.doctorInstitution.create({
          data: {
            doctorId: doctor.id,
            institutionId,
            isPrimary: true,
            role: 'attending'
          }
        });

        return { user, doctor, temporaryPassword };
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const target = Array.isArray(error.meta?.target)
          ? error.meta.target.join(',')
          : String(error.meta?.target ?? '');
        if (target.includes('email')) {
          throw new ConflictError('This email address is already registered');
        }
        if (target.includes('phone')) {
          throw new ConflictError('This phone number is already registered');
        }
        if (target.includes('licenseNumber')) {
          throw new ConflictError('This license number is already registered');
        }
        throw new ConflictError('A doctor with these details is already registered');
      }
      throw error;
    }

    return {
      doctor: {
        id: result.doctor.id,
        firstName: result.doctor.firstName,
        lastName: result.doctor.lastName,
        phone: result.user.phone,
        email: result.user.email,
        specialty: result.doctor.specialty,
        licenseNumber: result.doctor.licenseNumber,
      },
      credentials: {
        phone: result.user.phone,
        temporaryPassword: result.temporaryPassword,
      }
    };
  }

  async getDoctorsByInstitution(institutionId: string) {
    const doctors = await prisma.doctor.findMany({
      where: {
        institutions: {
          some: {
            institutionId: institutionId
          }
        },
        deletedAt: null
      },
      include: {
        user: {
          select: {
            phone: true,
            email: true,
            isActive: true,
            lastLoginAt: true
          }
        },
        institutions: {
          where: { institutionId },
          select: {
            role: true,
            isPrimary: true
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    return doctors.map(doc => ({
      id: doc.id,
      firstName: doc.firstName,
      lastName: doc.lastName,
      fullName: `${doc.firstName} ${doc.lastName}`,
      phone: doc.user.phone,
      email: doc.user.email,
      specialty: doc.specialty,
      licenseNumber: doc.licenseNumber,
      isVerified: doc.isVerified,
      isActive: doc.user.isActive,
      lastLoginAt: doc.user.lastLoginAt,
      role: doc.institutions[0]?.role,
      isPrimary: doc.institutions[0]?.isPrimary,
      createdAt: doc.createdAt
    }));
  }
}
