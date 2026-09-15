import { InstitutionRepository } from './institution.repository';
import { NotFoundError } from '@shared/utils/errors';

export class InstitutionService {
  private repository = new InstitutionRepository();

  async getAll(filters?: { type?: string; city?: string; region?: string }) {
    return this.repository.findAll(filters);
  }

  async getById(id: string) {
    const institution = await this.repository.findById(id);
    if (!institution) throw new NotFoundError('Institution not found');
    return institution;
  }

  async create(data: {
    name: string;
    type: string;
    phone?: string;
    email?: string;
    address?: string;
    city?: string;
    region?: string;
    latitude?: number;
    longitude?: number;
  }) {
    return this.repository.create(data);
  }
}
