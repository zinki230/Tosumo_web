import { Router } from 'express';
import { DoctorController } from './doctor.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new DoctorController();

router.post('/register', authenticate, controller.register);
router.get('/', authenticate, controller.getAll);
router.get('/profile', authenticate, controller.getProfile);
router.put('/profile', authenticate, controller.updateProfile);
router.put('/availability-status', authenticate, controller.setAvailabilityStatus);
router.get('/availability', authenticate, controller.getAvailability);
router.put('/availability', authenticate, controller.setAvailability);
router.get('/working-hours', authenticate, controller.getWorkingHours);
router.put('/working-hours', authenticate, controller.setWorkingHours);
router.get('/appointments', authenticate, controller.getAppointments);
router.get('/patients', authenticate, controller.getPatients);
router.get('/patients/search', authenticate, controller.searchPatients);
router.get('/patients/qr', authenticate, controller.lookupPatientByQr);
router.get('/dashboard', authenticate, controller.getDashboard);
router.get('/stats', authenticate, controller.getStats);
router.get('/reviews', authenticate, controller.getReviews);
router.get('/institutions', authenticate, controller.getInstitutions);
router.get('/:id', authenticate, controller.getById);

export default router;
