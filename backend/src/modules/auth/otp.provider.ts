import { config } from '@shared/config';
import { sendVerificationSMS } from '@shared/services/sms';

export interface OtpProvider {
  readonly mode: 'demo' | 'sms';
  send(phone: string, code: string): Promise<void>;
  verify(phone: string, code: string): Promise<boolean>;
  getDemoCode(): string | null;
}

export class DemoOtpProvider implements OtpProvider {
  readonly mode = 'demo' as const;

  async send(_phone: string, _code: string): Promise<void> {
    // Simulated delivery: no external SMS provider is configured for this prototype.
  }

  async verify(_phone: string, code: string): Promise<boolean> {
    // Demo mode: any well-formed 6-digit code is accepted so investor demos
    // never block on an actual SMS. The backend still performs the real
    // account lookup and issues real JWTs.
    return /^\d{6}$/.test(code);
  }

  getDemoCode(): string | null {
    return null;
  }
}

export class SmsOtpProvider implements OtpProvider {
  readonly mode = 'sms' as const;

  private store = new Map<string, { code: string; expiresAt: number }>();

  async send(phone: string, code: string): Promise<void> {
    this.store.set(phone, { code, expiresAt: Date.now() + 10 * 60 * 1000 });
    await sendVerificationSMS(phone, code);
  }

  async verify(phone: string, code: string): Promise<boolean> {
    const stored = this.store.get(phone);
    if (!stored) return false;
    if (Date.now() > stored.expiresAt) {
      this.store.delete(phone);
      return false;
    }
    if (stored.code !== code) return false;
    this.store.delete(phone);
    return true;
  }

  getDemoCode(): string | null {
    return null;
  }
}

export function createOtpProvider(): OtpProvider {
  const smsConfigured = Boolean(
    config.sms.apiKey &&
    config.sms.username &&
    !config.sms.username.includes('your-') &&
    config.sms.apiKey !== 'your-africastalking-api-key'
  );

  if (config.otpMode === 'provider') {
    // Provider mode requires the SMS integration to be configured. If it is
    // missing we still behave (fall back to demo) but flag it at startup.
    return smsConfigured ? new SmsOtpProvider() : new DemoOtpProvider();
  }

  return smsConfigured ? new SmsOtpProvider() : new DemoOtpProvider();
}
