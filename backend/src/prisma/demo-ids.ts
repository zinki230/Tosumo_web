import { createHash } from 'crypto';

/**
 * Deterministic, stable 24-char hex ObjectId for a given seed.
 * Used so the demo seeder can upsert using fixed ids (idempotent).
 */
export function oid(seed: string): string {
  return createHash('md5')
    .update(seed)
    .digest('hex')
    .slice(0, 24);
}

export const IDS = {
  userPatient: oid('demo.patient.user'),
  patient: oid('demo.patient'),
  card: oid('demo.patient.card'),

  userP2: oid('demo.patient.p2.user'),
  patientP2: oid('demo.patient.p2'),
  cardP2: oid('demo.patient.p2.card'),
  userP3: oid('demo.patient.p3.user'),
  patientP3: oid('demo.patient.p3'),
  cardP3: oid('demo.patient.p3.card'),
  userP4: oid('demo.patient.p4.user'),
  patientP4: oid('demo.patient.p4'),
  cardP4: oid('demo.patient.p4.card'),
  userP5: oid('demo.patient.p5.user'),
  patientP5: oid('demo.patient.p5'),
  cardP5: oid('demo.patient.p5.card'),
  userP6: oid('demo.patient.p6.user'),
  patientP6: oid('demo.patient.p6'),
  cardP6: oid('demo.patient.p6.card'),

  gpUser: oid('demo.doctor.gp.user'),
  gp: oid('demo.doctor.gp'),
  cardioUser: oid('demo.doctor.cardio.user'),
  cardio: oid('demo.doctor.cardio'),
  pedsUser: oid('demo.doctor.peds.user'),
  peds: oid('demo.doctor.peds'),
  dermUser: oid('demo.doctor.derm.user'),
  derm: oid('demo.doctor.derm'),
  gynoUser: oid('demo.doctor.gyno.user'),
  gyno: oid('demo.doctor.gyno'),
  neuroUser: oid('demo.doctor.neuro.user'),
  neuro: oid('demo.doctor.neuro'),
  entUser: oid('demo.doctor.ent.user'),
  ent: oid('demo.doctor.ent'),
  ophtaUser: oid('demo.doctor.ophta.user'),
  ophta: oid('demo.doctor.ophta'),
  dentUser: oid('demo.doctor.dent.user'),
  dent: oid('demo.doctor.dent'),
  psychUser: oid('demo.doctor.psych.user'),
  psych: oid('demo.doctor.psych'),

  institutionYaounde: oid('demo.institution.yaounde'),
  institutionDouala: oid('demo.institution.douala'),
  institutionBafoussam: oid('demo.institution.bafoussam'),
  institutionLab: oid('demo.institution.lab'),

  appointmentUpcoming: oid('demo.appointment.upcoming'),
  appointmentPastCompleted: oid('demo.appointment.past.completed'),
  appointmentPastCancelled: oid('demo.appointment.past.cancelled'),
  appointmentPastRescheduled: oid('demo.appointment.past.rescheduled'),

  chatGp: oid('demo.chat.gp'),
  chatCardio: oid('demo.chat.cardio'),
  chatPeds: oid('demo.chat.peds'),
} as const;
