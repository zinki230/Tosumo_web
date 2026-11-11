import { z } from 'zod';
import { normalizeCameroonPhone } from '@shared/utils/phone';

const phoneField = z.string().trim().transform((value) => value.replace(/[\s-]/g, ''))
  .pipe(z.string().min(9).max(15))
  .refine((value) => normalizeCameroonPhone(value) !== '', 'Numéro camerounais invalide');

export const createSystemAdminSchema = z.object({
  phone: phoneField,
  email: z.string().trim().email('Adresse email invalide').max(254),
  password: z.string().min(12, 'Le mot de passe doit contenir au moins 12 caractères')
    .regex(/[A-Z]/, 'Ajoutez une majuscule')
    .regex(/[a-z]/, 'Ajoutez une minuscule')
    .regex(/[0-9]/, 'Ajoutez un chiffre'),
  currentPassword: z.string().min(1, 'Confirmez le mot de passe du compte actuel'),
});
