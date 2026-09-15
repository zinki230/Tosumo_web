import prisma from '@shared/database/prisma';
async function main() {
  const doctor = await prisma.doctor.findFirst({ where: { user: { phone: '+237691000101' } }, include: { user: true } });
  console.log('DOCTOR', doctor?.id, doctor?.userId, doctor?.firstName, doctor?.lastName);
  if (!doctor) return;
  const appts = await prisma.appointment.findMany({
    where: { doctorId: doctor.id },
    include: { patient: { include: { user: true } } },
    orderBy: { appointmentDate: 'desc' },
  });
  console.log('APPT COUNT', appts.length);
  for (const a of appts) {
    console.log('APPT', JSON.stringify({ id: a.id, date: a.appointmentDate, start: a.startTime, status: a.status, patient: a.patient?.firstName + ' ' + a.patient?.lastName, hasDeletedAt: 'deletedAt' in a, deletedAt: a.deletedAt }));
  }
}
main().finally(() => prisma.$disconnect());
