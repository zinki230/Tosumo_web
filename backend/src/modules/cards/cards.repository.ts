import prisma from '@shared/database/prisma';

export class CardsRepository {
  async findByPatientId(patientId: string) {
    return prisma.medicalCard.findUnique({ where: { patientId } });
  }

  async deactivate(cardId: string) {
    return prisma.medicalCard.update({
      where: { id: cardId },
      data: { isActive: false },
    });
  }

  async create(patientId: string, cardNumber: string) {
    return prisma.medicalCard.create({
      data: { patientId, cardNumber },
    });
  }
}
