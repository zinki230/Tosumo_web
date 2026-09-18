import { CardsRepository } from './cards.repository';
import { NotFoundError, ForbiddenError } from '@shared/utils/errors';
import { generateCardNumber } from '@shared/utils/helpers';
import prisma from '@shared/database/prisma';

export class CardsService {
  private repository = new CardsRepository();

  async reissueCard(userId: string, patientId?: string) {
    let patient;
    if (patientId) {
      patient = await prisma.patient.findUnique({ where: { id: patientId } });
      if (!patient) throw new NotFoundError('Patient profile not found');
      if (patient.userId !== userId) throw new ForbiddenError('Cannot reissue another patient\'s card');
    } else {
      patient = await prisma.patient.findUnique({ where: { userId } });
    }
    if (!patient) throw new NotFoundError('Patient profile not found');

    const [existingCard] = await Promise.all([
      this.repository.findByPatientId(patient.id),
    ]);
    if (existingCard) {
      await this.repository.deactivate(existingCard.id);
    }

    const newCard = await this.repository.create(patient.id, generateCardNumber());

    await Promise.all([
      prisma.journeyEntry.create({
        data: {
          patientId: patient.id,
          title: 'Medical Card Reissued',
          description: 'A new medical card was issued',
          entryType: 'card_reissue',
          referenceId: newCard.id,
        },
      }),
      ...(patient.userId ? [prisma.notification.create({
        data: {
          userId: patient.userId,
          title: 'Card Reissued',
          body: 'Your medical card has been reissued successfully',
          type: 'medical',
        },
      })] : []),
    ]);

    return newCard;
  }
}
