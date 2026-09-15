import { Router } from 'express';
import { MedicalRecordsController } from './medical-records.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new MedicalRecordsController();

// Access-controlled aggregate view of a patient's records (doctor-only)
router.get('/patient/:patientId', authenticate, controller.getPatientRecords);

// Consultations
router.get('/consultations', authenticate, controller.getConsultations);
router.post('/consultations', authenticate, controller.createConsultation);
router.get('/consultations/:id', authenticate, controller.getConsultationById);
router.put('/consultations/:id', authenticate, controller.updateConsultation);
router.delete('/consultations/:id', authenticate, controller.deleteConsultation);

// Lab Results
router.get('/lab-results', authenticate, controller.getLabResults);
router.post('/lab-results', authenticate, controller.createLabResult);
router.get('/lab-results/:id', authenticate, controller.getLabResultById);
router.put('/lab-results/:id', authenticate, controller.updateLabResult);

// Imaging Results
router.get('/imaging-results', authenticate, controller.getImagingResults);
router.post('/imaging-results', authenticate, controller.createImagingResult);
router.get('/imaging-results/:id', authenticate, controller.getImagingResultById);
router.put('/imaging-results/:id', authenticate, controller.updateImagingResult);

// Prescriptions
router.get('/prescriptions', authenticate, controller.getPrescriptions);
router.post('/prescriptions', authenticate, controller.createPrescription);
router.get('/prescriptions/:id', authenticate, controller.getPrescriptionById);
router.put('/prescriptions/:id', authenticate, controller.updatePrescription);
router.put('/prescriptions/:id/fulfill', authenticate, controller.fulfillPrescription);
router.put('/prescriptions/:id/complete', authenticate, controller.completePrescription);

export default router;
