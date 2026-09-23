import { Router, Request, Response, NextFunction } from 'express'
import { User } from '../models/User'
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth'

const router = Router()

// Get all patients (basic implementation for web app)
router.get('/', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const { limit = '100', verified, search } = req.query
    
    let query: any = { 
      role: 'patient', 
      isActive: true 
    }

    if (verified === 'true') {
      query.isEmailVerified = true
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

    const patients = await User.find(query)
      .select('phone email firstName lastName dateOfBirth gender isActive isEmailVerified createdAt')
      .limit(parseInt(limit as string))
      .sort({ createdAt: -1 })

    // Transform to match frontend expectations
    const transformedPatients = patients.map(patient => ({
      id: patient._id,
      firstName: patient.firstName || '',
      lastName: patient.lastName || '',
      fullName: `${patient.firstName || ''} ${patient.lastName || ''}`.trim() || 'Patient',
      phone: patient.phone,
      email: patient.email,
      dateOfBirth: patient.dateOfBirth,
      age: patient.dateOfBirth ? Math.floor((Date.now() - new Date(patient.dateOfBirth).getTime()) / 3.156e10) : undefined,
      gender: patient.gender,
      isVerified: patient.isEmailVerified || false,
      chronicConditions: [], // Could be added later
      allergies: [], // Could be added later
      lastVisit: patient.updatedAt
    }))

    res.json({
      success: true,
      data: { patients: transformedPatients }
    })
  } catch (error) {
    next(error)
  }
})

// Get patient by ID
router.get('/:id', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const patient = await User.findOne({
      _id: req.params.id,
      role: 'patient'
    }).select('phone email firstName lastName dateOfBirth gender isActive isEmailVerified createdAt updatedAt')

    if (!patient) {
      return res.status(404).json({
        success: false,
        message: 'Patient not found'
      })
    }

    const transformed = {
      id: patient._id,
      firstName: patient.firstName || '',
      lastName: patient.lastName || '',
      fullName: `${patient.firstName || ''} ${patient.lastName || ''}`.trim() || 'Patient',
      phone: patient.phone,
      email: patient.email,
      dateOfBirth: patient.dateOfBirth,
      age: patient.dateOfBirth ? Math.floor((Date.now() - new Date(patient.dateOfBirth).getTime()) / 3.156e10) : undefined,
      gender: patient.gender,
      isVerified: patient.isEmailVerified || false,
      chronicConditions: [],
      allergies: [],
      lastVisit: patient.updatedAt
    }

    res.json({
      success: true,
      data: transformed
    })
  } catch (error) {
    next(error)
  }
})

// Update patient status (admin only)
router.put('/:id/status', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (!['admin', 'superadmin', 'institution_admin'].includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      })
    }

    const { isActive } = req.body

    const patient = await User.findOneAndUpdate(
      {
        _id: req.params.id,
        role: 'patient'
      },
      { isActive, updatedAt: new Date() },
      { new: true }
    ).select('phone email firstName lastName isActive')

    if (!patient) {
      return res.status(404).json({
        success: false,
        message: 'Patient not found'
      })
    }

    res.json({
      success: true,
      message: `Patient ${isActive ? 'activated' : 'deactivated'} successfully`,
      data: patient
    })
  } catch (error) {
    next(error)
  }
})

export default router