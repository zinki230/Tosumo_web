import request from 'supertest';
import app from '../src/app';

describe('Auth API', () => {
  const testUser = {
    email: 'test@tosumo.cm',
    phone: '237600000001',
    password: 'Test1234',
    role: 'patient' as const,
  };

  let accessToken: string;
  let refreshToken: string;

  it('should register a new user', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send(testUser);

    if (res.status === 409) {
      // User already exists from previous run - try to login instead
      const loginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: testUser.email, password: testUser.password });

      expect(loginRes.status).toBe(200);
      expect(loginRes.body.success).toBe(true);
      accessToken = loginRes.body.data.tokens.accessToken;
      refreshToken = loginRes.body.data.tokens.refreshToken;
      return;
    }

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.email).toBe(testUser.email);
    expect(res.body.data.tokens.accessToken).toBeDefined();
    expect(res.body.data.tokens.refreshToken).toBeDefined();

    accessToken = res.body.data.tokens.accessToken;
    refreshToken = res.body.data.tokens.refreshToken;
  });

  it('should login', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: testUser.email, password: testUser.password });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.tokens.accessToken).toBeDefined();

    accessToken = res.body.data.tokens.accessToken;
    refreshToken = res.body.data.tokens.refreshToken;
  });

  it('should get profile', async () => {
    const res = await request(app)
      .get('/api/v1/auth/profile')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.email).toBe(testUser.email);
  });

  it('should reject invalid credentials', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: testUser.email, password: 'WrongPass1' });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  it('should refresh token', async () => {
    const res = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.accessToken).toBeDefined();
  });

  it('should send an OTP for passwordless login', async () => {
    const res = await request(app)
      .post('/api/v1/auth/send-otp')
      .send({ phone: testUser.phone });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.mode).toBeDefined();
    expect(res.body.data.demoCode).toBeUndefined();
  });

  it('should login with a valid OTP', async () => {
    // Demo mode accepts any well-formed 6-digit code.
    const res = await request(app)
      .post('/api/v1/auth/otp-login')
      .send({ phone: testUser.phone, code: '123456' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.phone).toBeDefined();
    expect(res.body.data.tokens.accessToken).toBeDefined();
    expect(res.body.data.tokens.refreshToken).toBeDefined();
  });

  it('should reject OTP login for an unregistered phone', async () => {
    const res = await request(app)
      .post('/api/v1/auth/otp-login')
      .send({ phone: '237699999999', code: '123456' });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  it('should reject an invalid OTP for passwordless login', async () => {
    // 4 digits pass schema validation but are rejected by the provider
    // (demo mode requires exactly 6 digits).
    const res = await request(app)
      .post('/api/v1/auth/otp-login')
      .send({ phone: testUser.phone, code: '9999' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  it('should report an existing phone via check-phone', async () => {
    const res = await request(app)
      .post('/api/v1/auth/check-phone')
      .send({ phone: testUser.phone });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.exists).toBe(true);
    expect(res.body.data.phone).toBe('+237600000001');
  });

  it('should report an unknown phone via check-phone', async () => {
    const res = await request(app)
      .post('/api/v1/auth/check-phone')
      .send({ phone: '237677777777' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.exists).toBe(false);
    expect(res.body.data.phone).toBe('+237677777777');
  });

  it('should reject a duplicate phone with a typed error', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'duplicate-check@tosumo.cm',
        phone: '+237600000001',
        password: 'Test1234',
        role: 'patient',
      });

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
    expect(res.body.code).toBe('PHONE_ALREADY_REGISTERED');
    expect(res.body.error).toBe('Phone number already registered');
  });

  it('should reject the same number in local format', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'duplicate-check-2@tosumo.cm',
        phone: '600000001',
        password: 'Test1234',
        role: 'patient',
      });

    expect(res.status).toBe(409);
    expect(res.body.code).toBe('PHONE_ALREADY_REGISTERED');
  });

  it('should logout', async () => {
    const res = await request(app)
      .post('/api/v1/auth/logout')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('should reject request without token', async () => {
    const res = await request(app).get('/api/v1/auth/profile');
    expect(res.status).toBe(401);
  });

  it('should return 400 with field errors for an invalid phone on check-phone', async () => {
    const res = await request(app)
      .post('/api/v1/auth/check-phone')
      .send({ phone: '123' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.errors?.phone).toBeDefined();
  });

  it('should return 400 when phone is omitted on check-phone', async () => {
    const res = await request(app).post('/api/v1/auth/check-phone').send({});

    expect(res.status).toBe(400);
    expect(res.body.errors?.phone).toBeDefined();
  });
});
