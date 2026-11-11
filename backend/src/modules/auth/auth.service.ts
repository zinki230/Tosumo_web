import { AuthRepository } from './auth.repository';
import { hashPassword, verifyPassword } from '@shared/utils/password';
import { generateTokenPair, verifyRefreshToken } from '@shared/utils/jwt';
import { JwtPayload } from '@shared/types';
import { BadRequestError, ConflictError, UnauthorizedError } from '@shared/utils/errors';
import { sendEmailOtp, sendVerificationEmail } from '@shared/services/email';
import { RegisterInput, LoginInput, RegisterDoctorInput, RegisterInstitutionInput } from './auth.validation';
import { OtpProvider, createOtpProvider, generateOtp } from './otp.provider';
import { normalizeCameroonPhone } from '@shared/utils/phone';
import prisma from '@shared/database/prisma';
import { Prisma } from '@prisma/client';

function placeholderEmailForPhone(phone: string): string {
  const digits = (phone || '').replace(/\D/g, '');
  return `phone-${digits}@tosumo.cm`;
}

function phoneConflict(): ConflictError {
  const err = new ConflictError('Phone number already registered');
  err.code = 'PHONE_ALREADY_REGISTERED';
  return err;
}

export class AuthService {
  private otpProvider: OtpProvider = createOtpProvider();

