import prisma from '@shared/database/prisma';
async function main() {
  const appts = await prisma.appointment.findMany({ include: { patient: { include: { user: true } } }, orderBy: { appointmentDate: 'desc' } });
  for (const a of appts) {
    console.log('APPT', JSON.stringify({ id: a.id, date: a.appointmentDate, start: a.startTime, status: a.status, doctorId: a.doctorId, patient: a.patient?.firstName + ' ' + a.patient?.lastName, updatedAt: a.updatedAt }));
  }
}
main().finally(() => prisma.$disconnect());
