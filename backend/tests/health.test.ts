import request from 'supertest';
import app from '../src/app';

describe('Health Check', () => {
  it('should return 200 on health endpoint', async () => {
    const res = await request(app).get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toBe('TOSUMO API is running');
  });

  it('should return 404 for unknown routes', async () => {
    const res = await request(app).get('/api/v1/unknown');
    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
  });
});
