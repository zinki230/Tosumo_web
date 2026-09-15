import dotenv from 'dotenv';
dotenv.config();

const databaseUrl = process.env.MONGODB_URI || process.env.DATABASE_URL || '';
process.env.DATABASE_URL = databaseUrl;

// Secret used to sign patient medical-card QR tokens. Falls back to the JWT
// access secret so it works out of the box; override with QR_TOKEN_SECRET in
// production for token / access-token separation.
const qrTokenSecret =
  process.env.QR_TOKEN_SECRET || process.env.JWT_ACCESS_SECRET || 'dev-qr-secret';

const qrTokenExpiresInMinutes = parseInt(
  process.env.QR_TOKEN_EXPIRES_MIN || '10',
  10,
);

export const config = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3000', 10),
  host: process.env.HOST || '0.0.0.0',
  apiUrl: process.env.API_URL || 'http://localhost:3000',
  appUrl: process.env.APP_URL || 'https://tosumo.cm',

  database: {
    url: databaseUrl,
  },

  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET || 'dev-access-secret',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret',
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  },

  encryption: {
    key: process.env.ENCRYPTION_KEY || 'default-encryption-key-32chr!',
  },

  upload: {
    dir: process.env.UPLOAD_DIR || './uploads',
    maxFileSize: parseInt(process.env.MAX_FILE_SIZE || '10485760', 10),
  },

  email: {
    host: process.env.SMTP_HOST || '',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.EMAIL_FROM || 'noreply@tosumo.cm',
  },

  sms: {
    apiKey: process.env.SMS_API_KEY || '',
    username: process.env.SMS_USERNAME || '',
  },

  // OTP delivery mode.
  // - 'demo': no external SMS, any 6-digit code is accepted (prototype / investor demo).
  // - 'provider': real SMS delivery through the configured provider; requires
  //   SMS_API_KEY / SMS_USERNAME. Defaults to 'demo' for safety.
  otpMode: (process.env.OTP_MODE || 'demo') as 'demo' | 'provider',

  demo: {
    otp: process.env.DEMO_OTP || '123456',
    patientPhone: process.env.DEMO_PATIENT_PHONE || '+237691234567',
    patientPassword: process.env.DEMO_PATIENT_PASSWORD || 'Asonte@6900',
    patientEmail: process.env.DEMO_PATIENT_EMAIL || 'demo@tosumo.cm',
    patientNin: process.env.DEMO_PATIENT_NIN || 'NIN-DEMO-1985-0314-001',
  },

  payment: {
    provider: process.env.PAYMENT_PROVIDER || 'mock',
  },

  socket: {
    path: process.env.SOCKET_PATH || '/ws',
  },

  qr: {
    tokenSecret: qrTokenSecret,
    tokenExpiresInMinutes: Number.isFinite(qrTokenExpiresInMinutes)
      ? qrTokenExpiresInMinutes
      : 10,
  },

  cors: {
    origins: (process.env.CORS_ORIGINS || 'http://localhost:3000').split(','),
  },
} as const;

const isPlaceholder = (value: string, prefixes: string[]): boolean =>
  prefixes.some(p => value.startsWith(p));

/**
 * Startup environment validation.
 * - Missing REQUIRED variables block startup in production with a clear report.
 * - OPTIONAL integrations (SMS, payments, push, email) never block startup.
 */
export function validateEnvironment(): { warnings: string[] } {
  const warnings: string[] = [];
  const production = config.nodeEnv === 'production';

  const required = [
    ['DATABASE_URL', config.database.url],
    ['JWT_ACCESS_SECRET', config.jwt.accessSecret],
    ['JWT_REFRESH_SECRET', config.jwt.refreshSecret],
  ];

  const missing = required.filter(
    ([, v]) =>
      !v ||
      isPlaceholder(v, ['dev-', 'default-', 'your-', 'change-me', 'replace_with_strong'])
  );

  if (production && missing.length > 0) {
    console.error(
      '\nEnvironment validation failed. Required variables missing or insecure in production:\n' +
        missing.map(([n]) => `  - ${n}`).join('\n') +
        '\nSet strong values (openssl rand -hex 32) before starting.\n'
    );
    process.exit(1);
  }

  // Demo-mode notices for optional external integrations.
  const smsConfigured =
    config.sms.apiKey && config.sms.username &&
    !isPlaceholder(config.sms.username, ['your-']) &&
    config.sms.apiKey !== 'your-africastalking-api-key';
  if (config.otpMode === 'provider' && !smsConfigured) {
    warnings.push(
      'OTP_MODE=provider but SMS provider not configured — OTP will fall back to DEMO mode'
    );
  } else if (!smsConfigured) {
    warnings.push('SMS provider not configured — OTP in DEMO mode');
  }
  if (!config.payment.provider || config.payment.provider === 'mock') {
    warnings.push('Payment provider not configured — running with MOCK payments');
  }
  if (!config.email.host) {
    warnings.push('SMTP not configured — email notifications disabled');
  }
  if (!config.encryption.key || isPlaceholder(config.encryption.key, ['default-', 'change-me', 'your-'])) {
    warnings.push('ENCRYPTION_KEY not set — sensitive-field encryption disabled');
  }

  return { warnings };
}

validateEnvironment();
