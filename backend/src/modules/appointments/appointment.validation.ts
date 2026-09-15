import { z } from 'zod';

const timeRegex = /^([01]\d|2[0-3]):[0-5]\d$/;

export const bookAppointmentSchema = z.object({
  doctorId: z.string().min(1, 'Doctor is required'),
  appointmentDate: z.coerce.date({ errorMap: () => ({ message: 'Valid appointment date is required' }) }),
  startTime: z.string().regex(timeRegex, 'Start time must be in HH:mm format'),
  endTime: z.string().regex(timeRegex, 'End time must be in HH:mm format'),
  type: z.string().min(1, 'Appointment type is required'),
  reason: z.string().optional(),
  institutionId: z.string().optional(),
}).refine(d => d.startTime < d.endTime, {
  message: 'Start time must be before end time',
  path: ['endTime'],
}).refine(d => d.appointmentDate.getTime() > Date.now(), {
  message: 'Appointment date must be in the future',
  path: ['appointmentDate'],
});

export const cancelAppointmentSchema = z.object({
  reason: z.string().max(500).optional(),
});

export const rescheduleAppointmentSchema = z.object({
  appointmentDate: z.coerce.date({ errorMap: () => ({ message: 'Valid appointment date is required' }) }),
  startTime: z.string().regex(timeRegex, 'Start time must be in HH:mm format'),
  endTime: z.string().regex(timeRegex, 'End time must be in HH:mm format'),
  reason: z.string().max(500).optional(),
}).refine(d => d.startTime < d.endTime, {
  message: 'Start time must be before end time',
  path: ['endTime'],
}).refine(d => d.appointmentDate.getTime() > Date.now(), {
  message: 'Appointment date must be in the future',
  path: ['appointmentDate'],
});
