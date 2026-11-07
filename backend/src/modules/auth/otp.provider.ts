import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { config } from '@shared/config';
import prisma from '@shared/database/prisma';
import { AppError, BadRequestError, TooManyRequestsError } from '@shared/utils/errors';
import { sendVerificationSMS } from '@shared/services/sms';

export interface OtpProvider {
  readonly mode: 'sms';
  send(phone: string, code: string): Promise<void>;
  verify(phone: string, code: string): Promise<boolean>;
  getDemoCode(): string | null;
}

const OPERATION = 'phone_verification';
const OTP_TTL_MS = 5 * 60 * 1000;
const RESEND_WAIT_MS = 60 * 1000;
const MAX_ATTEMPTS = 5;

function otpHash(phone: string, code: string): string {
  const secret = config.sms.otpHashSecret;
  if (secret.length < 32) throw new AppError('Le secret de vérification OTP doit contenir au moins 32 caractères.', 503);
  return createHmac('sha256', secret).update(`${OPERATION}:${phone}:${code}`).digest('hex');
}

export class SmsOtpProvider implements OtpProvider {
  readonly mode = 'sms' as const;

  async send(phone: string, code: string): Promise<void> {
    const now = new Date();
    let record;
    try {
      record = await prisma.$transaction(async (tx) => {
        const current = await tx.phoneOtp.findUnique({
          where: { phone_operation: { phone, operation: OPERATION } },
        });
        if (current && now.getTime() - current.createdAt.getTime() < RESEND_WAIT_MS) {
          throw new TooManyRequestsError('Veuillez attendre 60 secondes avant de demander un nouveau code.');
        }
        return tx.phoneOtp.upsert({
          where: { phone_operation: { phone, operation: OPERATION } },
          create: {
            phone, operation: OPERATION, otpHash: otpHash(phone, code),
            createdAt: now, expiresAt: new Date(now.getTime() + OTP_TTL_MS), attempts: 0,
          },
          update: {
            otpHash: otpHash(phone, code), createdAt: now,
            expiresAt: new Date(now.getTime() + OTP_TTL_MS), attempts: 0, verifiedAt: null,
          },
        });
      });
    } catch (error: any) {
      // Concurrent first sends can race on the compound unique index.
      if (error?.code === 'P2002' || error?.code === 'P2034') {
        throw new TooManyRequestsError('Veuillez attendre 60 secondes avant de demander un nouveau code.');
      }
      throw error;
    }

    try {
      await sendVerificationSMS(phone, code);
    } catch (error) {
      // Keep the send timestamp for cooldown enforcement, but deactivate the
      // code because Orange did not accept the message.
      await prisma.phoneOtp.updateMany({
        where: { id: record.id, createdAt: now },
        data: { verifiedAt: now },
      });
      throw error;
    }
  }

  async verify(phone: string, code: string): Promise<boolean> {
    if (!/^\d{6}$/.test(code)) throw new BadRequestError('Le code doit contenir exactement 6 chiffres.');
    const current = await prisma.phoneOtp.findUnique({
      where: { phone_operation: { phone, operation: OPERATION } },
    });
    if (!current || current.verifiedAt || current.expiresAt <= new Date() || current.attempts >= MAX_ATTEMPTS) return false;

    const candidate = Buffer.from(otpHash(phone, code), 'hex');
    const stored = Buffer.from(current.otpHash, 'hex');
    const matches = candidate.length === stored.length && timingSafeEqual(candidate, stored);
    if (!matches) {
      const updated = await prisma.phoneOtp.updateMany({
        where: { id: current.id, attempts: { lt: MAX_ATTEMPTS }, expiresAt: { gt: new Date() } },
        data: { attempts: { increment: 1 } },
      });
      if (updated.count === 0) return false;
      return false;
    }

    // Mark conditionally so concurrent verification requests cannot both use
    // the same OTP. Retaining the row preserves the resend cooldown.
    const consumed = await prisma.phoneOtp.updateMany({
      where: { id: current.id, otpHash: current.otpHash, verifiedAt: null, attempts: { lt: MAX_ATTEMPTS }, expiresAt: { gt: new Date() } },
      data: { verifiedAt: new Date() },
    });
    return consumed.count === 1;
  }

  getDemoCode(): null { return null; }
}

export function createOtpProvider(): OtpProvider {
  // Deterministic fake is isolated to automated tests; production never falls
  // back to accepting a code without a real Orange SMS delivery.
  if (process.env.NODE_ENV === 'test') return new TestOtpProvider();
  return new SmsOtpProvider();
}

export class TestOtpProvider implements OtpProvider {
  readonly mode = 'sms' as const;
  async send(_phone: string, _code: string): Promise<void> {}
  async verify(_phone: string, code: string): Promise<boolean> { return code === '123456'; }
  getDemoCode(): null { return null; }
}

/** Secure six-digit decimal code; leading zeroes are preserved. */
export function generateOtp(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}
