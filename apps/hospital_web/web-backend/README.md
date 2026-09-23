# TOSUMO Hospital Web Backend

Backend API dédié pour l'application web hospitalière TOSUMO, séparé du backend mobile pour une meilleure gestion et maintenance.

## 🚀 Fonctionnalités

- **Authentification JWT** - Login/register sécurisé
- **Gestion des institutions** - CRUD complet pour centres hospitaliers
- **Gestion des médecins** - Création et gestion par admin institution
- **Gestion des patients** - Consultation et statistiques
- **Dashboard complet** - Statistiques en temps réel
- **API RESTful** - Endpoints clairs et documentés
- **CORS configuré** - Support Vercel et domaines locaux
- **Base de données MongoDB** - Connexion Atlas partagée

## 🛠️ Technologies

- **Runtime**: Node.js 18+ avec TypeScript
- **Framework**: Express.js avec middleware de sécurité
- **Base de données**: MongoDB Atlas (partagée avec apps mobiles)
- **Authentification**: JWT avec bcrypt
- **Validation**: Zod schemas
- **Déploiement**: Docker + Railway

## ⚙️ Configuration

### Variables d'environnement

```bash
# Serveur
NODE_ENV=development
PORT=4000
HOST=0.0.0.0

# Base de données MongoDB Atlas
MONGODB_URI=mongodb+srv://russeltsague3_db_user:bPRLbVhxwQpfF7W1@cluster0.5id4izm.mongodb.net/tosumo

# JWT
JWT_ACCESS_SECRET=your-access-secret
JWT_REFRESH_SECRET=your-refresh-secret
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# CORS
CORS_ORIGINS=http://localhost:5173,https://tosumo-web-hospital-web.vercel.app

# Sécurité
BCRYPT_ROUNDS=12
API_RATE_LIMIT=100

# Mode démo
DEMO_MODE=true
DEMO_ADMIN_PHONE=+237691234570
DEMO_ADMIN_EMAIL=admin@hospital-web.tosumo.cm
DEMO_ADMIN_PASSWORD=WebAdmin@2024
```

## 🚀 Démarrage rapide

### 1. Installation

```bash
cd apps/hospital_web/web-backend
npm install
```

### 2. Configuration

```bash
cp .env.example .env
# Modifier les variables selon votre environnement
```

### 3. Développement

```bash
npm run dev
```

Le serveur démarre sur `http://localhost:4000`

### 4. Production

```bash
npm run build
npm start
```

## 📡 API Endpoints

### Authentification
- `POST /api/v1/auth/login` - Connexion
- `POST /api/v1/auth/register/institution` - Inscription institution
- `POST /api/v1/auth/register/doctor` - Inscription médecin
- `GET /api/v1/auth/profile` - Profil utilisateur
- `POST /api/v1/auth/refresh` - Renouveler token

### Institutions
- `GET /api/v1/institutions` - Liste institutions
- `GET /api/v1/institutions/my` - Mon institution
- `PUT /api/v1/institutions/my` - Modifier mon institution
- `POST /api/v1/institutions/doctors` - Créer médecin
- `GET /api/v1/institutions/doctors/list` - Liste médecins

### Médecins
- `GET /api/v1/doctors` - Liste médecins
- `GET /api/v1/doctors/:id` - Détail médecin
- `PUT /api/v1/doctors/:id/status` - Modifier statut

### Patients
- `GET /api/v1/patients` - Liste patients
- `GET /api/v1/patients/:id` - Détail patient

### Dashboard
- `GET /api/v1/dashboard/stats` - Statistiques globales
- `GET /api/v1/dashboard/overview` - Vue d'ensemble institution

## 🐳 Docker

### Build local
```bash
docker build -t tosumo-web-backend .
docker run -p 4000:4000 --env-file .env tosumo-web-backend
```

### Railway Deploy
Le fichier `railway.json` configure automatiquement le déploiement.

## 🔐 Authentification

### Rôles utilisateur
- `institution_admin` - Admin centre hospitalier
- `doctor` - Médecin
- `patient` - Patient
- `admin` - Admin système
- `superadmin` - Super admin

### Tokens JWT
- **Access Token**: 15 minutes (API calls)
- **Refresh Token**: 7 jours (renouvellement)

## 📊 Données de démonstration

En mode `DEMO_MODE=true`, le système crée automatiquement :

### Compte Admin Demo
- **Téléphone**: +237691234570
- **Email**: admin@hospital-web.tosumo.cm
- **Mot de passe**: WebAdmin@2024
- **Rôle**: institution_admin

### Institution Demo
- **Nom**: Centre Hospitalier TOSUMO Web
- **Type**: Hôpital
- **Ville**: Douala, Littoral

### Médecins Demo
- Dr. Jean Mballa (Cardiologie)
- Dr. Marie Nguemo (Pédiatrie)
- Dr. Paul Fouda (Chirurgie)

## 🔧 Développement

### Structure du projet
```
src/
├── middleware/     # Auth, CORS, erreurs
├── models/         # Schémas MongoDB
├── routes/         # Endpoints API
├── services/       # Logique métier
├── utils/          # Utilitaires
└── server.ts       # Point d'entrée
```

### Scripts disponibles
- `npm run dev` - Développement avec hot reload
- `npm run build` - Build TypeScript
- `npm start` - Démarrage production
- `npm run lint` - Vérification code

## 🚀 Déploiement Railway

1. **Créer nouveau service Railway**
2. **Connecter le repository GitHub**
3. **Définir le dossier racine**: `apps/hospital_web/web-backend`
4. **Configurer les variables d'environnement**
5. **Déployer**

### Variables Railway requises
```
NODE_ENV=production
PORT=4000
MONGODB_URI=<your-mongodb-connection>
JWT_ACCESS_SECRET=<generate-strong-secret>
JWT_REFRESH_SECRET=<generate-strong-secret>
CORS_ORIGINS=https://tosumo-web-hospital-web.vercel.app
```

## 🔍 Monitoring

### Health Check
- **URL**: `/health`
- **Response**: Status server + timestamp

### Logs
- Connexions MongoDB
- Erreurs d'authentification
- Requêtes API (mode dev)

## 📝 License

MIT - TOSUMO Team