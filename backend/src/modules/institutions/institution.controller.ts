import { Response, NextFunction } from 'express';
import { InstitutionService } from './institution.service';
import { AuthenticatedRequest } from '@shared/types';
import prisma from '@shared/database/prisma';

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

  async createDoctor(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const result = await institutionService.createDoctor(req.user!.userId, req.body);
      res.status(201).json({ 
        success: true, 
        data: result.doctor,
        credentials: result.credentials,
        message: 'Doctor account created successfully. Please save the temporary password and share it with the doctor.'
      });
    } catch (error) { next(error); }
  }

  async getDoctors(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      // Get institution ID from the authenticated user
      const user = await prisma.user.findUnique({
        where: { id: req.user!.userId },
        include: { createdInstitutions: true }
      });

      if (!user || !user.createdInstitutions || user.createdInstitutions.length === 0) {
        return res.json({ success: true, data: [] });
      }

      const institutionId = user.createdInstitutions[0].id;
      const doctors = await institutionService.getDoctorsByInstitution(institutionId);
      res.json({ success: true, data: doctors });
    } catch (error) { next(error); }
  }
}