  async bootstrapSystemAdmin(data: {
    phone: string;
    email: string;
    password: string;
    currentPassword: string;
    createdByUserId: string;
    ipAddress?: string;
    userAgent?: string;
  }) {
    const actor = await prisma.user.findUnique({
      where: { id: data.createdByUserId },
      include: { createdInstitutions: { select: { id: true }, take: 1 } },
    });
    if (!actor || actor.role !== 'institution_admin' || !actor.isActive || !actor.createdInstitutions[0]) {
      throw new UnauthorizedError('Un compte administrateur d’établissement actif est nécessaire');
    }
    if (!(await verifyPassword(data.currentPassword, actor.passwordHash))) {
      throw new UnauthorizedError('Le mot de passe actuel est incorrect');
    }

    const phone = normalizeCameroonPhone(data.phone);
    if (!phone) throw new ConflictError('Numéro de téléphone invalide');
    const email = data.email.trim().toLowerCase();
    const passwordHash = await hashPassword(data.password);
    const institutionId = actor.createdInstitutions[0].id;

    try {
      return await prisma.$transaction(async (tx) => {
        // Serialize bootstrap requests so two establishment accounts cannot
        // both claim the first system-admin slot at the same time.
        await tx.$queryRaw`SELECT pg_advisory_xact_lock(6202611, 1)`;
        const systemAdminCount = await tx.user.count({ where: { role: { in: ['admin', 'superadmin'] } } });
        if (systemAdminCount > 0) {
          throw new ConflictError('Le compte administrateur système est déjà initialisé');
        }

        const user = await tx.user.create({
          data: {
            phone,
            email,
            passwordHash,
            role: 'superadmin',
            isActive: true,
            isEmailVerified: true,
          },
          select: { id: true, phone: true, email: true, role: true },
        });

        await tx.auditLog.create({
          data: {
            userId: actor.id,
            institutionId,
            action: 'create_system_admin',
            entity: 'user',
            entityId: user.id,
            description: `Création du compte administrateur système ${user.email}`,
            metadata: { role: user.role },
            ipAddress: data.ipAddress,
            userAgent: data.userAgent,
          },
        });

        return user;
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictError('Ce numéro ou cette adresse email est déjà utilisé');
      }
      throw error;
    }
  }

  private repository = new AuthRepository();

  async register(input: RegisterInput) {
    const phone = normalizeCameroonPhone(input.phone);
    if (!phone) {
      throw new BadRequestError('Invalid Cameroon phone number');
    }
    const email = input.email?.trim().toLowerCase() || placeholderEmailForPhone(phone);

    const existingPhone = await this.repository.findByPhone(phone);
    if (existingPhone) {
      throw phoneConflict();
    }

    const existingEmail = await this.repository.findByEmail(email);
    if (existingEmail) {
      const err = new ConflictError('Email already registered');
      err.code = 'EMAIL_ALREADY_REGISTERED';
      throw err;
    }

    const passwordHash = await hashPassword(input.password);
    const phoneVerification = await prisma.phoneOtp.findUnique({
      where: { phone_operation: { phone, operation: 'phone_verification' } },
      select: { verifiedAt: true },
    });
    const requiresEmailVerification = Boolean(input.email?.trim() && !email.startsWith('phone-'));
    const emailVerification = requiresEmailVerification
      ? await prisma.phoneOtp.findUnique({
          where: { phone_operation: { phone: `email:registration:${email}`, operation: 'email_verification' } },
          select: { verifiedAt: true, expiresAt: true },
        })
      : null;
    if (emailVerification && (!emailVerification.verifiedAt || emailVerification.expiresAt <= new Date() || Date.now() - emailVerification.verifiedAt.getTime() > 10 * 60_000)) {
      throw new BadRequestError('Veuillez vérifier votre adresse email avant de créer le compte.');
    }

    let user;
    try {
      user = await prisma.$transaction(async (tx) => {
        const createdUser = await tx.user.create({
          data: {
            email,
            phone,
            passwordHash,
            role: input.role,
            isPhoneVerified: Boolean(phoneVerification?.verifiedAt),
            isEmailVerified: Boolean(emailVerification?.verifiedAt),
          },
        });

        if (input.role === 'doctor') {
          const firstName = input.firstName?.trim() || 'Doctor';
          const lastName = input.lastName?.trim() || 'TOSUMO';
          const tempLicenseNumber = `TEMP-${createdUser.id.substring(0, 8)}-${Date.now()}`;
          await tx.doctor.create({
            data: {
              userId: createdUser.id,
              firstName,
              lastName,
              specialty: 'General Practice',
              licenseNumber: tempLicenseNumber,
            },
          });
        }

        return createdUser;
      });
    } catch (error: any) {
      // Race guard: two simultaneous registrations can both pass the
      // findByPhone check above. The database unique index (User.phone) is
      // the source of truth and rejects the second writer with P2002.
      if (error?.code === 'P2002') {
        const target = Array.isArray(error?.meta?.target)
          ? error.meta.target.join(',')
          : String(error?.meta?.target ?? '');
        if (target.includes('phone')) {
          throw phoneConflict();
        }
        if (target.includes('licenseNumber')) {
          // This should not happen with timestamp-based temp license numbers,
          // but if it does, let the error bubble up for investigation
          throw new ConflictError('License number conflict - please try again');
        }
        const conflict = new ConflictError('Email already registered');
        conflict.code = 'EMAIL_ALREADY_REGISTERED';
        throw conflict;
      }
      throw error;
    }

    const payload: JwtPayload = { userId: user.id, email: user.email, role: user.role as JwtPayload['role'] };
    const tokens = generateTokenPair(payload);

    await this.repository.updateRefreshToken(user.id, tokens.refreshToken);

    if (process.env.NODE_ENV !== 'test' && email.includes('@') && !emailVerification?.verifiedAt) {
      sendVerificationEmail(email, tokens.accessToken).catch(console.error);
    }

    return {
      user: {
        id: user.id,
        patientId: (user as any).patientProfile?.id ?? null,
        isOnboarded: (user as any).patientProfile?.isOnboarded ?? false,
        email: user.email,
        phone: user.phone,
        role: user.role,
        isEmailVerified: user.isEmailVerified,
        isPhoneVerified: user.isPhoneVerified,
      },
      tokens,
    };
  }

  async login(input: LoginInput) {
    let user;
    if (input.phone) {
      const phone = normalizeCameroonPhone(input.phone) || input.phone;
      user = await this.repository.findByPhone(phone);
    } else if (input.email) {
      user = await this.repository.findByEmail(input.email.trim().toLowerCase());
    }

    if (!user) {
      throw new UnauthorizedError('Invalid credentials');
    }

    if (!user.isActive) {
      throw new UnauthorizedError('Account is deactivated');
    }

    const isValid = await verifyPassword(input.password, user.passwordHash);
    if (!isValid) {
      throw new UnauthorizedError('Invalid credentials');
    }

    // Build JWT payload with role-specific IDs
    const payload: JwtPayload = { 
      userId: user.id, 
      email: user.email, 
      role: user.role as JwtPayload['role'] 
    };

    // Add role-specific identifiers to JWT
    if (user.role === 'institution_admin' && user.createdInstitutions && user.createdInstitutions.length > 0) {
      payload.institutionId = user.createdInstitutions[0].id;
    }
    
    if (user.role === 'doctor' && user.doctorProfile) {
      payload.doctorId = user.doctorProfile.id;
      // Also add institutionId if doctor has a primary institution
      if (user.doctorProfile.institutions && user.doctorProfile.institutions.length > 0) {
        payload.institutionId = user.doctorProfile.institutions[0].institutionId;
      }
    }

    if (user.role === 'patient' && user.patientProfile) {
      payload.patientId = user.patientProfile.id;
    }

    const tokens = generateTokenPair(payload);

    await this.repository.updateRefreshToken(user.id, tokens.refreshToken);
    await this.repository.updateLastLogin(user.id);

    return {
      user: {
        id: user.id,
        patientId: (user as any).patientProfile?.id ?? null,
        doctorId: (user as any).doctorProfile?.id ?? null,
        institutionId: payload.institutionId ?? null,
        isOnboarded: (user as any).patientProfile?.isOnboarded ?? false,
        email: user.email,
        phone: user.phone,
        role: user.role,
        isEmailVerified: user.isEmailVerified,
        isPhoneVerified: user.isPhoneVerified,
      },
      tokens,
    };
  }

  async refresh(refreshToken: string) {
    let payload: JwtPayload;
    try {
      payload = verifyRefreshToken(refreshToken);
    } catch {
      throw new UnauthorizedError('Invalid refresh token');
    }

    const user = await this.repository.findById(payload.userId);
    if (!user || !user.isActive) {
      throw new UnauthorizedError('User not found or inactive');
    }

    if (user.refreshToken !== refreshToken) {
      throw new UnauthorizedError('Refresh token has been revoked');
    }

    const newPayload: JwtPayload = { userId: user.id, email: user.email, role: user.role as JwtPayload['role'] };
    const tokens = generateTokenPair(newPayload);

    await this.repository.updateRefreshToken(user.id, tokens.refreshToken);

    return tokens;
  }

  async logout(userId: string) {
    await this.repository.updateRefreshToken(userId, null);
  }

  async getProfile(userId: string) {
    const user = await this.repository.findById(userId);
    if (!user) {
      throw new BadRequestError('User not found');
    }
    const { passwordHash, refreshToken, patientProfile, ...profile } = user as any;
    return {
      ...profile,
      patientId: patientProfile?.id ?? null,
      isOnboarded: patientProfile?.isOnboarded ?? false,
    };
  }

  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    const user = await this.repository.findById(userId);
    if (!user) {
      throw new BadRequestError('User not found');
    }

    const isValid = await verifyPassword(currentPassword, user.passwordHash);
    if (!isValid) {
      throw new BadRequestError('Current password is incorrect');
    }

    const newHash = await hashPassword(newPassword);
    await this.repository.updatePassword(userId, newHash);
  }

