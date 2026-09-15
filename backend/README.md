# TOSUMO Backend

Healthcare platform backend supporting patient and doctor mobile applications.

## Tech Stack

- **Runtime:** Node.js 22
- **Framework:** Express.js 4
- **Language:** TypeScript
- **Database:** MongoDB 7 (via Prisma ORM)
- **Cache:** Redis 7
- **Auth:** JWT (access + refresh tokens)
- **Real-time:** Socket.IO
- **Validation:** Zod

## Architecture

Clean Architecture layers:
- **Controller** - HTTP request handling
- **Service** - Business logic
- **Repository** - Database access (Prisma)

## Modules

- `auth` - Registration, login, token refresh, password management
- `patients` - Profile, medical card, emergency contacts, booklets, journey
- `doctors` - Profile, availability, working hours, verification, dashboard
- `appointments` - Book, approve, confirm, cancel, reschedule, complete
- `medical-records` - Consultations, lab results, imaging, prescriptions
- `chat` - Real-time messaging via Socket.IO + REST fallback
- `notifications` - Push and in-app notifications
- `access` - Patient grant/revoke doctor access with expiration
- `emergency` - SOS alerts, critical info sharing, nearby hospitals
- `institutions` - Hospital/clinic registry
- `payments` - Mock providers (Orange Money, MTN, cards)
- `upload` - File upload handling
- `sync` - Offline-first sync with versioned entities
- `audit` - Full action audit trail
- `admin` - User management, doctor verification, dashboard

## Quick Start

```bash
# Install dependencies
npm install

# Generate Prisma client
npm run prisma:generate

# Start MongoDB and Redis
docker compose up -d mongodb redis

# Push schema to MongoDB
npm run prisma:push

# Start development server
npm run dev
```

## API Documentation

Once running, visit `http://localhost:3000/api/v1/docs` for Swagger UI.

## Environment Variables

Copy `.env.example` to `.env` and configure:

| Variable | Description |
|----------|-------------|
| DATABASE_URL | MongoDB connection string |
| REDIS_URL | Redis connection string |
| JWT_ACCESS_SECRET | JWT access token signing key |
| JWT_REFRESH_SECRET | JWT refresh token signing key |
| SMTP_* | Email configuration |
| SMS_* | Africa's Talking SMS configuration |

## Testing

```bash
npm test
```

## Docker

```bash
# Full stack
docker compose up --build

# Individual services
docker compose up -d mongodb redis
```

## API Endpoints

All endpoints prefixed with `/api/v1`.

### Health
- `GET /health` - Health check

### Auth
- `POST /auth/register` - Register user
- `POST /auth/login` - Login
- `POST /auth/refresh` - Refresh tokens
- `POST /auth/logout` - Logout
- `GET /auth/profile` - Get profile
- `PUT /auth/change-password` - Change password
- `PUT /auth/fcm-token` - Update FCM token

### Patients
- `GET /patients/profile`
- `PUT /patients/profile`
- `POST /patients/onboard`
- `GET /patients/medical-card`
- `GET/POST /patients/emergency-contacts`
- `PUT/DELETE /patients/emergency-contacts/:id`
- `GET/POST /patients/medical-booklets`
- `DELETE /patients/medical-booklets/:id`
- `GET /patients/journey`
- `GET /patients/appointments`
- `GET /patients/medical-records`

### Doctors
- `POST /doctors/register`
- `GET/PUT /doctors/profile`
- `PUT /doctors/availability-status`
- `GET/PUT /doctors/availability`
- `GET/PUT /doctors/working-hours`
- `GET /doctors/appointments`
- `GET /doctors/patients`
- `GET /doctors/dashboard`
- `GET /doctors/stats`
- `GET /doctors/reviews`
- `GET /doctors/institutions`

### Appointments
- `POST /appointments`
- `GET /appointments/upcoming`
- `GET /appointments/:id`
- `PUT /appointments/:id/approve`
- `PUT /appointments/:id/confirm`
- `PUT /appointments/:id/cancel`
- `PUT /appointments/:id/reschedule`
- `PUT /appointments/:id/complete`
- `PUT /appointments/:id/no-show`

### Medical Records
- `GET/POST /medical-records/consultations`
- `GET/POST /medical-records/lab-results`
- `GET/POST /medical-records/imaging-results`
- `GET/POST /medical-records/prescriptions`

### Chat
- `GET /chat`
- `GET /chat/unread`
- `POST /chat/with/:doctorId`
- `GET /chat/:chatId/messages`
- `POST /chat/:chatId/messages`
- `PUT /chat/:chatId/read`

### Notifications
- `GET /notifications`
- `GET /notifications/unread`
- `GET /notifications/unread/count`
- `PUT /notifications/:id/read`
- `PUT /notifications/read-all`
- `DELETE /notifications/:id`

### Access Management
- `POST /access/grant`
- `PUT /access/:id/revoke`
- `GET /access/patient`
- `GET /access/doctor`
- `GET /access/check/:patientUserId`

### Emergency
- `POST /emergency/sos`
- `GET /emergency/critical-info`
- `GET /emergency/nearby-hospitals`

### Institutions
- `GET /institutions`
- `POST /institutions`
- `GET /institutions/:id`

### Payments
- `POST /payments/initiate`
- `GET /payments`
- `GET /payments/:id`
- `POST /payments/:id/refund`

### Upload
- `POST /upload` (single file)
- `POST /upload/multiple` (multiple files)

### Sync
- `POST /sync` (offline data synchronization)

### Audit
- `GET /audit-logs`

### Admin
- `GET /admin/users`
- `PUT /admin/users/:id/toggle-status`
- `PUT /admin/doctors/:id/verify`
- `GET /admin/doctors`
- `GET /admin/appointments`
- `GET /admin/audit-logs`
- `GET /admin/dashboard`
