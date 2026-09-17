# Guide d'inscription des médecins - Application Web TOSUMO

## 📋 Résumé

L'application web hospitalière TOSUMO permet maintenant aux médecins de s'inscrire en ligne en sélectionnant obligatoirement leur centre de santé d'exercice.

## ✨ Fonctionnalités ajoutées

### 1. **Page d'inscription médecin** (`/register/doctor`)
   - Formulaire complet en 4 sections :
     - **Identité** : Prénom, Nom
     - **Contact** : Email, Téléphone
     - **Informations professionnelles** : 
       - Spécialité médicale (liste déroulante)
       - Numéro de licence professionnelle
       - **Centre de santé** (sélection obligatoire depuis la base MongoDB)
     - **Sécurité** : Mot de passe avec confirmation

### 2. **API Backend** - `POST /api/v1/auth/register/doctor`
   - Validation des données avec Zod
   - Vérification de l'existence du centre de santé
   - Création transactionnelle de :
     - Compte utilisateur (role = `doctor`)
     - Profil médecin (`Doctor`)
     - Liaison médecin ↔ institution (`DoctorInstitution`)
   - Génération automatique des tokens JWT
   - Email de vérification (en production)

### 3. **API Frontend** - `institutionsApi.list()`
   - Récupération de la liste des centres de santé depuis MongoDB Atlas
   - Mapping automatique des données
   - Affichage : Nom — Ville (Type)

## 🏗️ Architecture technique

```
Frontend (React/Vite)
├── DoctorRegister.tsx
│   ├── Formulaire d'inscription
│   ├── Chargement des institutions via institutionsApi
│   └── Soumission via authApi.registerDoctor()
│
├── api.ts
│   ├── institutionsApi.list() → GET /api/v1/institutions
│   ├── authApi.registerDoctor() → POST /api/v1/auth/register/doctor
│   └── mapInstitution() mapper

Backend (Node.js/Express/Prisma)
├── auth.validation.ts
│   └── registerDoctorSchema (validation Zod)
│
├── auth.service.ts
│   └── registerDoctor()
│       ├── Validation téléphone Cameroun
│       ├── Vérification unicité email/phone
│       ├── Transaction Prisma :
│       │   ├── User (role=doctor)
│       │   ├── Doctor (profil médical)
│       │   └── DoctorInstitution (liaison)
│       └── Génération JWT + RefreshToken
│
├── auth.controller.ts
│   └── registerDoctor() → Handler Express
│
└── auth.routes.ts
    └── POST /register/doctor → controller.registerDoctor
```

## 🔐 Sécurité & Validation

### Validation Frontend
- Email au format valide
- Téléphone au format Cameroun (+237...)
- Mot de passe ≥ 8 caractères
- Confirmation mot de passe identique
- Centre de santé obligatoire

### Validation Backend (Zod)
```typescript
{
  firstName: string (min 1),
  lastName: string (min 1),
  email: string (format email),
  phone: string (format Cameroun normalisé),
  password: string (min 8, 1 majuscule, 1 minuscule, 1 chiffre),
  specialty: string (min 1),
  licenseNumber: string (min 1),
  institutionId: string (format UUID)
}
```

### Contrôles métier
- ✅ Email unique (erreur : `EMAIL_ALREADY_REGISTERED`)
- ✅ Téléphone unique (erreur : `PHONE_ALREADY_REGISTERED`)
- ✅ Institution existante (erreur : `Invalid institution ID`)
- ✅ Transaction atomique (tout ou rien)

## 📊 Données créées lors de l'inscription

### 1. **User** (Collection MongoDB)
```json
{
  "id": "abc123...",
  "email": "dr.jean@hopital.cm",
  "phone": "+237691000000",
  "passwordHash": "...",
  "role": "doctor",
  "isActive": true,
  "isEmailVerified": false,
  "isPhoneVerified": false,
  "createdAt": "2026-09-15T10:30:00Z"
}
```

### 2. **Doctor** (Collection MongoDB)
```json
{
  "id": "doc456...",
  "userId": "abc123...",
  "firstName": "Jean",
  "lastName": "Dupont",
  "specialty": "Cardiologie",
  "licenseNumber": "MD-CM-2024-12345",
  "isVerified": false,
  "isAvailable": true,
  "averageRating": 0.0,
  "totalRatings": 0
}
```

### 3. **DoctorInstitution** (Collection MongoDB)
```json
{
  "id": "di789...",
  "doctorId": "doc456...",
  "institutionId": "inst_selected_uuid",
  "isPrimary": true (implicite),
  "createdAt": "2026-09-15T10:30:00Z"
}
```

