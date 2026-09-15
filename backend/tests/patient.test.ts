import request from 'supertest';
import app from '../src/app';

describe('Patient API', () => {
  let token: string;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'test@tosumo.cm', password: 'Test1234' });

    if (res.status === 200) {
      token = res.body.data.tokens.accessToken;
    }
  });

  it('should get patient profile', async () => {
    if (!token) return;
    const res = await request(app)
      .get('/api/v1/patients/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('should update patient profile', async () => {
    if (!token) return;
    const res = await request(app)
      .put('/api/v1/patients/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ bloodType: 'O+', allergies: ['Penicillin'] });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('should get medical card', async () => {
    if (!token) return;
    const res = await request(app)
      .get('/api/v1/patients/medical-card')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
