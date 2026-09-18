import { z } from 'zod';
import { normalizeCameroonPhone } from '@shared/utils/phone';

const phoneField = z
  .string()
  .trim()
  .transform((p) => p.replace(/[\s-]/g, ''))
  .pipe(z.string().min(9).max(15))
  .refine((p) => normalizeCameroonPhone(p) !== '', {
    message: 'Invalid Cameroon phone number',
  });

export const registerSchema = z.object({
  email: z.string().email('Invalid email address').optional(),
  phone: phoneField,
  password: z.string().min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
    .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
    .regex(/[0-9]/, 'Password must contain at least one number'),
  role: z.enum(['patient', 'doctor', 'institution_admin']),
  firstName: z.string().min(1, 'First name is required').optional(),
  lastName: z.string().min(1, 'Last name is required').optional(),
});

export const loginSchema = z.object({
  email: z.string().email('Invalid email address').optional(),
  phone: phoneField.optional(),
  password: z.string().min(1, 'Password is required'),
}).refine(data => data.email || data.phone, {
  message: 'Email or phone is required',
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export const verifyEmailSchema = z.object({
  token: z.string().min(1, 'Verification token is required'),
});

export const forgotPasswordSchema = z.object({
  email: z.string().email('Invalid email address'),
});

export const resetPasswordSchema = z.object({
  phone: phoneField,
  code: z.string().min(4).max(6).regex(/^\d+$/, 'OTP code must be digits'),
  newPassword: z.string().min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
    .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
    .regex(/[0-9]/, 'Password must contain at least one number'),
});

export const sendOtpSchema = z.object({
  phone: phoneField,
});

export const checkPhoneSchema = z.object({
  phone: phoneField,
});

export const verifyOtpSchema = z.object({
  phone: phoneField,
  code: z.string().min(4).max(6).regex(/^\d+$/, 'OTP code must be digits'),
});

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1, 'Current password is required'),
  newPassword: z.string().min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
    .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
    .regex(/[0-9]/, 'Password must contain at least one number'),
});

export const registerDoctorSchema = z.object({
  firstName: z.string().min(1, 'First name is required'),
  lastName: z.string().min(1, 'Last name is required'),
  email: z.string().email('Invalid email address'),
  phone: phoneField,
  password: z.string().min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
    .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
    .regex(/[0-9]/, 'Password must contain at least one number'),
  specialty: z.string().min(1, 'Specialty is required'),
  licenseNumber: z.string().min(1, 'License number is required'),
  institutionId: z.string().min(1, 'Institution ID is required'),
});

export const registerInstitutionSchema = z.object({
  name: z.string().min(1, 'Institution name is required'),
  type: z.enum(['hospital', 'clinic', 'health_center', 'polyclinic']),
  phone: phoneField,
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
    .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
    .regex(/[0-9]/, 'Password must contain at least one number'),
  address: z.string().optional(),
  city: z.string().min(1, 'City is required'),
  region: z.string().min(1, 'Region is required'),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type RegisterDoctorInput = z.infer<typeof registerDoctorSchema>;
export type RegisterInstitutionInput = z.infer<typeof registerInstitutionSchema>;
