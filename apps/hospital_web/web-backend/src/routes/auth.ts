import { Router, Request, Response, NextFunction } from 'express'
import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'
import { z } from 'zod'
import { User } from '../models/User'
import { Institution } from '../models/Institution'
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth'

const router = Router()

// ── Validation Schemas ──────────────────────────────────────────────────────
const loginSchema = z.object({
  phone: z.string().min(10),
  password: z.string().min(6)
})

const registerInstitutionSchema = z.object({
  name: z.string().min(2),
  type: z.enum(['hospital', 'clinic', 'health_center', 'polyclinic']),
  phone: z.string().min(10),
  email: z.string().email(),
  password: z.string().min(8),
  city: z.string().min(2),
  region: z.string().min(2),
  address: z.string().optional()
})

const registerDoctorSchema = z.object({
  firstName: z.string().min(2),
  lastName: z.string().min(2),
  phone: z.string().min(10),
  email: z.string().email().optional(),
  password: z.string().min(8),
  specialty: z.string().min(2),
  licenseNumber: z.string().min(2),
  institutionId: z.string()
})

// ── Helper Functions ────────────────────────────────────────────────────────
function generateTokens(userId: string, role: string, institutionId?: string) {
  const payload = { 
    userId, 
    role, 
    ...(institutionId && { institutionId })
  }

  const accessToken = jwt.sign(payload, process.env.JWT_ACCESS_SECRET!, {
    expiresIn: process.env.JWT_ACCESS_EXPIRES_IN as string || '15m'
  })

  const refreshToken = jwt.sign(payload, process.env.JWT_REFRESH_SECRET!, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN as string || '7d'
  })

  return { accessToken, refreshToken }
}

// ── Routes ──────────────────────────────────────────────────────────────────

// Login
router.post('/login', async (req, res, next) => {
  try {
    const { phone, password } = loginSchema.parse(req.body)

    // Find user
    const user = await User.findOne({ phone, isActive: true })
      .populate('createdInstitutions')

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      })
    }

    // Check password
    const isMatch = await bcrypt.compare(password, user.passwordHash)
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      })
    }

    // Generate tokens
    const institutionId = user.role === 'institution_admin' && user.createdInstitutions?.[0] 
      ? user.createdInstitutions[0]._id.toString() 
      : undefined

    const institutionName = user.role === 'institution_admin' && user.createdInstitutions?.[0] 
      ? (user.createdInstitutions[0] as any).name
      : undefined

    const tokens = generateTokens(user._id.toString(), user.role, institutionId)

    // Update last login
    user.lastLoginAt = new Date()
    await user.save()

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user: {
          id: user._id,
          phone: user.phone,
          email: user.email,
          role: user.role,
          institutionId,
          institutionName
        },
        tokens
      }
    })
  } catch (error) {
    next(error)
  }
})

// Register Institution
router.post('/register/institution', async (req, res, next) => {
  try {
    const input = registerInstitutionSchema.parse(req.body)

    // Check if phone/email already exists
    const existingUser = await User.findOne({
      $or: [{ phone: input.phone }, { email: input.email }]
    })

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Phone number or email already registered'
      })
    }

    // Hash password
    const rounds = parseInt(process.env.BCRYPT_ROUNDS || '12')
    const passwordHash = await bcrypt.hash(input.password, rounds)

    // Create user and institution
    const user = new User({
      phone: input.phone,
      email: input.email,
      passwordHash,
      role: 'institution_admin',
      isActive: true,
      isEmailVerified: true
    })

    const institution = new Institution({
      name: input.name,
      type: input.type,
      phone: input.phone,
      email: input.email,
      city: input.city,
      region: input.region,
      address: input.address,
      createdBy: user._id,
      isVerified: true // Auto-verify for web app
    })

    await user.save()
    await institution.save()

    // Add institution to user
    user.createdInstitutions = [institution._id]
    await user.save()

    // Generate tokens
    const tokens = generateTokens(user._id.toString(), user.role, institution._id.toString())

    res.status(201).json({
      success: true,
      message: 'Institution registered successfully',
      data: {
        user: {
          id: user._id,
          phone: user.phone,
          email: user.email,
          role: user.role,
          institutionId: institution._id,
          institutionName: institution.name
        },
        tokens
      }
    })
  } catch (error) {
    next(error)
  }
})

// Register Doctor (by Institution Admin)
router.post('/register/doctor', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (req.user.role !== 'institution_admin') {
      return res.status(403).json({
        success: false,
        message: 'Only institution admins can register doctors'
      })
    }

    const input = registerDoctorSchema.parse(req.body)

    // Verify institution belongs to user
    if (input.institutionId !== req.user.institutionId) {
      return res.status(403).json({
        success: false,
        message: 'You can only add doctors to your institution'
      })
    }

    // Check if doctor already exists
    const existingUser = await User.findOne({
      $or: [{ phone: input.phone }, ...(input.email ? [{ email: input.email }] : [])]
    })

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Doctor with this phone/email already exists'
      })
    }

    // Hash password
    const rounds = parseInt(process.env.BCRYPT_ROUNDS || '12')
    const passwordHash = await bcrypt.hash(input.password, rounds)

    // Create doctor user
    const user = new User({
      phone: input.phone,
      email: input.email,
      passwordHash,
      role: 'doctor',
      isActive: true
    })

    await user.save()

    res.status(201).json({
      success: true,
      message: 'Doctor registered successfully',
      data: {
        id: user._id,
        phone: user.phone,
        email: user.email,
        role: user.role
      }
    })
  } catch (error) {
    next(error)
  }
})

// Get Profile
router.get('/profile', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const user = await User.findById(req.user.userId)
      .populate('createdInstitutions')
      .select('-passwordHash')

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      })
    }

    const institutionName = user.createdInstitutions?.[0] 
      ? (user.createdInstitutions[0] as any).name
      : undefined

    res.json({
      success: true,
      data: {
        id: user._id,
        phone: user.phone,
        email: user.email,
        role: user.role,
        isActive: user.isActive,
        lastLoginAt: user.lastLoginAt,
        institutionId: user.createdInstitutions?.[0]?._id,
        institutionName
      }
    })
  } catch (error) {
    next(error)
  }
})

// Refresh Token
router.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body

    if (!refreshToken) {
      return res.status(401).json({
        success: false,
        message: 'Refresh token required'
      })
    }

    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET!) as any
    const user = await User.findById(decoded.userId)

    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'Invalid refresh token'
      })
    }

    const tokens = generateTokens(user._id.toString(), user.role, decoded.institutionId)

    res.json({
      success: true,
      data: { tokens }
    })
  } catch (error) {
    next(error)
  }
})

// Logout
router.post('/logout', authMiddleware, (req: AuthenticatedRequest, res: Response) => {
  res.json({
    success: true,
    message: 'Logged out successfully'
  })
})

export default router