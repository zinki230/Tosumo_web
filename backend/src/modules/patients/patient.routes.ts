import { Router } from 'express';
import { PatientController } from './patient.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new PatientController();

router.get('/profile', authenticate, controller.getProfile);
router.put('/profile', authenticate, controller.updateProfile);
router.post('/onboard', authenticate, controller.onboard);
router.get('/medical-card', authenticate, controller.getMedicalCard);
router.get('/emergency-contacts', authenticate, controller.getEmergencyContacts);
router.post('/emergency-contacts', authenticate, controller.addEmergencyContact);
router.put('/emergency-contacts/:contactId', authenticate, controller.updateEmergencyContact);
router.delete('/emergency-contacts/:contactId', authenticate, controller.deleteEmergencyContact);
router.get('/medical-booklets', authenticate, controller.getMedicalBooklets);
router.post('/medical-booklets', authenticate, controller.addMedicalBooklet);
router.delete('/medical-booklets/:bookletId', authenticate, controller.deleteMedicalBooklet);
router.get('/journey', authenticate, controller.getJourney);
router.get('/appointments', authenticate, controller.getAppointments);
router.get('/medical-records', authenticate, controller.getMedicalRecords);
router.get('/:id', authenticate, controller.getPatientByIdOrUserId);
router.put('/:id', authenticate, controller.updateByDoctor);
router.post('/', authenticate, controller.createPatient);

export default router;