  async updateFcmToken(userId: string, fcmToken: string) {
    await this.repository.updateFcmToken(userId, fcmToken);
  }

  /**
   * Checks whether a phone number is already registered. Used by the
   * registration flow to reject duplicate numbers before OTP / account
   * creation. The canonical (normalized) phone is always returned so the
   * caller can display/store a single representation.
   */
  async checkPhone(phone: string) {
    const normalized = normalizeCameroonPhone(phone);
    if (!normalized) {
      throw new BadRequestError('Invalid Cameroon phone number');
    }
    const existing = await this.repository.findByPhone(normalized);
    return { exists: Boolean(existing), phone: normalized };
  }

  async sendOtp(phone: string) {
    const normalized = normalizeCameroonPhone(phone);
    if (!normalized) throw new BadRequestError('Invalid Cameroon phone number');
    const code = generateOtp();
    await this.otpProvider.send(normalized, code);

    return {
      message: 'OTP sent successfully',
      expiresIn: 300,
      resendAfter: 60,
      mode: this.otpProvider.mode,
    };
  }

  async sendEmailOtp(email: string, purpose: 'login' | 'registration' = 'login') {
    const normalized = email.trim().toLowerCase();
    const user = await this.repository.findByEmail(normalized);
    if (purpose === 'login' && !user) throw new BadRequestError('Aucun compte ne correspond à cette adresse email.');
    if (purpose === 'registration' && user) {
      const err = new ConflictError('Email already registered');
      err.code = 'EMAIL_ALREADY_REGISTERED';
      throw err;
    }
    const code = generateOtp();
    const key = `email:${purpose}:${normalized}`;
    const now = new Date();
    const hash = createHmac('sha256', config.sms.otpHashSecret).update(`email_verification:${key}:${code}`).digest('hex');
    const current = await prisma.phoneOtp.findUnique({ where: { phone_operation: { phone: key, operation: 'email_verification' } } });
    if (current && now.getTime() - current.createdAt.getTime() < 60_000) throw new BadRequestError('Veuillez attendre avant de demander un nouveau code.');
    await prisma.phoneOtp.upsert({
      where: { phone_operation: { phone: key, operation: 'email_verification' } },
      create: { phone: key, operation: 'email_verification', otpHash: hash, createdAt: now, expiresAt: new Date(now.getTime()+300_000), attempts: 0 },
      update: { otpHash: hash, createdAt: now, expiresAt: new Date(now.getTime()+300_000), attempts: 0, verifiedAt: null },
    });
    try { await sendEmailOtp(normalized, code); }
    catch { await prisma.phoneOtp.updateMany({ where: { phone: key, operation: 'email_verification', createdAt: now }, data: { verifiedAt: now, expiresAt: new Date(now.getTime() - 1) } }); throw new BadRequestError('Impossible d’envoyer le code email.'); }
    return { message: 'Code envoyé par email', expiresIn: 300, resendAfter: 60, mode: 'email' };
  }

