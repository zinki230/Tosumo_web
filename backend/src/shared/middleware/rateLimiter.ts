import rateLimit from 'express-rate-limit';

// Rate limiting is disabled under tests so the integration suite can issue
// many auth calls without tripping the limiter.
const isTest = () => process.env.NODE_ENV === 'test';

export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  skip: isTest,
  message: {
    success: false,
    message: 'Too many requests, please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  // Generous limit: a normal flow (check-phone + send-otp + verify-otp +
  // register/login, with a few retries) must never trip this. Behind Railway
  // the real client IP is recovered via `trust proxy`, so this is per-client.
  max: 100,
  skip: isTest,
  message: {
    success: false,
    message: 'Too many authentication attempts, please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
});
