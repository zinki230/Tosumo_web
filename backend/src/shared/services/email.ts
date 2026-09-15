import nodemailer from 'nodemailer';
import { config } from '@shared/config';

let transporter: nodemailer.Transporter | null = null;

/// True when an SMTP server is actually configured. When false, email is
/// treated as an optional/disconnected integration and we never attempt a TCP
/// connection (which would otherwise hit 127.0.0.1:587 in production and spam
/// ECONNREFUSED). Registration and verification must not block on email.
function isEmailConfigured(): boolean {
  return (
    config.email.host.trim().length > 0 &&
    config.email.user.trim().length > 0 &&
    config.email.pass.trim().length > 0
  );
}

function getTransporter(): nodemailer.Transporter {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: config.email.host,
      port: config.email.port,
      secure: config.email.port === 465,
      auth: {
        user: config.email.user,
        pass: config.email.pass,
      },
    });
  }
  return transporter;
}

export async function sendEmail(params: {
  to: string;
  subject: string;
  html: string;
  text?: string;
}): Promise<void> {
  if (process.env.NODE_ENV === 'test') return;

  // Optional integration: never block the caller (or registration) on email.
  if (!isEmailConfigured()) {
    console.warn(
      '[email] SMTP provider not configured — skipping outbound email (non-blocking). ' +
        'Set EMAIL_HOST/EMAIL_USER/EMAIL_PASS to enable verification & password-reset emails.',
    );
    return;
  }

  try {
    await getTransporter().sendMail({
      from: config.email.from,
      to: params.to,
      subject: params.subject,
      text: params.text,
      html: params.html,
    });
  } catch (error) {
    console.error('[email] Failed to send email (non-blocking):', error);
  }
}

export async function sendVerificationEmail(email: string, token: string): Promise<void> {
  const verificationUrl = `${config.apiUrl}/api/v1/auth/verify-email?token=${token}`;
  await sendEmail({
    to: email,
    subject: 'Verify your TOSUMO account',
    html: `
      <h1>Welcome to TOSUMO</h1>
      <p>Click the link below to verify your email address:</p>
      <a href="${verificationUrl}" style="display:inline-block;padding:12px 24px;background:#0066CC;color:white;text-decoration:none;border-radius:4px;">Verify Email</a>
      <p>This link expires in 24 hours.</p>
    `,
  });
}

export async function sendPasswordResetEmail(email: string, token: string): Promise<void> {
  const resetUrl = `${config.appUrl}/reset-password?token=${token}`;
  await sendEmail({
    to: email,
    subject: 'Reset your TOSUMO password',
    html: `
      <h1>Password Reset</h1>
      <p>Click the link below to reset your password:</p>
      <a href="${resetUrl}" style="display:inline-block;padding:12px 24px;background:#0066CC;color:white;text-decoration:none;border-radius:4px;">Reset Password</a>
      <p>This link expires in 1 hour.</p>
    `,
  });
}
