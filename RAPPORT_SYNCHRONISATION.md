# 📊 RAPPORT D'ANALYSE - SYNCHRONISATION DES DONNÉES TOSUMO

**Date:** 15 Septembre 2026  
**Analyste:** Système d'analyse automatisé  
**Priorité:** 🔴 PRIORITÉ 1

---

## 🎯 OBJECTIF

Analyser et corriger le parallélisme et la synchronisation des données entre:
- ✅ **App Doctor** (Flutter)
- ✅ **App Patient** (Flutter)
- ✅ **Backend** (Node.js + MongoDB/Prisma)

---

## 📋 RÉSUMÉ EXÉCUTIF

### ✅ Points Forts
1. **Backend MongoDB** fonctionne comme source unique de vérité (Single Source of Truth)
2. **Persistence locale** implémentée avec Hive dans les deux apps
3. **App Doctor** dispose d'un système de synchronisation avancé (PersistentSyncQueue + SyncService)
4. **Backend** utilise Prisma avec champs `syncVersion` pour versioning
5. **Endpoints API** bien structurés et sécurisés avec authentification

### ⚠️ Problèmes Critiques Identifiés
1. **Inconsistances de modèles** entre Doctor/Patient apps et Backend
2. **Structure Patient différente** entre les deux apps
3. **Types de données incompatibles** (DateTime vs String)
4. **Champs manquants** dans certains modèles
5. **Mappage de réponses** non uniforme entre apps

---

## 🔍 ANALYSE DÉTAILLÉE

### 1️⃣ MODÈLES DE DONNÉES - PATIENT

#### Backend (Prisma Schema)
```prisma
model Patient {
  id             String
  userId         String   @unique
  nin            String?  @unique        // National ID
  firstName      String?
  lastName       String?
  dateOfBirth    DateTime?               // ⚠️ DateTime
  gender         String?
  bloodType      String?
  heightCm       Float?
  weightKg       Float?
  allergies      String[]
  chronicDiseases String[]              // ⚠️ Nom différent
  currentMeds    String[]
  emergencyContactName  String?         // ⚠️ Champs séparés
  emergencyContactPhone String?
  address        String?
  city           String?
  region         String?
  profilePhotoUrl String?
  isOnboarded    Boolean
  isVerified     Boolean
  verifiedBy     String?
  verifiedByName String?
  verifiedAt     DateTime?
  // ... relations
}
```

#### App Doctor - PatientDetail
```dart
class PatientDetail {
  String id;
  String name;                    // ⚠️ Combiné firstName+lastName
  DateTime dateOfBirth;           // ✅ DateTime
  String nationalId;              // ⚠️ Mappé depuis nin
  String bloodType;
  String gender;
  String photoUrl;
  String phone;
  String email;
  List<String> allergies;
  List<String> chronicConditions; // ⚠️ Nom différent
  List<String> currentMeds;
  EmergencyContactInfo? emergencyContact; // ⚠️ Objet imbriqué
  String insuranceProvider;       // ⚠️ MANQUANT dans backend
  String insuranceNumber;         // ⚠️ MANQUANT dans backend
  int healthScore;                // ⚠️ MANQUANT dans backend
  bool verified;
  DateTime? lastVisit;            // ⚠️ MANQUANT dans backend
}
```

#### App Patient - Patient
```dart
class Patient {
  String id;
  String name;                    // ⚠️ Combiné
  String dateOfBirth;             // ❌ String au lieu de DateTime
  String nationalId;
  ContactInfo contactInfo;        // ⚠️ Structure imbriquée différente
  String bloodType;
  List<String> allergies;
  List<String> chronicConditions;
  List<String> currentMeds;
  EmergencyContact emergencyContact; // ⚠️ Structure différente
  String status;                  // ⚠️ MANQUANT dans backend
  bool verified;
  String? gender;
  String? photoUrl;
  String city;
  String address;
}
```

