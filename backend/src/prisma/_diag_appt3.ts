import prisma from '@shared/database/prisma';
async function main() {
  const appt = await prisma.appointment.findUnique({ where: { id: '6a7f35510937222230588795' } });
  console.log('FOUND BY ID', JSON.stringify(appt));
  const all = await prisma.appointment.findMany({ where: { doctorId: '673cc0829b20efded5bff828' } });
  console.log('DEMO DOCTOR APPTS', all.length);
  for (const a of all) console.log(JSON.stringify({ id: a.id, status: a.status, date: a.appointmentDate }));
}
main().finally(() => prisma.$disconnect());