## 🚀 Utilisation

### 1. **Démarrer le backend**
```bash
cd backend
npm run dev
# OU
node dist/server.js
```
Backend disponible sur : `http://localhost:3000`

### 2. **Démarrer l'application web**
```bash
cd apps/hospital_web
npm run dev
```
Frontend disponible sur : `http://localhost:5173`

### 3. **Accéder au formulaire d'inscription**
- **Depuis la page de connexion** : Cliquer sur "Créer un compte médecin"
- **URL directe** : `http://localhost:5173/register/doctor`

### 4. **Remplir le formulaire**
1. **Identité** : Prénom et Nom
2. **Contact** : Email professionnel + Téléphone (+237...)
3. **Professionnel** :
   - Choisir une spécialité dans la liste
   - Saisir le numéro de licence
   - **Sélectionner le centre de santé** (liste chargée depuis MongoDB)
4. **Sécurité** : Mot de passe sécurisé
5. **Soumettre** → Redirection automatique vers `/login` après 2 secondes

## 🧪 Test de bout en bout

### Scénario de test complet

```bash
# 1. Vérifier que le backend est connecté à MongoDB Atlas
curl http://localhost:3000/api/v1/health
# Réponse attendue : { "status": "ok", "database": "connected" }

# 2. Vérifier que les institutions sont disponibles
curl http://localhost:3000/api/v1/institutions
# Réponse : 6 institutions (CHU de Yaoundé, Hôpital Central, etc.)

# 3. Tester l'inscription d'un nouveau médecin
curl -X POST http://localhost:3000/api/v1/auth/register/doctor \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Marie",
    "lastName": "Kamga",
    "email": "dr.marie.kamga@tosumo.cm",
    "phone": "+237693456789",
    "password": "SecurePass123",
    "specialty": "Pédiatrie",
    "licenseNumber": "MD-CM-2026-78901",
    "institutionId": "67031ee69f98f8d5c9e5f3af"
  }'

# Réponse attendue (201 Created) :
{
  "success": true,
  "message": "Doctor registration successful",
  "data": {
    "user": {
      "id": "...",
      "doctorId": "...",
      "email": "dr.marie.kamga@tosumo.cm",
      "phone": "+237693456789",
      "role": "doctor",
      "firstName": "Marie",
      "lastName": "Kamga",
      "specialty": "Pédiatrie",
      "isEmailVerified": false,
      "isPhoneVerified": false
    },
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIs...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
    }
  }
}

# 4. Vérifier la connexion avec le nouveau compte
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+237693456789",
    "password": "SecurePass123"
  }'
```

### Test via interface web

1. Ouvrir `http://localhost:5173/login`
2. Cliquer sur **"Créer un compte médecin"**
3. Remplir le formulaire avec :
   - Prénom : `Test`
   - Nom : `Medecin`
   - Email : `test.medecin@example.cm`
   - Téléphone : `+237690000001`
   - Spécialité : `Médecine générale`
   - Licence : `TEST-2026-001`
   - Centre : Sélectionner dans la liste
   - Mot de passe : `TestPass123`
   - Confirmer : `TestPass123`
4. Soumettre → Message de succès → Redirection vers login
5. Se connecter avec le nouveau compte

## 🔍 Vérification dans MongoDB Atlas

### Connexion à MongoDB Atlas
```bash
# Connection string
mongodb+srv://russeltsague3_db_user:bPRLbVhxwQpfF7W1@cluster0.5id4izm.mongodb.net/tosumo
```

### Requêtes de vérification

```javascript
// 1. Vérifier le User créé
db.User.findOne({ email: "dr.marie.kamga@tosumo.cm" })

// 2. Vérifier le Doctor créé
db.Doctor.findOne({ 
  userId: "ID_DU_USER_CI_DESSUS" 
})

// 3. Vérifier la liaison avec l'institution
db.DoctorInstitution.findOne({ 
  doctorId: "ID_DU_DOCTOR_CI_DESSUS" 
})

// 4. Compter les nouveaux médecins inscrits aujourd'hui
db.User.count({ 
  role: "doctor",
  createdAt: { $gte: new Date("2026-09-15T00:00:00Z") }
})
```

## 📝 Liste des spécialités disponibles

L'application propose 13 spécialités médicales :

1. Médecine générale
2. Pédiatrie
3. Gynécologie
4. Cardiologie
5. Chirurgie générale
6. Dermatologie
7. ORL
8. Ophtalmologie
9. Radiologie
10. Anesthésie
11. Psychiatrie
12. Urgences
13. Autre

