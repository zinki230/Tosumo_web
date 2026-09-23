import { Request, Response, NextFunction } from 'express'
import jwt from 'jsonwebtoken'
import { User } from '../models/User'

export interface AuthenticatedRequest extends Request {
  user: {
    userId: string
    role: string
    institutionId?: string
  }
}

export interface JWTPayload {
  userId: string
  role: string
  institutionId?: string
  iat?: number
  exp?: number
}

export async function authMiddleware(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '')

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. No token provided'
      })
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET!) as JWTPayload

    // Check if user still exists and is active
    const user = await User.findById(decoded.userId).select('isActive role')
    
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'Invalid token - user not found or inactive'
      })
    }

    // Attach user info to request
    req.user = {
      userId: decoded.userId,
      role: decoded.role,
      institutionId: decoded.institutionId
    }

    next()
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({
        success: false,
        message: 'Token expired'
      })
    }

    if (error instanceof jwt.JsonWebTokenError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid token'
      })
    }

    res.status(401).json({
      success: false,
      message: 'Token verification failed'
    })
  }
}

// Role-based authorization middleware
export function authorize(...roles: string[]) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. Authentication required'
      })
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Insufficient permissions'
      })
    }

    next()
  }
}

// Institution admin can only access their own institution's data
export function requireInstitutionAccess(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  if (req.user.role === 'institution_admin' && !req.user.institutionId) {
    return res.status(403).json({
      success: false,
      message: 'Institution access required'
    })
  }

  next()
}