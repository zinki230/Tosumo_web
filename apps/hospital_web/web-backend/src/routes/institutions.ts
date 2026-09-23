import { Router, Request, Response, NextFunction } from 'express'
import { z } from 'zod'
import { Institution } from '../models/Institution'
import { User } from '../models/User'
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth'

const router = Router()

// ── Validation Schemas ──────────────────────────────────────────────────────
const updateInstitutionSchema = z.object({
  name: z.string().min(2).optional(),
  address: z.string().optional(),
  city: z.string().min(2).optional(),
  region: z.string().min(2).optional(),
  phone: z.string().min(10).optional(),
  email: z.string().email().optional()
})

const createDoctorSchema = z.object({
  firstName: z.string().min(2),
  lastName: z.string().min(2),
  phone: z.string().min(10),
  email: z.string().email().optional(),
  specialty: z.string().min(2),
  licenseNumber: z.string().min(2)
})

// ── Routes ──────────────────────────────────────────────────────────────────

// Get all institutions (for dropdowns)
router.get('/', async (req, res, next) => {
  try {
    const { limit = '50', verified = 'true' } = req.query

    const query: any = {}
    if (verified === 'true') query.isVerified = true

    const institutions = await Institution.find(query)
      .limit(parseInt(limit as string))
      .select('name type city region phone email isVerified')
      .sort({ name: 1 })

    res.json({
      success: true,
      data: { institutions }
    })
  } catch (error) {
    next(error)
  }
})

// Get my institution (for institution admin)
router.get('/my', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (req.user.role !== 'institution_admin') {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      })
    }

    const institution = await Institution.findById(req.user.institutionId)
      .populate('createdBy', 'phone email')

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      })
    }

    res.json({
      success: true,
      data: institution
    })
  } catch (error) {
    next(error)
  }
})

// Update my institution
router.put('/my', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (req.user.role !== 'institution_admin') {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      })
    }

    const updateData = updateInstitutionSchema.parse(req.body)
    
    const institution = await Institution.findByIdAndUpdate(
      req.user.institutionId,
      { ...updateData, updatedAt: new Date() },
      { new: true, runValidators: true }
    )

    if (!institution) {
      return res.status(404).json({
        success: false,
        message: 'Institution not found'
      })
    }

    res.json({
      success: true,
      message: 'Institution updated successfully',
      data: institution
    })
  } catch (error) {
    next(error)
  }
})

// Create doctor in my institution
router.post('/doctors', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (req.user.role !== 'institution_admin') {
      return res.status(403).json({
        success: false,
        message: 'Only institution admins can create doctors'
      })
    }

    const input = createDoctorSchema.parse(req.body)

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

    // For web app, we'll create a simple doctor record
    // Password will be generated and sent via SMS/email in real implementation
    const tempPassword = 'TempDoc@123'
    const bcrypt = await import('bcrypt')
    const passwordHash = await bcrypt.hash(tempPassword, 12)

    const doctor = new User({
      phone: input.phone,
      email: input.email,
      passwordHash,
      role: 'doctor',
      isActive: true,
      createdBy: req.user.userId
    })

    await doctor.save()

    res.status(201).json({
      success: true,
      message: 'Doctor created successfully',
      data: {
        id: doctor._id,
        phone: doctor.phone,
        email: doctor.email,
        firstName: input.firstName,
        lastName: input.lastName,
        specialty: input.specialty,
        licenseNumber: input.licenseNumber,
        tempPassword // In real app, send via SMS
      }
    })
  } catch (error) {
    next(error)
  }
})

// Get doctors in my institution
router.get('/doctors/list', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (req.user.role !== 'institution_admin') {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      })
    }

    const doctors = await User.find({
      role: 'doctor',
      createdBy: req.user.userId,
      isActive: true
    })
    .select('phone email firstName lastName isActive createdAt')
    .sort({ createdAt: -1 })

    res.json({
      success: true,
      data: doctors
    })
  } catch (error) {
    next(error)
  }
})

export default router