# Architecture TOSUMO Hospital Web

## 🏗️ Nouvelle Architecture (Septembre 2026)

L'application web hospitalière TOSUMO utilise maintenant une **architecture séparée** avec son propre backend dédié, distinct du backend partagé utilisé par les applications mobiles.

### Avant (Architecture Partagée)
```
Frontend Web (Vercel) → Backend Partagé (Railway) → MongoDB Atlas
Applications Mobile   ↗
```

### Maintenant (Architecture Séparée)
```
Frontend Web (Vercel) → Backend Web Dédié (Railway) → MongoDB Atlas
Applications Mobile   → Backend Mobile (Railway)     ↗
```

## 🎯 Avantages de la Séparation

### ✅ **Avantages**
- **Maintenance indépendante** - Modifications web sans impact mobile
- **Déploiements séparés** - Pas de downtime croisé
- **API spécialisées** - Endpoints optimisés pour chaque plateforme
- **Sécurité améliorée** - Isolation des accès
- **Développement parallèle** - Équipes peuvent travailler indépendamment

### 🔄 **Base de Données Partagée**
- **MongoDB Atlas reste partagé** pour la cohérence des données
- Même collections `users`, `institutions`, etc.
- Synchronisation automatique entre plateformes
- Un patient créé via mobile apparaît dans le web et vice versa

## 📁 Structure des Dossiers

```
apps/hospital_web/
├── src/                    # Frontend React + TypeScript
├── web-backend/            # Backend Node.js dédié
│   ├── src/
│   │   ├── routes/         # API endpoints
│   │   ├── models/         # Modèles MongoDB
│   │   ├── middleware/     # Auth, CORS, etc.
│   │   └── services/       # Logique métier
│   ├── Dockerfile          # Conteneur Docker
│   └── railway.json        # Config Railway
├── .env.local             # Config développement
├── .env.production        # Config production
└── start-dev.ps1          # Script de démarrage
```

## 🚀 URLs et Ports

### Développement Local
- **Frontend**: http://localhost:5173 (Vite)
- **Backend Web**: http://localhost:4000 (Express)
- **Backend Mobile**: http://localhost:3000 (si actif)

### Production
- **Frontend**: https://tosumo-web-hospital-web.vercel.app
- **Backend Web**: https://tosumo-web-backend.railway.app
- **Backend Mobile**: https://tosumo-production.up.railway.app

## 🔐 Authentification

### Système JWT Indépendant
- **Secrets JWT différents** entre web et mobile
- **Tokens non interchangeables** entre plateformes
- **Sessions séparées** - se connecter sur web n'affecte pas mobile

### Rôles Supportés
- `institution_admin` - Admin centre hospitalier (principal pour web)
- `doctor` - Médecin (créé par institution_admin)
- `patient` - Patient (consultation uniquement)
- `admin`, `superadmin` - Admins système

## 📡 API Endpoints Web

### Base URL
- **Dev**: `http://localhost:4000/api/v1`
- **Prod**: `https://tosumo-web-backend.railway.app/api/v1`

### Endpoints Principaux
```
POST /auth/login                    # Connexion
POST /auth/register/institution     # Inscription centre
GET  /dashboard/stats               # Statistiques dashboard
GET  /institutions                  # Liste centres
GET  /doctors                       # Liste médecins  
GET  /patients                      # Liste patients
POST /institutions/doctors          # Créer médecin
```

## 🗄️ Base de Données

### Collections MongoDB Partagées
```javascript
// Collections utilisées par les deux backends
users              // Utilisateurs (patients, médecins, admins)
institutions       // Centres hospitaliers
doctors            // Profils médecins (deprecated - data dans users)
patients           // Profils patients (deprecated - data dans users)
appointments       // Rendez-vous (futur)
```

### Modèles Unifiés
- **User** - Modèle unifié pour tous les types d'utilisateurs
- **Institution** - Centres hospitaliers, cliniques, etc.
- **Appointment** - Rendez-vous (à implémenter)

## 🎨 Frontend (React + TypeScript)

### Technologies
- **React 18** - Interface utilisateur
- **TypeScript** - Typage statique
- **Tailwind CSS** - Styles
- **React Router** - Navigation
- **Axios** - Requêtes API

### Fonctionnalités
- Dashboard statistiques en temps réel
- Gestion institutions (CRUD)
- Création et gestion médecins
- Consultation patients
- Authentification JWT
- Interface responsive

## 🔧 Backend Web (Node.js + Express)

### Technologies
- **Node.js 18+** - Runtime
- **Express.js** - Framework web
- **TypeScript** - Développement
- **MongoDB + Mongoose** - Base de données
- **JWT** - Authentification
- **bcrypt** - Hachage mots de passe
- **Zod** - Validation données

### Middleware
- **CORS** - Configuration domaines autorisés
- **Helmet** - Sécurité headers HTTP
- **Rate Limiting** - Protection DDoS
- **Compression** - Optimisation taille réponses
- **Morgan** - Logs HTTP

## 🚀 Déploiement

### Développement
```bash
# Démarrer backend + frontend
npm run dev:full

# Ou séparément
npm run backend:dev    # Backend seul
npm run dev           # Frontend seul
```

### Production

#### Backend (Railway)
1. Créer nouveau service Railway
2. Connecter repo GitHub
3. Dossier racine: `apps/hospital_web/web-backend`
4. Variables d'environnement (voir `.env.production`)
5. Déployer avec Docker

#### Frontend (Vercel)  
1. Projet Vercel existant
2. Mettre à jour `VITE_API_BASE_URL`
3. Redéployer

## 🔄 Migration depuis Backend Partagé

### Étapes de Migration
1. ✅ **Backend dédié créé** avec APIs compatibles
2. ✅ **Frontend mis à jour** pour pointer vers nouveau backend
3. 🔄 **Tests des endpoints** et authentification
4. 🔄 **Déploiement Railway** du backend web
5. 🔄 **Mise à jour Vercel** avec nouvelles variables
6. 🔄 **Tests production** complets
7. 📝 **Documentation migration** complétée

### Compatibilité des Données
- **Aucune migration de données** requise
- **Même schéma MongoDB** utilisé
- **Données existantes** accessibles immédiatement
- **Pas de downtime** durant la migration

## 🧪 Tests et Validation

### Tests Manuels Requis
- [ ] Inscription nouvelle institution
- [ ] Connexion avec compte existant
- [ ] Dashboard statistiques
- [ ] Création médecins
- [ ] Consultation patients
- [ ] CORS entre Vercel et Railway
- [ ] Variables d'environnement production

### Identifiants de Test
```
Téléphone: +237691234570
Email: admin@hospital-web.tosumo.cm
Mot de passe: WebAdmin@2024
Rôle: institution_admin
```

## 📞 Support

### En cas de problème
1. **Vérifier les logs** Railway et Vercel
2. **Tester les endpoints** via Postman/curl
3. **Vérifier les variables** d'environnement
4. **Consulter la documentation** API
5. **Revenir au backend partagé** temporairement si critique

### Rollback Rapide
Si problème critique, modifier dans Vercel :
```
VITE_API_BASE_URL=https://tosumo-production.up.railway.app/api/v1
```