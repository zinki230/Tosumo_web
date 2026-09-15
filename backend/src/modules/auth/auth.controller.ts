import { Response, NextFunction } from 'express';
import { AuthService } from './auth.service';
import { AuthenticatedRequest } from '@shared/types';
import { registerSchema, loginSchema, refreshTokenSchema, sendOtpSchema, verifyOtpSchema, changePasswordSchema, resetPasswordSchema, checkPhoneSchema } from './auth.validation';

const authService = new AuthService();

export class AuthController {
  async register(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const input = registerSchema.parse(req.body);
      const result = await authService.register(input);
      res.status(201).json({ success: true, message: 'Registration successful', data: result });
    } catch (error) {
      next(error);
    }
  }

  async login(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const input = loginSchema.parse(req.body);
      const result = await authService.login(input);
      res.json({ success: true, message: 'Login successful', data: result });
    } catch (error) {
      next(error);
    }
  }

  async otpLogin(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { phone, code } = verifyOtpSchema.parse(req.body);
      const result = await authService.otpLogin(phone, code);
      res.json({ success: true, message: 'Login successful', data: result });
    } catch (error) {
      next(error);
    }
  }

  async refresh(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { refreshToken } = refreshTokenSchema.parse(req.body);
      const tokens = await authService.refresh(refreshToken);
      res.json({ success: true, data: tokens });
    } catch (error) {
      next(error);
    }
  }

  async logout(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await authService.logout(req.user!.userId);
      res.json({ success: true, message: 'Logged out successfully' });
    } catch (error) {
      next(error);
    }
  }

  async getProfile(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const profile = await authService.getProfile(req.user!.userId);
      res.json({ success: true, data: profile });
    } catch (error) {
      next(error);
    }
  }

  async changePassword(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { currentPassword, newPassword } = changePasswordSchema.parse(req.body);
      await authService.changePassword(req.user!.userId, currentPassword, newPassword);
      res.json({ success: true, message: 'Password changed successfully' });
    } catch (error) {
      next(error);
    }
  }

  async updateFcmToken(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { fcmToken } = req.body;
      await authService.updateFcmToken(req.user!.userId, fcmToken);
      res.json({ success: true, message: 'FCM token updated' });
    } catch (error) {
      next(error);
    }
  }

  async checkPhone(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { phone } = checkPhoneSchema.parse(req.body);
      const result = await authService.checkPhone(phone);
      res.json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async sendOtp(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { phone } = sendOtpSchema.parse(req.body);
      const result = await authService.sendOtp(phone);
      res.json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async verifyOtp(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { phone, code } = verifyOtpSchema.parse(req.body);
      const result = await authService.verifyOtp(phone, code);
      res.json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  async resetPassword(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { phone, code, newPassword } = resetPasswordSchema.parse(req.body);
      const result = await authService.resetPassword(phone, code, newPassword);
      res.json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }
}
