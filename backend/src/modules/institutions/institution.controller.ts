import { Response, NextFunction } from 'express';
import { InstitutionService } from './institution.service';
import { AuthenticatedRequest } from '@shared/types';

const institutionService = new InstitutionService();

export class InstitutionController {
  async getAll(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const filters = req.query as { type?: string; city?: string; region?: string };
      const institutions = await institutionService.getAll(filters);
      res.json({ success: true, data: institutions });
    } catch (error) { next(error); }
  }

  async getById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const institution = await institutionService.getById(req.params.id as string);
      res.json({ success: true, data: institution });
    } catch (error) { next(error); }
  }

  async create(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const institution = await institutionService.create(req.body);
      res.status(201).json({ success: true, data: institution });
    } catch (error) { next(error); }
  }
}