  async verifyEmailOtp(email: string, code: string, purpose: 'login' | 'registration' = 'login') {
    const normalized = email.trim().toLowerCase();
    if (!/^\d{6}$/.test(code)) throw new BadRequestError('Code invalide.');
    const key = `email:${purpose}:${normalized}`;
    const current = await prisma.phoneOtp.findUnique({ where: { phone_operation: { phone: key, operation: 'email_verification' } } });
    if (!current || current.verifiedAt || current.expiresAt <= new Date() || current.attempts >= 5) throw new BadRequestError('Code invalide ou expiré.');
    const expected = createHmac('sha256', config.sms.otpHashSecret).update(`email_verification:${key}:${code}`).digest('hex');
    const a = Buffer.from(expected, 'hex'); const b = Buffer.from(current.otpHash, 'hex');
    if (a.length !== b.length || !timingSafeEqual(a,b)) {
      await prisma.phoneOtp.updateMany({ where: { id: current.id, attempts: { lt: 5 } }, data: { attempts: { increment: 1 } } });
      throw new BadRequestError('Code invalide ou expiré.');
    }
    const used = await prisma.phoneOtp.updateMany({ where: { id: current.id, verifiedAt: null, expiresAt: { gt: new Date() }, attempts: { lt: 5 } }, data: { verifiedAt: new Date() } });
    if (!used.count) throw new BadRequestError('Code invalide ou expiré.');
    const user = await this.repository.findByEmail(normalized);
    if (purpose === 'registration') {
      return { message: 'Adresse email vérifiée', mode: 'email', verified: true };
    }
    if (!user || !user.isActive) throw new UnauthorizedError('Aucun compte actif ne correspond à cette adresse email.');
    await prisma.user.update({ where: { id: user.id }, data: { isEmailVerified: true } });
    const payload: JwtPayload = { userId: user.id, email: user.email, role: user.role as JwtPayload['role'] };
    const tokens = generateTokenPair(payload);
    await this.repository.updateRefreshToken(user.id, tokens.refreshToken);
    await this.repository.updateLastLogin(user.id);
    return {
      message: 'Adresse email vérifiée',
      mode: 'email',
      user: {
        id: user.id,
        patientId: (user as any).patientProfile?.id ?? null,
        isOnboarded: (user as any).patientProfile?.isOnboarded ?? false,
        email: user.email,
        phone: user.phone,
        role: user.role,
        isEmailVerified: true,
        isPhoneVerified: user.isPhoneVerified,
      },
      tokens,
    };
  }

