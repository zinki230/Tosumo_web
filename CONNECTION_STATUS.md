# ✅ État de connexion — MongoDB Atlas TOSUMO

**Date de vérification :** 15 Septembre 2026  
**Cluster :** `cluster0.5id4izm.mongodb.net`  
**Base :** `tosumo`

---

## 📊 Données en base (vérifié)

| Collection    | Nombre |
|---------------|--------|
| Users         | 69     |
| Patients      | 34     |
| Doctors       | 27     |
| Appointments  | 10     |
| Institutions  | 6      |

---

## 🔗 Architecture de connexion

```
Apps Flutter (Patient & Doctor)
        │
        │  HTTPS
        ▼
  Backend Node.js (Railway)
  https://tosumo-production.up.railway.app
        │
        │  mongodb+srv://
        ▼
  MongoDB Atlas
  cluster0.5id4izm.mongodb.net/tosumo
```

### Pourquoi les apps Flutter ne se connectent PAS directement à MongoDB

Les apps Flutter ne lisent **jamais** la `DATABASE_URL`. Elles parlent uniquement
au **backend REST** via HTTPS. C'est le backend qui accède à MongoDB Atlas.

---

## ✅ Vérifications effectuées

### Backend local (`localhost:3000`)
- [x] `GET /health` → `{"status":"ok","service":"tosumo-backend"}`
- [x] `POST /api/v1/auth/login` → JWT token retourné
- [x] `GET /api/v1/doctors` → 25+ médecins retournés
- [x] `GET /api/v1/patients` → 34 patients retournés
- [x] `GET /api/v1/appointments` → rendez-vous retournés
- [x] Connexion Prisma → Atlas confirmée

### Apps Flutter
- [x] Patient app → pointe vers `https://tosumo-production.up.railway.app`
- [x] Doctor app → pointe vers `https://tosumo-production.up.railway.app`
- [x] En debug Android → utilise Railway (pas localhost)
- [x] Override possible : `--dart-define=API_BASE_URL=http://10.0.2.2:3000`

### App Web (`localhost:5173`)
- [x] Proxy Vite → `/api/*` redirigé vers `http://localhost:3000`
- [x] Login fonctionne avec compte demo

---

## 🔧 Configuration locale (backend)

**Fichier :** `backend/.env` (non versionné — contient credentials)

```env
DATABASE_URL=mongodb+srv://russeltsague3_db_user:***@cluster0.5id4izm.mongodb.net/tosumo?appName=Cluster0
NODE_ENV=development
PORT=3000
```

---

## 🚀 Démarrage

### Backend local
```bash
cd backend
npm install       # si pas encore fait
npm run build     # compiler TypeScript → dist/
node dist/server.js
# OU en mode watch :
npm run dev
```

### App Web
```bash
cd apps/hospital_web
npm install
npm run dev
# Ouvrir http://localhost:5173
```

### Comptes de test
| Rôle    | Téléphone        | Mot de passe |
|---------|------------------|--------------|
| Médecin | +237691000101    | Demo@1234    |
| Patient | +237691234567    | Demo@1234    |

---

## ⚠️ Déploiement Railway

Pour que le backend **déployé** utilise Atlas, définir dans les variables
d'environnement Railway :

```
DATABASE_URL = mongodb+srv://russeltsague3_db_user:<password>@cluster0.5id4izm.mongodb.net/tosumo?appName=Cluster0
```

Via : Railway Dashboard → Project → Variables → Add Variable
