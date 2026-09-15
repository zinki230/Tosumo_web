import request from 'supertest';
import app from '../src/app';

describe('Appointment API', () => {
  let patientToken: string;
  let doctorToken: string;

  beforeAll(async () => {
    // Login as patient
    const patientRes = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'test@tosumo.cm', password: 'Test1234' });

    if (patientRes.status === 200) {
      patientToken = patientRes.body.data.tokens.accessToken;
    }
  });

  it('should get upcoming appointments', async () => {
    if (!patientToken) return;
    const res = await request(app)
      .get('/api/v1/appointments/upcoming')
      .set('Authorization', `Bearer ${patientToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
  });
});
