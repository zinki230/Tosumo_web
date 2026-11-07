# TOSUMO Backend

Healthcare platform backend supporting patient and doctor mobile applications.

## Tech Stack

- **Runtime:** Node.js 22
- **Framework:** Express.js 4
- **Language:** TypeScript
- **Database:** PostgreSQL (via Prisma ORM; Neon provisioned through Vercel Marketplace)
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

# Start PostgreSQL locally (or configure DATABASE_URL for Neon)
docker compose up -d postgres

# Apply versioned PostgreSQL migrations
npm run prisma:migrate

# Start development server
npm run dev
```

## API Documentation

Once running, visit `http://localhost:3000/api/v1/docs` for Swagger UI.

## Environment Variables

Copy `.env.example` to `.env` and configure:

| Variable | Description |
|----------|-------------|
| DATABASE_URL | PostgreSQL connection string (Neon pooled URL on Vercel) |
| DIRECT_URL | Direct PostgreSQL URL required by Prisma schema/migration commands (local setup may reuse `DATABASE_URL`) |
| REDIS_URL | Redis connection string |
| JWT_ACCESS_SECRET | JWT access token signing key |
| JWT_REFRESH_SECRET | JWT refresh token signing key |
| SMTP_* | Email configuration |
| ORANGE_SMS_CLIENT_ID / ORANGE_SMS_CLIENT_SECRET | Orange Developer OAuth credentials |
| ORANGE_SMS_SENDER_ADDRESS | Orange authorized SMS sender, e.g. `tel:+2370000` |
| OTP_HASH_SECRET | Server-only HMAC key (at least 32 characters) |

## Testing

```bash
npm test
```

## Docker

```bash
# Full stack (API + PostgreSQL)
docker compose up --build

# Individual services
docker compose up -d postgres
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
# Base PostgreSQL sur Neon/Vercel

Le backend utilise PostgreSQL avec Prisma. Le schéma et les migrations versionnées
sont dans `src/prisma/schema.prisma` et `src/prisma/migrations`. Dans Vercel, reliez
une base Neon depuis **Storage → Marketplace** pour provisionner les variables
d'environnement du projet. Utilisez la chaîne PostgreSQL poolée fournie par
Neon dans `DATABASE_URL` et la chaîne directe dans `DIRECT_URL` pour les
commandes Prisma (la même URL convient si vous n'avez pas de connexion directe
distincte). Le backend existant peut être hébergé ailleurs et se connecter à
Neon via `DATABASE_URL`.

Après avoir créé ou lié la base, appliquez les migrations avec `npm run
prisma:migrate`. `npm run prisma:generate` génère le client Prisma. N'utilisez
`prisma db push` que pour du développement local sans migrations versionnées.

## Transfert initial depuis MongoDB

Le transfert conserve les identifiants Mongo existants sous forme de chaînes
hexadécimales, ce qui préserve les références entre documents. Il copie les
collections en respectant les relations PostgreSQL et ignore les IDs déjà
présents pour permettre de reprendre après une interruption.

1. Créez une sauvegarde MongoDB et une base PostgreSQL Neon vide.
2. Configurez `MONGODB_SOURCE_URL` (source) et `DATABASE_URL` (destination) dans
   l'environnement local du backend. Ces deux valeurs donnent accès aux données
   médicales : ne les mettez pas dans Git ou dans le code Flutter.
3. Appliquez les migrations sur PostgreSQL : `npm run prisma:migrate`.
4. Lancez `npm run migrate:mongodb-to-postgres` et contrôlez les nombres de
   lignes, les utilisateurs, les dossiers médicaux et les rendez-vous avant de
   changer `DATABASE_URL` en production.
5. Gardez la source en lecture seule jusqu'à la validation fonctionnelle et la
   sauvegarde PostgreSQL. Ensuite, retirez `MONGODB_SOURCE_URL` des variables.

Le script ne supprime ni ne modifie les données MongoDB. Il faut vérifier les
erreurs de documents orphelins ou de doublons avant la bascule; PostgreSQL
applique des clés étrangères et des contraintes uniques que MongoDB n'imposait
pas nécessairement.

# Téléphone OTP avec Orange Cameroun

La vérification téléphone utilise les routes d'authentification existantes :

- `POST /api/v1/auth/send-otp` — `{ "phone": "+2376XXXXXXXX" }`
- `POST /api/v1/auth/resend-otp` — même payload, soumis au délai de 60 secondes
- `POST /api/v1/auth/verify-otp` — `{ "phone": "+2376XXXXXXXX", "code": "012345" }`

Le code est à 6 chiffres, valable 5 minutes, avec 5 tentatives maximum. Chaque
renvoi remplace l'ancien code. Le code n'est jamais stocké en clair : MongoDB
contient son HMAC-SHA256, calculé avec `OTP_HASH_SECRET`. Les identifiants Orange
et le secret HMAC restent uniquement dans l'environnement backend.

## Configuration Orange

1. Copiez `.env.example` en `.env` et gardez `.env` hors du dépôt.
2. Dans le portail [Orange Developer](https://developer.orange.com/apis/sms-cm/), créez une application, abonnez-la à SMS Cameroon 2.0 et achetez un bundle.
3. Renseignez `ORANGE_SMS_CLIENT_ID` et `ORANGE_SMS_CLIENT_SECRET` depuis MyApps.
4. Renseignez `ORANGE_SMS_SENDER_ADDRESS` avec l'expéditeur autorisé par Orange. La documentation donne `tel:+2370000` comme expéditeur pays Cameroun.
5. Définissez `OTP_HASH_SECRET` avec une valeur aléatoire d'au moins 32 caractères (`openssl rand -hex 32`). Ne la faites pas tourner pendant que des codes sont actifs.
6. Générez le client Prisma après mise à jour du schéma : `npm run prisma:generate`. Appliquez le schéma MongoDB : `npm run prisma:push`.

Le backend ne simule pas l'envoi et ne valide pas de code arbitraire si Orange
n'est pas configuré. L'API répond en erreur tant que l'envoi réel n'est pas
accepté. Les réponses d'erreur Orange sont journalisées sans contenu qui
pourrait exposer le numéro destinataire ou le code OTP.

Orange annonce l'arrêt de SMS Cameroon 2.0 le 1er décembre 2026. Vérifiez auprès
d'Orange la disponibilité du service et la migration vers Ngage avant cette
date. L'acceptation HTTP 201 confirme la prise en charge du SMS par Orange ; la
livraison au téléphone dépend ensuite du réseau destinataire.
