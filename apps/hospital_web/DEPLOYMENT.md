# 🚀 Guide de Déploiement - TOSUMO Hospital Web

## Architecture de Déploiement

```
Frontend (Vercel)           Backend (Railway)           Database (MongoDB Atlas)
─────────────────          ────────────────────        ─────────────────────────
tosumo-hospital-web  →     tosumo-web-backend    →    cluster0.5id4izm.mongodb.net
vercel.app                 -production                  
                           .up.railway.app              
```

---

## 📦 Backend - Railway

### URL de Production
```
https://tosumo-web-backend-production.up.railway.app
```

### Repository
```
https://github.com/zinki230/tosumo-web-backend
```

### Variables d'Environnement Requises

```env
NODE_ENV=production
PORT=4000
MONGODB_URI=mongodb+srv://russeltsague3_db_user:bPRLbVhxwQpfF7W1@cluster0.5id4izm.mongodb.net/tosumo
JWT_SECRET=votre-secret-jwt-securise
JWT_ACCESS_SECRET=votre-access-secret-jwt
JWT_REFRESH_SECRET=votre-refresh-secret-jwt
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
BCRYPT_ROUNDS=12
CORS_ORIGINS=https://tosumo-web-hospital-web.vercel.app,https://tosumo-hospital-web.vercel.app
```

### Endpoints API

- **Health Check**: `GET /health`
- **Auth**: `POST /api/v1/auth/login`
- **Dashboard**: `GET /api/v1/dashboard/stats`
- Voir `web-backend/README.md` pour la liste complète

### Déploiement Backend

1. Pusher les changements sur GitHub :
   ```bash
   cd apps/hospital_web/web-backend
   git add .
   git commit -m "Update backend"
   git push
   ```

2. Railway redéploie automatiquement

---

## 🌐 Frontend - Vercel

### Déploiement Initial

#### Option A : Via Vercel Dashboard (Recommandé)

1. Va sur [vercel.com/new](https://vercel.com/new)
2. Importe ton repository GitHub (monorepo principal)
3. Configure :
   - **Framework Preset**: Vite
   - **Root Directory**: `apps/hospital_web`
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
4. Variables d'environnement (automatiquement détectées depuis `.env.production`) :
   ```
   VITE_API_BASE_URL=https://tosumo-web-backend-production.up.railway.app/api/v1
   VITE_APP_TITLE=TOSUMO - Gestion Hospitalière
   VITE_APP_VERSION=1.0.0
   ```
5. Clique sur **Deploy**

#### Option B : Via Vercel CLI

```bash
# Installer Vercel CLI
npm i -g vercel

# Se déplacer dans le dossier frontend
cd apps/hospital_web

# Déployer en production
vercel --prod
```

### Redéploiement

Vercel redéploie automatiquement à chaque push sur la branche `main`/`master`.

Pour forcer un redéploiement :
```bash
cd apps/hospital_web
vercel --prod --force
```

---

## 🧪 Vérification du Déploiement

### 1. Tester le Backend

```bash
# Health check
curl https://tosumo-web-backend-production.up.railway.app/health

# Expected response:
# {"status":"ok","timestamp":"2024-...","uptime":...}
```

### 2. Tester l'API

```bash
# Login test
curl -X POST https://tosumo-web-backend-production.up.railway.app/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"1234567890","password":"test123"}'
```

### 3. Tester le Frontend

1. Ouvre l'URL Vercel dans ton navigateur
2. Essaye de te connecter
3. Vérifie la console du navigateur (F12) pour les erreurs CORS ou API

---

## 🔧 Configuration CORS

Le backend est configuré pour accepter les requêtes de :
- `https://tosumo-web-hospital-web.vercel.app`
- `https://tosumo-hospital-web.vercel.app`
- `http://localhost:5173` (développement)

Si tu as un autre domaine Vercel, ajoute-le dans la variable `CORS_ORIGINS` sur Railway.

---

## 🗄️ Base de Données

### MongoDB Atlas
- **Cluster**: cluster0.5id4izm.mongodb.net
- **Database**: tosumo
- **Partagée** avec les applications mobiles (Doctor et Patient)

### Collections Principales
- `users` - Utilisateurs (admins, docteurs)
- `institutions` - Hôpitaux/Cliniques
- `patients` - Patients
- `appointments` - Rendez-vous
- `consultations` - Consultations médicales

---

## 🔐 Sécurité

### Secrets à Configurer

1. **Générer des secrets JWT sécurisés** :
   ```bash
   # Dans PowerShell
   [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).ToString()))
   ```

2. **Mettre à jour sur Railway** :
   - Settings > Variables
   - Remplacer `JWT_SECRET`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`

### Bonnes Pratiques
- ✅ Utiliser HTTPS partout
- ✅ Secrets JWT différents pour access/refresh tokens
- ✅ CORS strictement configuré
- ✅ Rate limiting activé (voir middleware)
- ✅ Helmet.js pour les headers de sécurité

---

## 📊 Monitoring

### Railway
- Dashboard > Metrics
- Logs en temps réel
- Utilisation CPU/Mémoire

### Vercel
- Dashboard > Analytics
- Logs de déploiement
- Performance metrics

---

## 🐛 Troubleshooting

### Erreur CORS
```
Access to XMLHttpRequest has been blocked by CORS policy
```
**Solution** : Vérifie que l'URL Vercel est dans `CORS_ORIGINS` sur Railway

### Erreur 401 Unauthorized
**Solution** : Vérifie que les JWT secrets sont correctement configurés

### Erreur de connexion MongoDB
**Solution** : Vérifie `MONGODB_URI` sur Railway et l'IP whitelist sur MongoDB Atlas

### Build Failed sur Vercel
**Solution** : Vérifie que le `Root Directory` est bien `apps/hospital_web`

---

## 📝 Logs

### Consulter les logs Railway
```bash
# Via Railway CLI
railway logs
```

### Consulter les logs Vercel
```bash
# Via Vercel CLI
vercel logs
```

Ou via les dashboards respectifs.

---

## 🔄 Rollback

### Backend (Railway)
1. Dashboard > Deployments
2. Clique sur un déploiement précédent
3. "Redeploy"

### Frontend (Vercel)
1. Dashboard > Deployments
2. Clique sur "..." d'un déploiement précédent
3. "Promote to Production"

---

## 📚 Documentation Technique

- Backend API: `web-backend/README.md`
- Frontend: `README.md`
- Architecture: `docs/capability_matrix.md`

---

**Dernière mise à jour** : 2024
**Maintenu par** : TOSUMO Team
