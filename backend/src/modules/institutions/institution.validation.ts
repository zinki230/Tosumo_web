import { z } from 'zod';

export const createDoctorSchema = z.object({
  firstName: z.string().min(2, 'First name must be at least 2 characters'),
  lastName: z.string().min(2, 'Last name must be at least 2 characters'),
  phone: z.string().min(9, 'Phone number is required'),
  specialty: z.string().min(2, 'Specialty is required'),
  licenseNumber: z.string().min(3, 'License number is required'),
  email: z.string().email().optional().or(z.literal('')),
});
