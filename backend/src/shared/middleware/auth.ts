import { Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '@shared/config';
import { JwtPayload, AuthenticatedRequest, UserRole } from '@shared/types';
import { UnauthorizedError, ForbiddenError } from '@shared/utils/errors';

function extractToken(req: AuthenticatedRequest): string | null {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }
  if (req.cookies?.accessToken) {
    return req.cookies.accessToken;
  }
  return null;
}

export function authenticate(req: AuthenticatedRequest, _res: Response, next: NextFunction): void {
  const token = extractToken(req);
  if (!token) {
    throw new UnauthorizedError('No authentication token provided');
  }

  try {
    const decoded = jwt.verify(token, config.jwt.accessSecret) as JwtPayload;
    req.user = decoded;
    next();
  } catch (error) {
    throw new UnauthorizedError('Invalid or expired token');
  }
}

export function optionalAuth(req: AuthenticatedRequest, _res: Response, next: NextFunction): void {
  const token = extractToken(req);
  if (!token) {
    next();
    return;
  }

  try {
    const decoded = jwt.verify(token, config.jwt.accessSecret) as JwtPayload;
    req.user = decoded;
  } catch {
    // Token invalid, continue without user
  }
  next();
}

export function authorize(...roles: UserRole[]) {
  return (req: AuthenticatedRequest, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      throw new UnauthorizedError('Authentication required');
    }
    if (!roles.includes(req.user.role as UserRole)) {
      throw new ForbiddenError('Insufficient permissions');
    }
    next();
  };
}
