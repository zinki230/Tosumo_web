import './register-aliases';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import cookieParser from 'cookie-parser';
import { config } from '@shared/config';
import prisma from '@shared/database/prisma';
import { errorHandler } from '@shared/middleware/errorHandler';
import { apiLimiter, authLimiter } from '@shared/middleware/rateLimiter';

import authRoutes from '@modules/auth/auth.routes';
import patientRoutes from '@modules/patients/patient.routes';
import doctorRoutes from '@modules/doctors/doctor.routes';
import appointmentRoutes from '@modules/appointments/appointment.routes';
import medicalRecordsRoutes from '@modules/medical-records/medical-records.routes';
import chatRoutes from '@modules/chat/chat.routes';
import notificationRoutes from '@modules/notifications/notification.routes';
import accessRoutes from '@modules/access/access.routes';
import emergencyRoutes from '@modules/emergency/emergency.routes';
import institutionRoutes from '@modules/institutions/institution.routes';
import paymentRoutes from '@modules/payments/payment.routes';
import uploadRoutes from '@modules/uploads/upload.routes';
import syncRoutes from '@modules/sync/sync.routes';
import auditRoutes from '@modules/audit/audit.routes';
import adminRoutes from '@modules/admin/admin.routes';
import cardsRoutes from '@modules/cards/cards.routes';

const app = express();

// Trust the Railway / reverse-proxy hop so express-rate-limit can read the real
// client IP from X-Forwarded-For. Without this, rate-limit throws
// ERR_ERL_UNEXPECTED_X_FORWARDED_FOR when the proxy forwards that header.
app.set('trust proxy', 1);

// Security
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
const allowedOrigins = config.cors.origins;
app.use(
  cors({
    origin(origin, callback) {
      // Non-browser clients (curl, mobile SDKs, Postman) send no Origin header.
      if (!origin) return callback(null, true);
      // Explicit allow-list from CORS_ORIGINS env (comma separated).
      if (allowedOrigins.includes(origin)) return callback(null, true);
      // Local development origins: Flutter Web dev server runs on a random
      // localhost port, so allow any localhost/127.0.0.1 origin.
      if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
        return callback(null, true);
      }
      // Allow Vercel domains for hospital web app (all Vercel preview and production URLs)
      if (/^https:\/\/.*\.vercel\.app$/.test(origin)) {
        return callback(null, true);
      }
      // Additional safety: allow specific Vercel preview domains
      if (origin && origin.includes('vercel.app')) {
        return callback(null, true);
      }
      callback(new Error('CORS: origin not allowed'));
    },
    credentials: true,
  }),
);

// Performance
app.use(compression());

// Parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// Logging
if (config.nodeEnv !== 'test') {
  app.use(morgan('dev'));
}

// Static files for uploads
app.use('/uploads', express.static(config.upload.dir));

// Rate limiting
app.use('/api/', apiLimiter);

// Health checks
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'tosumo-backend' });
});

app.get('/health/ready', async (_req, res) => {
  try {
    await prisma.$runCommandRaw({ ping: 1 });
    res.json({ status: 'ok', service: 'tosumo-backend', database: 'connected' });
  } catch {
    res.status(503).json({ status: 'degraded', service: 'tosumo-backend', database: 'disconnected' });
  }
});

app.get('/api/v1/health', (_req, res) => {
  res.json({ success: true, message: 'TOSUMO API is running', timestamp: new Date().toISOString() });
});

// API Routes
app.use('/api/v1/auth', authLimiter, authRoutes);
app.use('/api/v1/patients', patientRoutes);
app.use('/api/v1/doctors', doctorRoutes);
app.use('/api/v1/appointments', appointmentRoutes);
app.use('/api/v1/medical-records', medicalRecordsRoutes);
app.use('/api/v1/chat', chatRoutes);
app.use('/api/v1/notifications', notificationRoutes);
app.use('/api/v1/access', accessRoutes);
app.use('/api/v1/emergency', emergencyRoutes);
app.use('/api/v1/institutions', institutionRoutes);
app.use('/api/v1/payments', paymentRoutes);
app.use('/api/v1/upload', uploadRoutes);
app.use('/api/v1/sync', syncRoutes);
app.use('/api/v1/audit-logs', auditRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/cards', cardsRoutes);

// Swagger docs
if (config.nodeEnv !== 'production') {
  const swaggerUi = require('swagger-ui-express');
  const swaggerSpec = require('./swagger');
  app.use('/api/v1/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
}

// Error handling
app.use(errorHandler);

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

export default app;