  async verifyOtp(phone: string, code: string) {
    const normalized = normalizeCameroonPhone(phone);
    if (!normalized) throw new BadRequestError('Invalid Cameroon phone number');
    const valid = await this.otpProvider.verify(normalized, code);
    if (!valid) {
      throw new BadRequestError('Invalid or expired OTP code');
    }

    const user = await this.repository.findByPhone(normalized);
    if (user) {
      await this.repository.setPhoneVerified(user.id);
    }

    return { message: 'Phone verified successfully', mode: this.otpProvider.mode };
  }

  /**
   * Passwordless login for the patient app: a verified OTP replaces the
   * password. The phone number must belong to a registered, active account —
   * unknown numbers are rejected and never auto-created.
   */
  async otpLogin(phone: string, code: string) {
    const normalized = normalizeCameroonPhone(phone);
    if (!normalized) throw new BadRequestError('Invalid Cameroon phone number');
    const valid = await this.otpProvider.verify(normalized, code);
    if (!valid) {
      throw new BadRequestError('Invalid or expired OTP code');
    }

    const user = await this.repository.findByPhone(normalized);
    if (!user) {
      throw new UnauthorizedError('Phone number not registered');
    }
    if (!user.isActive) {
      throw new UnauthorizedError('Account is deactivated');
    }

    await this.repository.setPhoneVerified(user.id);

    const payload: JwtPayload = { userId: user.id, email: user.email, role: user.role as JwtPayload['role'] };
    const tokens = generateTokenPair(payload);

    await this.repository.updateRefreshToken(user.id, tokens.refreshToken);
    await this.repository.updateLastLogin(user.id);

    return {
      user: {
        id: user.id,
        patientId: (user as any).patientProfile?.id ?? null,
        isOnboarded: (user as any).patientProfile?.isOnboarded ?? false,
        email: user.email,
        phone: user.phone,
        role: user.role,
        isEmailVerified: user.isEmailVerified,
        isPhoneVerified: true,
      },
      tokens,
      mode: this.otpProvider.mode,
    };
  }

  async resetPassword(phone: string, code: string, newPassword: string) {
    const normalized = normalizeCameroonPhone(phone);
    if (!normalized) throw new BadRequestError('Invalid Cameroon phone number');
    const valid = await this.otpProvider.verify(normalized, code);
    if (!valid) {
      throw new BadRequestError('Invalid or expired OTP code');
    }

    const user = await this.repository.findByPhone(normalized);
    if (!user) {
      throw new BadRequestError('User not found for this phone number');
    }

    const newHash = await hashPassword(newPassword);
    await this.repository.updatePassword(user.id, newHash);
    return { message: 'Password reset successfully', mode: this.otpProvider.mode };
  }

