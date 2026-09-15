import { Response, NextFunction } from 'express';
import { CardsService } from './cards.service';
import { AuthenticatedRequest } from '@shared/types';

const cardsService = new CardsService();

export class CardsController {
  async reissue(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const card = await cardsService.reissueCard(req.user!.userId, req.body.patientId);
      res.json({ success: true, data: card });
    } catch (error) { next(error); }
  }
}
