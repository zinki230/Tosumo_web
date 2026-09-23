import { Router, Request, Response, NextFunction } from 'express'
import { User } from '../models/User'
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth'

const router = Router()

// Get all doctors (filtered by institution for institution_admin)
router.get('/', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const { limit = '50', specialty, search } = req.query
    
    let query: any = { 
      role: 'doctor', 
      isActive: true 
    }

    // Filter by institution for institution_admin
    if (req.user.role === 'institution_admin') {
      query.createdBy = req.user.userId
    }

    if (specialty) {
      query.specialty = specialty
    }

    if (search) {
      const searchRegex = new RegExp(search as string, 'i')
      query.$or = [
        { firstName: searchRegex },
        { lastName: searchRegex },
        { phone: searchRegex },
        { email: searchRegex }
      ]
    }

    const doctors = await User.find(query)
      .select('phone email firstName lastName specialty licenseNumber isActive createdAt')
      .limit(parseInt(limit as string))
      .sort({ createdAt: -1 })

    // Transform to match frontend expectations
    const transformedDoctors = doctors.map(doc => ({
      id: doc._id,
      firstName: doc.firstName || '',
      lastName: doc.lastName || '',
      fullName: `${doc.firstName || ''} ${doc.lastName || ''}`.trim() || 'Médecin',
      phone: doc.phone,
      email: doc.email,
      specialty: doc.specialty || '',
      licenseNumber: doc.licenseNumber || '',
      isVerified: true, // All doctors created via web are verified
      isAvailable: true,
      averageRating: 0,
      totalRatings: 0
    }))

    res.json({
      success: true,
      data: { doctors: transformedDoctors }
    })
  } catch (error) {
    next(error)
  }
})

// Get doctor by ID
router.get('/:id', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const doctor = await User.findOne({
      _id: req.params.id,
      role: 'doctor'
    }).select('phone email firstName lastName specialty licenseNumber isActive createdAt')

    if (!doctor) {
      return res.status(404).json({
        success: false,
        message: 'Doctor not found'
      })
    }

    // Check access for institution_admin
    if (req.user.role === 'institution_admin' && doctor.createdBy?.toString() !== req.user.userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      })
    }

    const transformed = {
      id: doctor._id,
      firstName: doctor.firstName || '',
      lastName: doctor.lastName || '',
      fullName: `${doctor.firstName || ''} ${doctor.lastName || ''}`.trim() || 'Médecin',
      phone: doctor.phone,
      email: doctor.email,
      specialty: doctor.specialty || '',
      licenseNumber: doctor.licenseNumber || '',
      isVerified: true,
      isAvailable: true,
      averageRating: 0,
      totalRatings: 0,
      patientCount: 0 // Could calculate from appointments
    }

    res.json({
      success: true,
      data: transformed
    })
  } catch (error) {
    next(error)
  }
})

// Update doctor status
router.put('/:id/status', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (req.user.role !== 'institution_admin') {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      })
    }

    const { isActive } = req.body

    const doctor = await User.findOneAndUpdate(
      {
        _id: req.params.id,
        role: 'doctor',
        createdBy: req.user.userId
      },
      { isActive, updatedAt: new Date() },
      { new: true }
    ).select('phone email firstName lastName isActive')

    if (!doctor) {
      return res.status(404).json({
        success: false,
        message: 'Doctor not found'
      })
    }

    res.json({
      success: true,
      message: `Doctor ${isActive ? 'activated' : 'deactivated'} successfully`,
      data: doctor
    })
  } catch (error) {
    next(error)
  }
})

export default router