## 🏥 Centres de santé disponibles (MongoDB Atlas)

Actuellement **6 institutions** dans la base de données :

| Nom | Type | Ville | Région |
|-----|------|-------|--------|
| CHU de Yaoundé | hospital | Yaoundé | Centre |
| Hôpital Central | hospital | Douala | Littoral |
| Hôpital Général | hospital | Bafoussam | Ouest |
| Centre de Santé Biyem-Assi | clinic | Yaoundé | Centre |
| Polyclinique du Sud | clinic | Ebolowa | Sud |
| Hôpital de District | hospital | Bertoua | Est |

## 🛠️ Dépannage

### Problème : "Impossible de charger les centres de santé"
**Cause** : Backend non démarré ou MongoDB déconnecté  
**Solution** :
```bash
cd backend
node dist/server.js
# Vérifier : curl http://localhost:3000/api/v1/institutions
```

### Problème : "Email already registered"
**Cause** : Email déjà utilisé  
**Solution** : Utiliser un email différent ou vérifier dans MongoDB :
```javascript
db.User.findOne({ email: "votre_email@example.cm" })
```

### Problème : "Phone number already registered"
**Cause** : Numéro de téléphone déjà enregistré  
**Solution** : Utiliser un numéro différent ou normaliser :
```javascript
// Les formats suivants sont équivalents :
"+237691000000"
"237691000000"
"691000000"
```

### Problème : "Invalid institution ID"
**Cause** : ID d'institution inexistant  
**Solution** : Vérifier la liste des institutions :
```bash
curl http://localhost:3000/api/v1/institutions | jq '.data.institutions[].id'
```

## 📦 Fichiers modifiés

### Frontend
- ✅ `apps/hospital_web/src/pages/DoctorRegister.tsx` (nouveau)
- ✅ `apps/hospital_web/src/App.tsx` (route ajoutée)
- ✅ `apps/hospital_web/src/pages/Login.tsx` (bouton inscription)
- ✅ `apps/hospital_web/src/services/api.ts` (institutionsApi + registerDoctor)

### Backend
- ✅ `backend/src/modules/auth/auth.validation.ts` (registerDoctorSchema)
- ✅ `backend/src/modules/auth/auth.service.ts` (registerDoctor method)
- ✅ `backend/src/modules/auth/auth.controller.ts` (registerDoctor handler)
- ✅ `backend/src/modules/auth/auth.routes.ts` (route POST /register/doctor)

## 🚢 Déploiement

### Commit & Push
```bash
git status
git add apps/hospital_web/ backend/src/modules/auth/
git commit -m "feat: Add doctor registration with health center selection"
git push origin feature/hospital-web-sync-fixes
```

### Build production
```bash
# Backend
cd backend
npm run build

# Frontend
cd apps/hospital_web
npm run build
# Fichiers générés dans : apps/hospital_web/dist/
```

## 📚 Prochaines étapes suggérées

1. **Vérification médecin** : Workflow d'approbation par l'administrateur
2. **Upload documents** : Licence médicale, diplômes (scan PDF)
3. **Photo de profil** : Upload avatar médecin
4. **Vérification email** : Envoyer email de confirmation automatique
5. **Vérification téléphone** : OTP SMS lors de l'inscription
6. **Multi-institutions** : Permettre à un médecin d'exercer dans plusieurs centres
7. **Dashboard médecin** : Page d'accueil personnalisée après connexion
8. **Gestion disponibilités** : Configurer les horaires de consultation

---

## ✅ Statut de l'implémentation

| Fonctionnalité | Statut | Notes |
|----------------|--------|-------|
| Frontend formulaire inscription | ✅ Complet | Tous les champs + validation |
| API institutionsApi | ✅ Complet | Liste centres de santé |
| API registerDoctor | ✅ Complet | Frontend → Backend |
| Backend validation | ✅ Complet | Zod schema |
| Backend service | ✅ Complet | Transaction User+Doctor+Link |
| Backend endpoint | ✅ Complet | POST /register/doctor |
| Tests unitaires | ❌ À faire | Tests Jest recommandés |
| Tests E2E | ❌ À faire | Cypress/Playwright |
| Documentation API | ⚠️ Partiel | Ce document suffit pour dev |

---

**Date de création** : 15 septembre 2026  
**Auteur** : Équipe TOSUMO  
**Version** : 1.0  
**Branche Git** : `feature/hospital-web-sync-fixes`
