import { AuthRepository } from './auth.repository';
import { hashPassword, verifyPassword } from '@shared/utils/password';
import { generateTokenPair, verifyRefreshToken } from '@shared/utils/jwt';
import { JwtPayload } from '@shared/types';
import { BadRequestError, ConflictError, UnauthorizedError } from '@shared/utils/errors';
import { sendVerificationEmail } from '@shared/services/email';
import { RegisterInput, LoginInput, RegisterDoctorInput, RegisterInstitutionInput } from './auth.validation';
import { OtpProvider, createOtpProvider } from './otp.provider';
import { normalizeCameroonPhone } from '@shared/utils/phone';
import prisma from '@shared/database/prisma';

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

  private repository = new AuthRepository();

  async register(input: RegisterInput) {
    const phone = normalizeCameroonPhone(input.phone);
    if (!phone) {
      throw new BadRequestError('Invalid Cameroon phone number');
    }
    const email = input.email?.trim() || placeholderEmailForPhone(phone);

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

    let user;
    try {
      user = await prisma.$transaction(async (tx) => {
        const createdUser = await tx.user.create({
          data: {
            email,
            phone,
            passwordHash,
            role: input.role,
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

    if (process.env.NODE_ENV !== 'test' && email.includes('@')) {
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
    const normalized = normalizeCameroonPhone(phone) || phone;
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    await this.otpProvider.send(normalized, code);

    return {
      message: 'OTP sent successfully',
      expiresIn: 600,
      mode: this.otpProvider.mode,
    };
  }

  async verifyOtp(phone: string, code: string) {
    const normalized = normalizeCameroonPhone(phone) || phone;
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
    const normalized = normalizeCameroonPhone(phone) || phone;
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
        isPhoneVerified: user.isPhoneVerified,
      },
      tokens,
      mode: this.otpProvider.mode,
    };
  }

  async resetPassword(phone: string, code: string, newPassword: string) {
    const normalized = normalizeCameroonPhone(phone) || phone;
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