#### 🔴 INCONSISTANCES MAJEURES
| Champ | Backend | Doctor App | Patient App | Problème |
|-------|---------|-----------|-------------|----------|
| `dateOfBirth` | `DateTime?` | `DateTime` | `String` | ❌ Types incompatibles |
| `chronicDiseases` | `String[]` | `chronicConditions` | `chronicConditions` | ⚠️ Nom différent |
| `emergencyContact` | Champs plats | Objet `EmergencyContactInfo` | Objet `EmergencyContact` | ❌ Structures différentes |
| `contactInfo` | Champs plats | Champs directs | Objet `ContactInfo` | ❌ Structure différente |
| `insuranceProvider` | ❌ Manquant | ✅ Existe | ❌ Manquant | ⚠️ Asymétrie |
| `healthScore` | ❌ Manquant | ✅ Existe | ❌ Manquant | ⚠️ Asymétrie |
| `lastVisit` | ❌ Manquant | ✅ Existe | ❌ Manquant | ⚠️ Asymétrie |
| `status` | `isActive` | ❌ Manquant | ✅ Existe | ⚠️ Asymétrie |

---

### 2️⃣ ENDPOINTS API

#### Backend Routes Disponibles

**Patients:**
```typescript
GET    /api/v1/patients/profile               // Patient's own profile
PUT    /api/v1/patients/profile               // Update own profile
POST   /api/v1/patients/onboard               // Onboarding
GET    /api/v1/patients/medical-card          // Get card + QR token
GET    /api/v1/patients/:id                   // Get by ID (with access control)
PUT    /api/v1/patients/:id                   // Update by doctor
GET    /api/v1/patients/medical-records       // Aggregate records
GET    /api/v1/patients/appointments          // Patient's appointments
```

**Doctors:**
```typescript
GET    /api/v1/doctors/patients               // Doctor's patients list
GET    /api/v1/doctors/patients/search        // Search patients
GET    /api/v1/doctors/patients/qr            // Lookup by QR code
GET    /api/v1/doctors/appointments           // Doctor's appointments
```

**Medical Records:**
```typescript
GET    /api/v1/medical-records/patient/:id    // Patient's records (doctor-only)
POST   /api/v1/medical-records/consultations  // Create consultation
GET    /api/v1/medical-records/consultations  // List consultations
POST   /api/v1/medical-records/prescriptions  // Create prescription
GET    /api/v1/medical-records/prescriptions  // List prescriptions
POST   /api/v1/medical-records/lab-results    // Create lab result
POST   /api/v1/medical-records/imaging-results // Create imaging result
```

#### ✅ Alignement des Apps

