import { Router } from 'express';
import { AuthController } from './auth.controller';
import { authenticate } from '@shared/middleware/auth';
import { authLimiter, otpSendLimiter } from '@shared/middleware/rateLimiter';

const router = Router();
const controller = new AuthController();

router.post('/register', authLimiter, controller.register);
router.post('/register/doctor', authLimiter, controller.registerDoctor);
router.post('/register/institution', authLimiter, controller.registerInstitution);
router.post('/login', authLimiter, controller.login);
router.post('/otp-login', authLimiter, controller.otpLogin);
router.post('/refresh', controller.refresh);
router.post('/logout', authenticate, controller.logout);
router.get('/profile', authenticate, controller.getProfile);
router.put('/change-password', authenticate, controller.changePassword);
router.put('/fcm-token', authenticate, controller.updateFcmToken);
router.post('/check-phone', authLimiter, controller.checkPhone);
router.post('/send-otp', authLimiter, otpSendLimiter, controller.sendOtp);
router.post('/resend-otp', authLimiter, otpSendLimiter, controller.sendOtp);
router.post('/verify-otp', authLimiter, controller.verifyOtp);
router.post('/reset-password', controller.resetPassword);

export default router;
