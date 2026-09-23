import { Router, Request, Response, NextFunction } from 'express'
import { User } from '../models/User'
import { Institution } from '../models/Institution'
import { authMiddleware, AuthenticatedRequest } from '../middleware/auth'

const router = Router()

// Get dashboard statistics
router.get('/stats', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (!['admin', 'superadmin', 'institution_admin'].includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      })
    }

    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const tomorrow = new Date(today)
    tomorrow.setDate(tomorrow.getDate() + 1)

    let doctorQuery: any = { role: 'doctor', isActive: true }
    let patientQuery: any = { role: 'patient', isActive: true }
    let institutionQuery: any = { isVerified: true }

    // Filter by institution for institution_admin
    if (req.user.role === 'institution_admin') {
      doctorQuery.createdBy = req.user.userId
      // For patients, we'll count all patients since they're not institution-specific in this simple model
    }

    const [
      totalDoctors,
      totalPatients,
      totalInstitutions,
      verifiedPatients
    ] = await Promise.all([
      User.countDocuments(doctorQuery),
      User.countDocuments(patientQuery),
      req.user.role === 'institution_admin' ? 1 : Institution.countDocuments(institutionQuery),
      User.countDocuments({ ...patientQuery, isEmailVerified: true })
    ])

    // Mock data for appointments since we don't have appointment model yet
    const stats = {
      totalDoctors,
      totalPatients,
      totalInstitutions,
      totalAppointments: 0, // Will be implemented with appointment model
      todayAppointments: 0, // Will be implemented with appointment model
      verifiedPatients,
      activeRelationships: 0, // Will be calculated from appointments
      pendingVerifications: 0 // For doctors pending verification
    }

    res.json({
      success: true,
      data: stats
    })
  } catch (error) {
    next(error)
  }
})

// Get dashboard overview for institution admin
router.get('/overview', authMiddleware, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (req.user.role !== 'institution_admin') {
      return res.status(403).json({
        success: false,
        message: 'Access denied'
      })
    }

    // Get institution info
    const institution = await Institution.findById(req.user.institutionId)
      .select('name type city region createdAt')

    // Get recent doctors
    const recentDoctors = await User.find({
      role: 'doctor',
      createdBy: req.user.userId,
      isActive: true
    })
    .select('phone email firstName lastName specialty createdAt')
    .sort({ createdAt: -1 })
    .limit(5)

    // Get counts
    const doctorCount = await User.countDocuments({
      role: 'doctor',
      createdBy: req.user.userId,
      isActive: true
    })

    res.json({
      success: true,
      data: {
        institution,
        recentDoctors,
        counts: {
          doctors: doctorCount,
          patients: 0, // Will implement when we add patient relationships
          appointments: 0 // Will implement with appointment model
        }
      }
    })
  } catch (error) {
    next(error)
  }
})

export default router