| Endpoint | Backend | Doctor App | Patient App | Status |
|----------|---------|-----------|-------------|--------|
| GET /patients/profile | ✅ | ✅ | ✅ | ✅ Aligné |
| PUT /patients/profile | ✅ | ✅ | ✅ | ✅ Aligné |
| GET /doctors/patients/qr | ✅ | ✅ | ❌ | ✅ OK (Patient n'en a pas besoin) |
| GET /medical-records/consultations | ✅ | ✅ | ⚠️ | ⚠️ Patient utilise `/patients/medical-records` |
| POST /medical-records/consultations | ✅ | ✅ | ❌ | ✅ OK (Seul doctor crée) |

---

### 3️⃣ PERSISTENCE & SYNCHRONISATION

#### App Doctor ✅ EXCELLENT

**PersistentSyncQueue (Hive)**
```dart
class PersistentSyncQueue {
  // ✅ Queue persistante qui survit aux crashes
  // ✅ Sauvegarde dans Hive
  // ✅ Retry automatique (3 tentatives max)
  // ✅ Tracking des opérations (id, method, endpoint, data)
}
```

**SyncService**
```dart
class SyncService {
  // ✅ Synchronisation automatique toutes les 30 secondes
  // ✅ Détection online/offline
  // ✅ Retry intelligent selon type d'erreur:
  //    - Erreur réseau (timeout) → réessayer
  //    - Erreur serveur (5xx) → réessayer
  //    - Erreur client (4xx) → abandonner (données invalides)
}
```

#### App Patient ⚠️ BASIQUE

**SyncEngine**
```dart
class SyncEngine {
  // ⚠️ Moins robuste que Doctor app
  // ✅ Utilise Hive pour persistence
  // ⚠️ Retry timer 30s fixe
  // ⚠️ Pas de gestion fine des erreurs
}
```

**LocalDatabase**
```dart
class LocalDatabase {
  // ✅ Bien structuré avec box typing
  // ✅ Méthodes CRUD génériques
  // ✅ Session management (activePatientId)
  // ⚠️ Pas de queue de synchronisation explicite
}
```

#### Backend ✅ SOLIDE

**Prisma + MongoDB**
```prisma
// ✅ Champs de versioning
version        Int      @default(1)
syncVersion    Int      @default(1)

// ✅ Soft delete
deletedAt      DateTime?

// ✅ Timestamps automatiques
createdAt      DateTime @default(now())
updatedAt      DateTime @updatedAt
```

---

### 4️⃣ MAPPAGE DES RÉPONSES

#### Backend → Apps (Response Mapping)

**Doctor App - DoctorResponseMapper**
```dart
static Map<String, dynamic> patientDetailFromBackend(json) {
  // ✅ Mappe correctement firstName/lastName → name
  // ✅ Mappe nin → nationalId
  // ✅ Gère emergencyInfos (liste) → emergencyContact (objet)
  // ✅ Mappe chronicDiseases → chronicConditions
  // ⚠️ PROBLÈME: Ajoute healthScore, lastVisit, insuranceProvider
  //              qui n'existent PAS dans le backend
}
```

**Patient App - ResponseMapper**
```dart
static Patient patientFromBackend(json) {
  // ✅ Mappe firstName/lastName → name
  // ✅ Mappe nin → nationalId
  // ❌ PROBLÈME: dateOfBirth reste String au lieu de DateTime
  // ❌ PROBLÈME: Crée ContactInfo imbriqué alors que backend a champs plats
  // ⚠️ PROBLÈME: emergencyContact structure différente
}
```

#### Apps → Backend (Request Mapping)

**Doctor App**
```dart
// ✅ Update patient: Décompose emergencyContact en champs plats
payload['emergencyContactName'] = ec['name'];
payload['emergencyContactPhone'] = ec['phone'];
```

**Patient App**
```dart
// ⚠️ Pas de mapper explicite toBackend trouvé
// ⚠️ Risque: Envoie ContactInfo imbriqué que backend n'attend pas
```

---

## 🚨 PROBLÈMES CRITIQUES PAR PRIORITÉ

### 🔴 PRIORITÉ 1 - BLOQUANT

#### 1. DateOfBirth incompatible (Patient App)
**Problème:** Patient app utilise `String`, Doctor app et Backend utilisent `DateTime`
```dart
// ❌ Actuel (Patient App)
dateOfBirth: String

// ✅ Devrait être
dateOfBirth: DateTime
```
**Impact:** Erreurs de parsing, comparaisons impossibles, calcul d'âge erroné

#### 2. ContactInfo structure incompatible (Patient App)
**Problème:** Patient app crée objet imbriqué, Backend attend champs plats
```dart
// ❌ Actuel (Patient App)
ContactInfo {
  phone: String
  email: String
}

// ✅ Devrait être (champs directs)
phone: String
email: String
```
**Impact:** Échec des updates de profil depuis Patient app

#### 3. EmergencyContact structure différente
**Problème:** 3 structures différentes pour la même donnée
```
Backend:        emergencyContactName, emergencyContactPhone (champs plats)
Doctor App:     EmergencyContactInfo { name, relationship, phone }
Patient App:    EmergencyContact { name, relationship, phone }
```
**Impact:** Incohérence, perte de données, bugs de synchronisation

### 🟠 PRIORITÉ 2 - IMPORTANT

#### 4. Champs fantômes dans Doctor App
**Problème:** Doctor app utilise des champs qui n'existent PAS dans le backend
```dart
insuranceProvider: String    // ❌ N'existe pas dans Prisma
insuranceNumber: String      // ❌ N'existe pas dans Prisma
healthScore: int            // ❌ N'existe pas dans Prisma
lastVisit: DateTime?        // ❌ N'existe pas dans Prisma
```
**Impact:** 
- Données perdues après synchronisation
- Confusion pour les docteurs
- Impossible de persister ces infos

**Solution:** Ajouter ces champs au schema Prisma OU les retirer du modèle Doctor

#### 5. chronicDiseases vs chronicConditions
**Problème:** Nom de champ différent
```
Backend:        chronicDiseases
Doctor App:     chronicConditions
Patient App:    chronicConditions
```
**Impact:** Confusion, nécessite mapping constant

### 🟡 PRIORITÉ 3 - AMÉLIORATION

#### 6. Status field asymétrique
```
Backend:        isActive: Boolean
Patient App:    status: String ('ACTIVE' | 'INACTIVE')
Doctor App:     ❌ Pas de status
```

#### 7. Appointment/Consultation/Prescription
**Problème:** Patient app n'a PAS de modèles individuels
- Patient app utilise `BookletEntry` agrégé
- Doctor app a modèles séparés `Appointment`, `Consultation`, `Prescription`
- Backend a modèles séparés

**Impact:** Patient ne peut pas voir détails structurés de ses consultations

---

## ✅ SOLUTIONS RECOMMANDÉES

### Solution 1: Harmoniser le modèle Patient

#### A. Mettre à jour le Backend (Prisma)
```prisma
model Patient {
  // ... champs existants ...
  
  // Ajouter les champs manquants
  insuranceProvider   String?
  insuranceNumber     String?
  healthScore        Int      @default(0)
  lastVisit          DateTime?
  
  // Renommer pour cohérence
  chronicConditions  String[]  // au lieu de chronicDiseases
}
```

#### B. Standardiser Emergency Contact
**Option 1: Champs plats (Recommandé - Plus simple)**
```prisma
// Backend reste inchangé
emergencyContactName  String?
emergencyContactPhone String?
emergencyContactRelationship String?

// Apps utilisent champs directs
phone: backend.emergencyContactPhone
```

**Option 2: Table séparée (Plus flexible)**
```prisma
model EmergencyInfo {  // ✅ Existe déjà!
  id           String
  patientId    String
  fullName     String
  phone        String
  relationship String
  isPrimary    Boolean
}
```
**Recommandation:** Utiliser `EmergencyInfo` existant, déprécier les champs plats

#### C. Fixer Patient App dateOfBirth
```dart
// Changer dans Patient model
@freezed
sealed class Patient with _$Patient {
  const factory Patient({
    required String id,
    required String name,
    required DateTime dateOfBirth,  // ✅ DateTime au lieu de String
    // ...
  }) = _Patient;
  
  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      // ...
      dateOfBirth: json['dateOfBirth'] is String
          ? DateTime.parse(json['dateOfBirth'])
          : json['dateOfBirth'],
      // ...
    );
  }
}
```

#### D. Fixer Patient App ContactInfo
```dart
// Supprimer ContactInfo imbriqué, utiliser champs directs
@freezed
sealed class Patient with _$Patient {
  const factory Patient({
    required String id,
    required String name,
    required String phone,        // ✅ Direct
    required String email,        // ✅ Direct
    // ... pas de contactInfo: ContactInfo
  }) = _Patient;
}
```

### Solution 2: Aligner les Response Mappers

#### Backend Response Format Standardisé
```typescript
// Créer un PatientDTO
export class PatientDTO {
  id: string;
  name: string;  // firstName + lastName combiné
  nationalId: string;  // nin
  dateOfBirth: string;  // ISO 8601
  gender: string;
  bloodType: string;
  phone: string;  // depuis user.phone
  email: string;  // depuis user.email
  allergies: string[];
  chronicConditions: string[];  // Renommer
  currentMeds: string[];
  emergencyContact: {
    name: string;
    phone: string;
    relationship: string;
  };
  insuranceProvider?: string;
  insuranceNumber?: string;
  healthScore: number;
  verified: boolean;
  lastVisit?: string;
  photoUrl?: string;
  city: string;
  address: string;
}
```

### Solution 3: Améliorer Sync Patient App

```dart
// Copier le système de Doctor app
class PersistentSyncQueue {
  // ... même implémentation que Doctor app
}

class ImprovedSyncService {
  // ✅ Retry intelligent
  // ✅ Gestion erreurs par type
  // ✅ Queue persistante
  // ✅ Polling 30s
}
```

### Solution 4: Tests de bout en bout

```dart
// Test: Doctor crée consultation → Patient la voit
test('Doctor consultation syncs to Patient app', () async {
  // 1. Doctor crée consultation pour Patient X
  final consultation = await doctorRepo.createConsultation(...);
  
  // 2. Attendre sync
  await Future.delayed(Duration(seconds: 35));
  
  // 3. Patient app récupère medical records
  final records = await patientRepo.getMedicalRecords(patientId);
  
  // 4. Vérifier consultation présente
  expect(records.consultations, contains(consultation.id));
});
```

---

## 📊 PLAN D'IMPLÉMENTATION

### Phase 1: Fixes Critiques (1-2 jours) 🔴

1. **Fixer Patient App dateOfBirth**
   - Changer type `String` → `DateTime`
   - Mettre à jour mapper
   - Tester toutes les utilisations

2. **Fixer Patient App ContactInfo**
   - Retirer structure imbriquée
   - Utiliser champs directs
   - Mettre à jour UI

3. **Standardiser EmergencyContact**
   - Utiliser `EmergencyInfo` du backend
   - Mettre à jour mappers des 2 apps
   - Déprécier champs plats

### Phase 2: Harmonisation Backend (2-3 jours) 🟠

4. **Ajouter champs manquants au schema Prisma**
   ```bash
   npx prisma db push
   ```

5. **Renommer chronicDiseases → chronicConditions**
   - Migration Prisma
   - Update code backend
   - Update mappers

6. **Créer DTOs standardisés**
   - PatientDTO
   - ConsultationDTO
   - AppointmentDTO

### Phase 3: Amélioration Sync (2 jours) 🟡

7. **Porter PersistentSyncQueue vers Patient app**

8. **Implémenter retry intelligent**

9. **Tests de synchronisation bout en bout**

### Phase 4: Tests & Validation (1-2 jours) ✅

10. **Tests unitaires mappers**

11. **Tests d'intégration API**

12. **Tests manuels cross-app**
    - Doctor crée consultation → Patient la voit
    - Patient met à jour profil → Doctor voit changements
    - Test offline → online sync

---

## 📈 MÉTRIQUES DE SUCCÈS

### Critères d'Acceptation

✅ **Modèles de données**
- [ ] Tous les champs ont le même nom dans Backend/Doctor/Patient
- [ ] Tous les types sont compatibles (DateTime, structures)
- [ ] Pas de champs fantômes

✅ **Synchronisation**
- [ ] Données créées dans Doctor app visibles dans Patient app < 35s
- [ ] Données créées dans Patient app visibles dans Doctor app < 35s
- [ ] Sync fonctionne après redémarrage app
- [ ] Sync fonctionne après période offline → online

✅ **Intégrité**
- [ ] Pas de perte de données lors des updates
- [ ] EmergencyContact cohérent entre apps
- [ ] dateOfBirth cohérent entre apps

✅ **Tests**
- [ ] 100% des tests unitaires passent
- [ ] Tests d'intégration E2E passent
- [ ] Aucune régression détectée

---

## 🔧 FICHIERS À MODIFIER

### Backend
```
backend/src/prisma/schema.prisma
backend/src/modules/patients/patient.service.ts
backend/src/modules/patients/patient.repository.ts
backend/src/modules/patients/dtos/patient.dto.ts (NOUVEAU)
```

### Doctor App
```
apps/doctor_flutter/lib/domain/models/patient_detail.dart
apps/doctor_flutter/lib/core/data/doctor_response_mapper.dart
apps/doctor_flutter/lib/core/data/repositories/remote_doctor_repository.dart
```

### Patient App
```
apps/patient_flutter/lib/shared/models/patient.dart
apps/patient_flutter/lib/core/data/response_mapper.dart
apps/patient_flutter/lib/core/data/repositories/remote_patient_repository.dart
apps/patient_flutter/lib/core/network/sync_engine.dart (AMÉLIORER)
apps/patient_flutter/lib/core/data/persistent_sync_queue.dart (NOUVEAU)
```

---

## 📝 CONCLUSION

Le système TOSUMO a une **base solide** avec:
- ✅ Backend MongoDB robuste
- ✅ Doctor app avec excellent système de sync
- ✅ Architecture REST bien structurée

Mais souffre de **problèmes de cohérence de données** causés par:
- ❌ Modèles incompatibles entre apps
- ❌ Types de données différents
- ❌ Structures imbriquées non alignées

**Impact utilisateur actuel:**
- 🔴 Patient app ne peut pas synchroniser correctement son profil
- 🔴 Doctor voit des champs vides que Patient a remplis
- 🔴 Données perdues lors des synchronisations

**Après corrections:**
- ✅ Synchronisation bidirectionnelle fiable
- ✅ Données cohérentes entre apps
- ✅ Aucune perte de données
- ✅ Utilisateurs peuvent se reconnecter et retrouver toutes leurs données

**Temps estimé total: 6-10 jours de développement**

---

**Rapport généré le:** 15 Septembre 2026  
**Version:** 1.0  
**Statut:** ⏳ En attente d'implémentation
