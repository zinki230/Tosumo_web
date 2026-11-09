import { config } from '@shared/config';

type EmailParams = { to: string; subject: string; html: string; text?: string };

async function sendResendEmail(params: EmailParams): Promise<void> {
  if (!config.email.resendApiKey) throw new Error('RESEND_API_KEY is not configured.');
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.email.resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: config.email.from,
      to: [params.to],
      subject: params.subject,
      html: params.html,
      text: params.text,
    }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) {
    // Do not log the provider response body; it can include recipient data.
    console.error('[email] Resend request failed', { status: response.status });
    throw new Error(`Resend email request failed (${response.status}).`);
  }
}

export async function sendEmail(params: EmailParams): Promise<void> {
  if (process.env.NODE_ENV === 'test') return;
  if (!config.email.resendApiKey) {
    console.warn('[email] RESEND_API_KEY is missing; skipping non-critical email.');
    return;
  }
  try {
    await sendResendEmail(params);
  } catch (error) {
    console.error('[email] Non-critical email delivery failed:', error instanceof Error ? error.message : 'unknown error');
  }
}

export async function sendEmailOtp(email: string, code: string): Promise<void> {
  if (process.env.NODE_ENV === 'test') return;
  await sendResendEmail({
    to: email,
    subject: 'Votre code de vérification TOSUMO',
    text: `Votre code de vérification TOSUMO est ${code}. Il expire dans 5 minutes. Ne le partagez avec personne.`,
    html: `<div lang="fr"><h1>Vérification TOSUMO</h1><p>Votre code est :</p><p style="font-size:32px;font-weight:bold;letter-spacing:8px">${code}</p><p>Il expire dans 5 minutes. Ne le partagez avec personne.</p></div>`,
  });
}

export async function sendVerificationEmail(email: string, token: string): Promise<void> {
  const verificationUrl = `${config.apiUrl}/api/v1/auth/verify-email?token=${token}`;
  await sendEmail({
    to: email,
    subject: 'Verify your TOSUMO account',
    html: `<h1>Welcome to TOSUMO</h1><p>Click the link below to verify your email address:</p><a href="${verificationUrl}">Verify Email</a><p>This link expires in 24 hours.</p>`,
  });
}

export async function sendPasswordResetEmail(email: string, token: string): Promise<void> {
  const resetUrl = `${config.appUrl}/reset-password?token=${token}`;
  await sendEmail({
    to: email,
    subject: 'Reset your TOSUMO password',
    html: `<h1>Password Reset</h1><p>Click the link below to reset your password:</p><a href="${resetUrl}">Reset Password</a><p>This link expires in 1 hour.</p>`,
  });
}