  /**
   * Register a new doctor with their professional profile and institution affiliation.
   * Creates both User (role=doctor) and DoctorProfile records in a transaction.
   */
  async registerDoctor(input: RegisterDoctorInput) {
    const phone = normalizeCameroonPhone(input.phone);
    if (!phone) {
      throw new BadRequestError('Invalid Cameroon phone number');
    }
    const email = input.email.trim().toLowerCase();

    // Check for existing user
    const existingPhone = await this.repository.findByPhone(phone);
    if (existingPhone) {
      throw phoneConflict();
    }

    const existingEmail = await this.repository.findByEmail(email);
    if (existingEmail) {
      const err = new ConflictError('Email already registered');
      err.code = 'EMAIL_ALREADY_REGISTERED';
      throw err;
    }

    // Verify institution exists
    const institution = await prisma.institution.findUnique({
      where: { id: input.institutionId },
    });
    if (!institution) {
      throw new BadRequestError('Invalid institution ID');
    }

    const passwordHash = await hashPassword(input.password);

    // Create user and doctor profile in transaction
    const result = await prisma.$transaction(async (tx) => {
      // 1. Create User
      const user = await tx.user.create({
        data: {
          email,
          phone,
          passwordHash,
          role: 'doctor',
        },
      });

      // 2. Create Doctor profile
      const doctor = await tx.doctor.create({
        data: {
          userId: user.id,
          firstName: input.firstName,
          lastName: input.lastName,
          specialty: input.specialty,
          licenseNumber: input.licenseNumber,
          isVerified: false,
          isAvailable: true,
        },
      });

      // 3. Link to institution
      await tx.doctorInstitution.create({
        data: {
          doctorId: doctor.id,
          institutionId: input.institutionId,
        },
      });

      return { user, doctor };
    });

    const payload: JwtPayload = { 
      userId: result.user.id, 
      email: result.user.email, 
      role: 'doctor' as JwtPayload['role'] 
    };
    const tokens = generateTokenPair(payload);

    await this.repository.updateRefreshToken(result.user.id, tokens.refreshToken);

    if (process.env.NODE_ENV !== 'test') {
      sendVerificationEmail(email, tokens.accessToken).catch(console.error);
    }

    return {
      user: {
        id: result.user.id,
        doctorId: result.doctor.id,
        email: result.user.email,
        phone: result.user.phone,
        role: result.user.role,
        firstName: result.doctor.firstName,
        lastName: result.doctor.lastName,
        specialty: result.doctor.specialty,
        isEmailVerified: result.user.isEmailVerified,
        isPhoneVerified: result.user.isPhoneVerified,
      },
      tokens,
    };
  }

  /**
   * Register a new institution (health center, hospital, clinic).
   * Creates a User with role='institution_admin' and Institution record.
   */
  async registerInstitution(input: RegisterInstitutionInput) {
    const phone = normalizeCameroonPhone(input.phone);
    if (!phone) {
      throw new BadRequestError('Invalid Cameroon phone number');
    }
    const email = input.email.trim().toLowerCase();

    // Check for existing user
    const existingPhone = await this.repository.findByPhone(phone);
    if (existingPhone) {
      throw phoneConflict();
    }

    const existingEmail = await this.repository.findByEmail(email);
    if (existingEmail) {
      const err = new ConflictError('Email already registered');
      err.code = 'EMAIL_ALREADY_REGISTERED';
      throw err;
    }

    const passwordHash = await hashPassword(input.password);

    // Create user and institution in transaction
    const result = await prisma.$transaction(async (tx) => {
      // 1. Create User with institution_admin role
      const user = await tx.user.create({
        data: {
          email,
          phone,
          passwordHash,
          role: 'institution_admin',
        },
      });

      // 2. Create Institution record
      const institution = await tx.institution.create({
        data: {
          name: input.name,
          type: input.type,
          phone: phone,
          email: email,
          address: input.address || null,
          city: input.city,
          region: input.region,
          isVerified: false, // Needs admin verification
          createdByUserId: user.id,
        },
      });

      return { user, institution };
    });

    const payload: JwtPayload = { 
      userId: result.user.id, 
      email: result.user.email, 
      role: 'institution_admin' as JwtPayload['role'] 
    };
    const tokens = generateTokenPair(payload);

    await this.repository.updateRefreshToken(result.user.id, tokens.refreshToken);

    if (process.env.NODE_ENV !== 'test') {
      sendVerificationEmail(email, tokens.accessToken).catch(console.error);
    }

    return {
      user: {
        id: result.user.id,
        institutionId: result.institution.id,
        email: result.user.email,
        phone: result.user.phone,
        role: result.user.role,
        institutionName: result.institution.name,
        isEmailVerified: result.user.isEmailVerified,
        isPhoneVerified: result.user.isPhoneVerified,
      },
      tokens,
    };
  }
}
import { createHmac, timingSafeEqual } from 'node:crypto';
import { config } from '@shared/config';
