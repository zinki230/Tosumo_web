import { createHmac } from 'node:crypto';
import { config } from '../src/shared/config';

const phoneOtpMock = {
  findUnique: jest.fn(),
  upsert: jest.fn(),
  updateMany: jest.fn(),
};
const prismaMock = {
  $transaction: jest.fn((fn: (tx: any) => unknown) => fn({ phoneOtp: phoneOtpMock })),
  phoneOtp: phoneOtpMock,
};

jest.mock('../src/shared/database/prisma', () => ({ __esModule: true, default: prismaMock }));
jest.mock('../src/shared/services/sms', () => ({ sendVerificationSMS: jest.fn() }));

import { SmsOtpProvider, generateOtp } from '../src/modules/auth/otp.provider';
import prisma from '../src/shared/database/prisma';
import { sendVerificationSMS } from '../src/shared/services/sms';

describe('Orange OTP provider', () => {
  const phone = '+237690000001';
  const provider = new SmsOtpProvider();
  const otpMocks = prisma.phoneOtp as any;

  beforeEach(() => jest.clearAllMocks());

  it('generates a cryptographically random six digit string', () => {
    const code = generateOtp();
    expect(code).toMatch(/^\d{6}$/);
  });

  it('stores only an HMAC and sends the generated code through Orange', async () => {
    otpMocks.findUnique.mockResolvedValue(null);
    otpMocks.upsert.mockImplementation(async ({ create }: any) => ({ id: 'otp1', ...create }));

    await provider.send(phone, '001234');

    const stored = otpMocks.upsert.mock.calls[0][0].create;
    expect(stored.otpHash).toMatch(/^[a-f0-9]{64}$/);
    expect(stored.otpHash).not.toContain('001234');
    expect(stored.expiresAt.getTime() - stored.createdAt.getTime()).toBe(5 * 60 * 1000);
    expect(sendVerificationSMS).toHaveBeenCalledWith(phone, '001234');
  });

  it('enforces the resend cooldown based on the persisted send time', async () => {
    otpMocks.findUnique.mockResolvedValue({ createdAt: new Date() });
    await expect(provider.send(phone, '001234')).rejects.toThrow('60 secondes');
    expect(otpMocks.upsert).not.toHaveBeenCalled();
  });

  it('does not accept expired, consumed, or exhausted codes', async () => {
    otpMocks.findUnique.mockResolvedValue({
      id: 'otp1', otpHash: '0'.repeat(64), attempts: 0,
      expiresAt: new Date(Date.now() - 1), verifiedAt: null,
    });
    await expect(provider.verify(phone, '001234')).resolves.toBe(false);
    expect(otpMocks.updateMany).not.toHaveBeenCalled();
  });

  it('increments failed attempts and blocks verification after five failures', async () => {
    otpMocks.findUnique.mockResolvedValue({
      id: 'otp1', otpHash: '0'.repeat(64), attempts: 0,
      expiresAt: new Date(Date.now() + 60_000), verifiedAt: null,
    });
    otpMocks.updateMany.mockResolvedValue({ count: 1 });
    await expect(provider.verify(phone, '001234')).resolves.toBe(false);
    expect(otpMocks.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: { attempts: { increment: 1 } },
    }));

    otpMocks.findUnique.mockResolvedValue({
      id: 'otp1', otpHash: '0'.repeat(64), attempts: 5,
      expiresAt: new Date(Date.now() + 60_000), verifiedAt: null,
    });
    otpMocks.updateMany.mockClear();
    await expect(provider.verify(phone, '001234')).resolves.toBe(false);
    expect(otpMocks.updateMany).not.toHaveBeenCalled();
  });

  it('consumes a correct code once and rejects reuse', async () => {
    const code = '001234';
    const otpHash = createHmac('sha256', config.sms.otpHashSecret)
      .update(`phone_verification:${phone}:${code}`).digest('hex');
    otpMocks.findUnique.mockResolvedValue({
      id: 'otp1', otpHash, attempts: 0,
      expiresAt: new Date(Date.now() + 60_000), verifiedAt: null,
    });
    otpMocks.updateMany.mockResolvedValue({ count: 1 });
    await expect(provider.verify(phone, code)).resolves.toBe(true);
    expect(otpMocks.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ verifiedAt: null, otpHash }),
      data: { verifiedAt: expect.any(Date) },
    }));

    otpMocks.findUnique.mockResolvedValue({
      id: 'otp1', otpHash, attempts: 0,
      expiresAt: new Date(Date.now() + 60_000), verifiedAt: new Date(),
    });
    await expect(provider.verify(phone, code)).resolves.toBe(false);
  });

  it('allows a new request after 60 seconds and replaces the active hash', async () => {
    const oldCreatedAt = new Date(Date.now() - 60_001);
    otpMocks.findUnique.mockResolvedValue({ createdAt: oldCreatedAt });
    otpMocks.upsert.mockImplementation(async ({ create }: any) => ({ id: 'otp1', ...create }));
    await provider.send(phone, '654321');
    const write = otpMocks.upsert.mock.calls[0][0];
    const previousHash = createHmac('sha256', config.sms.otpHashSecret)
      .update(`phone_verification:${phone}:001234`).digest('hex');
    expect(write.create.otpHash).not.toBe(previousHash);
    otpMocks.findUnique.mockResolvedValue({
      id: 'otp1', otpHash: write.create.otpHash, attempts: 0,
      expiresAt: new Date(Date.now() + 60_000), verifiedAt: null,
    });
    otpMocks.updateMany.mockResolvedValue({ count: 1 });
    await expect(provider.verify(phone, '001234')).resolves.toBe(false);
    expect(sendVerificationSMS).toHaveBeenCalledWith(phone, '654321');
  });
});
