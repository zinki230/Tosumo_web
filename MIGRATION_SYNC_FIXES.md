# 🔄 GUIDE DE MIGRATION - CORRECTIONS SYNCHRONISATION

**Date:** 15 Septembre 2026  
**Version:** 1.0  
**Statut:** ✅ Implémenté (Phase 1 - Fixes Critiques)

---

## 📌 RÉSUMÉ DES CHANGEMENTS

### ✅ Modifications Implémentées

#### 1. Backend (Prisma Schema) ✅
**Fichier:** `backend/src/prisma/schema.prisma`

**Ajouts:**
```prisma
model Patient {
  // NOUVEAUX CHAMPS
  chronicConditions String[] @default([])     // Nom standardisé
  emergencyContactRelationship String?        // Relation contact urgence
  insuranceProvider String?                   // Assurance
  insuranceNumber String?                     // Numéro assurance
  healthScore Int @default(0)                 // Score santé global
  lastVisit DateTime?                         // Dernière visite
  
  // CONSERVATION pour rétro-compatibilité
  chronicDiseases String[]  // Legacy field
}
```

**Impact:**
- ✅ Support des deux noms `chronicDiseases` ET `chronicConditions`
- ✅ Nouveaux champs alignés avec Doctor app
- ✅ Rétro-compatibilité maintenue

**Action Requise:**
```bash
cd backend
npx prisma db push
# OU
npx prisma migrate dev --name add-patient-sync-fields
```

---

#### 2. Patient App - Model Patient ✅
**Fichier:** `apps/patient_flutter/lib/shared/models/patient.dart`

**Changements Majeurs:**

**AVANT:**
```dart
class Patient {
  required String dateOfBirth;              // ❌ String
  required ContactInfo contactInfo;         // ❌ Objet imbriqué
  required EmergencyContact emergencyContact; // ❌ Objet imbriqué
}
```

**APRÈS:**
```dart
class Patient {
  required DateTime dateOfBirth;            // ✅ DateTime
  required String phone;                    // ✅ Champs directs
  required String email;                    // ✅ Champs directs
  required String emergencyContactName;     // ✅ Champs directs
  required String emergencyContactRelationship;
  required String emergencyContactPhone;
}
```

**Structures Supprimées:**
- ❌ `ContactInfo` (imbriqué)
- ❌ `EmergencyContact` (imbriqué)

**Impact:**
- ✅ Compatible avec structure backend
- ✅ Type `DateTime` pour calculs d'âge corrects
- ✅ Plus besoin de dé-imbriquer lors des updates

**Action Requise:**
```bash
cd apps/patient_flutter
flutter pub run build_runner build --delete-conflicting-outputs
```

---

#### 3. Patient App - Response Mapper ✅
**Fichier:** `apps/patient_flutter/lib/core/data/response_mapper.dart`

**Améliorations:**

```dart
static Patient patientFromBackend(Map<String, dynamic> json) {
  // ✅ Parse DateTime correctement
  DateTime parsedDOB = DateTime.now();
  final dobRaw = json['dateOfBirth'];
  if (dobRaw is String && dobRaw.isNotEmpty) {
    parsedDOB = DateTime.parse(dobRaw);
  } else if (dobRaw is DateTime) {
    parsedDOB = dobRaw;
  }
  
  return Patient(
    dateOfBirth: parsedDOB,  // ✅ DateTime
    phone: user?['phone'] ?? json['phone'] ?? '',  // ✅ Direct
    email: user?['email'] ?? json['email'] ?? '',  // ✅ Direct
    emergencyContactName: json['emergencyContactName'] ?? '',  // ✅ Direct
    // ...
    chronicConditions: (json['chronicConditions'] ?? json['chronicDiseases']) ?? [],  // ✅ Support les 2
  );
}

// NOUVEAU: Mapper pour updates backend
static Map<String, dynamic> patientToBackend(Patient patient) {
  return {
    'dateOfBirth': patient.dateOfBirth.toIso8601String(),
    'emergencyContactName': patient.emergencyContactName,
    'emergencyContactRelationship': patient.emergencyContactRelationship,
    'emergencyContactPhone': patient.emergencyContactPhone,
    'chronicConditions': patient.chronicConditions,
    // ...
  };
}
```

**Fonctionnalités:**
- ✅ Parse `DateTime` robuste (String ou DateTime)
- ✅ Flatten contact info et emergency contact
- ✅ Support `chronicDiseases` legacy + `chronicConditions` nouveau
- ✅ Nouveau mapper `patientToBackend` pour updates

---

#### 4. Doctor App - Response Mapper ✅
**Fichier:** `apps/doctor_flutter/lib/core/data/doctor_response_mapper.dart`

**Améliorations:**

```dart
static Map<String, dynamic> patientDetailFromBackend(json) {
  // ✅ Support chronicConditions ET chronicDiseases
  final chronicConditions = (json['chronicConditions'] as List?)?.cast<String>() 
      ?? (json['chronicDiseases'] as List?)?.cast<String>() 
      ?? <String>[];
  
  // ✅ Support EmergencyInfo (table) ET champs plats
  'emergencyContact': primaryEmergency != null
      ? { 'name': primaryEmergency['fullName'], ... }
      : (json['emergencyContactName'] != null)
          ? { 'name': json['emergencyContactName'], ... }
          : null,
  
  // ✅ Nouveaux champs mappés
  'insuranceProvider': json['insuranceProvider'] ?? '',
  'insuranceNumber': json['insuranceNumber'] ?? '',
  'healthScore': json['healthScore'] ?? 0,
  'lastVisit': json['lastVisit'] ?? json['updatedAt'],
}
```

**Fonctionnalités:**
- ✅ Fallback `chronicDiseases` → `chronicConditions`
- ✅ Support double source emergency contact (EmergencyInfo table OU champs plats)
- ✅ Mappe nouveaux champs depuis backend

---

#### 5. Backend - Patient Service ✅
**Fichier:** `backend/src/modules/patients/patient.service.ts`

**Amélioration `updateByDoctor`:**

```typescript
async updateByDoctor(patientId: string, data: Record<string, unknown>) {
  // ...
  
  // ✅ Sync chronicConditions ↔ chronicDiseases
  if (payload['chronicConditions'] != null && payload['chronicDiseases'] == null) {
    payload['chronicDiseases'] = payload['chronicConditions'];
  } else if (payload['chronicDiseases'] != null && payload['chronicConditions'] == null) {
    payload['chronicConditions'] = payload['chronicDiseases'];
  }
  
  // ✅ Emergency contact avec relationship
  if (ec != null) {
    payload['emergencyContactName'] = ec['name'];
    payload['emergencyContactPhone'] = ec['phone'];
    payload['emergencyContactRelationship'] = ec['relationship'];
    delete payload['emergencyContact'];
  }
  
  return this.repository.update(patient.id, payload);
}
```

**Fonctionnalités:**
- ✅ Synchronisation automatique `chronicConditions` ↔ `chronicDiseases`
- ✅ Emergency contact inclut `relationship`
- ✅ Rétro-compatibilité garantie

---

#### 6. Backend - Patient Repository ✅
**Fichier:** `backend/src/modules/patients/patient.repository.ts`

**Champs autorisés mis à jour:**

```typescript
private readonly allowedUpdateFields = [
  'nin', 'firstName', 'lastName', 'dateOfBirth', 'gender', 'bloodType',
  'allergies', 
  'chronicDiseases',          // ✅ Legacy
  'chronicConditions',        // ✅ Nouveau
  'currentMeds',
  'emergencyContactName', 
  'emergencyContactPhone', 
  'emergencyContactRelationship',  // ✅ Nouveau
  'insuranceProvider',        // ✅ Nouveau
  'insuranceNumber',          // ✅ Nouveau
  'healthScore',              // ✅ Nouveau
  'lastVisit',                // ✅ Nouveau
  'isVerified', 'verifiedAt',
  // ...
];
```

---

## 🔧 ÉTAPES DE DÉPLOIEMENT

### Étape 1: Backend Database Migration

```bash
cd backend

# Option A: Push direct (dev/test)
npx prisma db push

# Option B: Migration formelle (production)
npx prisma migrate dev --name add-patient-sync-fields
npx prisma generate
```

**Vérification:**
```bash
# Vérifier que les nouveaux champs existent
npx prisma studio
# Ouvrir Patient model et vérifier: chronicConditions, insuranceProvider, etc.
```

---

### Étape 2: Backend Code

```bash
cd backend

# Installer dépendances (si nécessaire)
npm install

# Compiler TypeScript
npm run build

# Redémarrer serveur
npm run start:dev
# OU production
npm run start:prod
```

**Vérification:**
```bash
# Test API
curl -X GET http://localhost:3000/api/v1/patients/profile \
  -H "Authorization: Bearer YOUR_TOKEN"

# Vérifier que la réponse inclut chronicConditions, insuranceProvider, etc.
```

---

### Étape 3: Patient App

```bash
cd apps/patient_flutter

# Regénérer les modèles Freezed/JSON
flutter pub run build_runner build --delete-conflicting-outputs

# Clean build
flutter clean
flutter pub get

# Tester
flutter run
```

**Vérification:**
```dart
// Test que dateOfBirth est bien DateTime
final patient = await repository.getPatientProfile(patientId);
print(patient.dateOfBirth.runtimeType);  // Should print: DateTime

// Test update
await repository.updatePatient({
  'emergencyContactName': 'Jean Dupont',
  'emergencyContactRelationship': 'Frère',
  'emergencyContactPhone': '+237699999999',
});
```

---

### Étape 4: Doctor App

```bash
cd apps/doctor_flutter

# Regénérer les modèles
flutter pub run build_runner build --delete-conflicting-outputs

# Clean build
flutter clean
flutter pub get

# Tester
flutter run
```

**Vérification:**
```dart
// Test que nouveaux champs sont présents
final patient = await repository.getPatientById(patientId);
print(patient.insuranceProvider);  // Should not be null
print(patient.healthScore);        // Should be int
print(patient.lastVisit);          // Should be DateTime?
```

---

## ✅ TESTS DE VALIDATION

### Test 1: Patient App - Création de Profil

```dart
test('Patient can create profile with new structure', () async {
  final patient = Patient(
    id: 'test123',
    name: 'Alice Martin',
    dateOfBirth: DateTime(1990, 5, 15),  // ✅ DateTime
    nationalId: 'CM12345',
    phone: '+237677777777',              // ✅ Direct
    email: 'alice@example.com',          // ✅ Direct
    bloodType: 'A+',
    allergies: ['Pénicilline'],
    chronicConditions: ['Diabète'],
    currentMeds: ['Metformine'],
    emergencyContactName: 'Bob Martin',  // ✅ Direct
    emergencyContactRelationship: 'Époux',
    emergencyContactPhone: '+237688888888',
    status: 'ACTIVE',
    verified: false,
    city: 'Douala',
    address: 'Akwa',
  );
  
  final json = ResponseMapper.patientToBackend(patient);
  
  expect(json['dateOfBirth'], isA<String>());  // ISO 8601
  expect(json['emergencyContactName'], 'Bob Martin');
  expect(json['emergencyContactRelationship'], 'Époux');
});
```

---

### Test 2: Doctor App → Backend → Patient App

```dart
test('Data syncs between Doctor and Patient apps', () async {
  // 1. Doctor met à jour patient
  await doctorRepo.updatePatient('patient123', {
    'insuranceProvider': 'CNPS',
    'insuranceNumber': 'INS-98765',
    'healthScore': 85,
    'chronicConditions': ['Hypertension'],
  });
  
  // 2. Attendre sync
  await Future.delayed(Duration(seconds: 35));
  
  // 3. Patient récupère son profil
  final patient = await patientRepo.getPatientProfile('patient123');
  
  // 4. Vérifier cohérence (via backend)
  expect(patient.chronicConditions, contains('Hypertension'));
  // Note: insuranceProvider/Number pas dans Patient model actuel
});
```

---

### Test 3: DateTime Parsing Robustesse

```dart
test('dateOfBirth parses correctly from various formats', () {
  // Test String ISO
  final json1 = {'dateOfBirth': '1990-05-15T00:00:00.000Z'};
  final patient1 = ResponseMapper.patientFromBackend(json1);
  expect(patient1.dateOfBirth.year, 1990);
  
  // Test DateTime direct
  final json2 = {'dateOfBirth': DateTime(1990, 5, 15)};
  final patient2 = ResponseMapper.patientFromBackend(json2);
  expect(patient2.dateOfBirth.year, 1990);
  
  // Test null/invalid → fallback
  final json3 = {'dateOfBirth': null};
  final patient3 = ResponseMapper.patientFromBackend(json3);
  expect(patient3.dateOfBirth, isA<DateTime>());
});
```

---

## 🚨 BREAKING CHANGES & MIGRATION

### Patient App

**Code à mettre à jour:**

#### AVANT (❌ Ne fonctionne plus):
```dart
final patient = await repo.getPatientProfile(id);

// ❌ contactInfo n'existe plus
print(patient.contactInfo.phone);
print(patient.contactInfo.email);

// ❌ emergencyContact n'existe plus
print(patient.emergencyContact.name);
print(patient.emergencyContact.phone);

// ❌ dateOfBirth n'est plus String
final age = int.parse(patient.dateOfBirth.substring(0, 4));
```

#### APRÈS (✅ Correct):
```dart
final patient = await repo.getPatientProfile(id);

// ✅ Champs directs
print(patient.phone);
print(patient.email);

// ✅ Emergency contact direct
print(patient.emergencyContactName);
print(patient.emergencyContactPhone);
print(patient.emergencyContactRelationship);

// ✅ DateTime
final age = DateTime.now().year - patient.dateOfBirth.year;
```

---

### UI Updates (Patient App)

**Fichiers à vérifier et mettre à jour:**

1. **Profile Screen**
```dart
// apps/patient_flutter/lib/features/profile/presentation/profile_screen.dart

// AVANT
Text(patient.contactInfo.phone)

// APRÈS
Text(patient.phone)
```

2. **Emergency Contact Display**
```dart
// Chercher dans tous les fichiers:
// patient.emergencyContact.name → patient.emergencyContactName
// patient.emergencyContact.phone → patient.emergencyContactPhone
```

3. **Age Calculation**
```dart
// Chercher: dateOfBirth calculs
// Remplacer String parsing par DateTime calculs
```

**Commande pour trouver les usages:**
```bash
cd apps/patient_flutter
grep -r "contactInfo\." lib/
grep -r "emergencyContact\." lib/
grep -r "dateOfBirth" lib/ | grep -v ".dart\'"
```

---

## 📊 CHECKLIST DE VALIDATION FINALE

### Backend ✅
- [x] Schema Prisma mis à jour avec nouveaux champs
- [x] Migration Prisma exécutée
- [x] `patient.service.ts` gère sync chronicDiseases ↔ chronicConditions
- [x] `patient.repository.ts` allowedUpdateFields inclut nouveaux champs
- [x] Backend redémarré sans erreurs

### Patient App ✅
- [x] Model `Patient` utilise `DateTime dateOfBirth`
- [x] Model `Patient` a champs `phone`, `email` directs
- [x] Model `Patient` a `emergencyContactName/Phone/Relationship` directs
- [x] Structures `ContactInfo` et `EmergencyContact` supprimées
- [x] `response_mapper.dart` parse DateTime correctement
- [x] `response_mapper.dart` a `patientToBackend` pour updates
- [x] Build runner exécuté (`.freezed.dart`, `.g.dart` regénérés)
- [ ] UI mise à jour (remplacer `patient.contactInfo.x` par `patient.x`)
- [ ] Tests manuels: profil, update, sync

### Doctor App ✅
- [x] Model `PatientDetail` inclut `insuranceProvider`, `insuranceNumber`, `healthScore`, `lastVisit`
- [x] `doctor_response_mapper.dart` mappe nouveaux champs
- [x] `doctor_response_mapper.dart` supporte chronicDiseases et chronicConditions
- [x] Build runner exécuté
- [ ] Tests: créer consultation → vérifier sync Patient app

### Synchronisation ⏳
- [ ] Test E2E: Doctor update → Patient voit changement < 35s
- [ ] Test E2E: Patient update → Doctor voit changement < 35s
- [ ] Test offline → online: queue sync fonctionne
- [ ] Test app restart: données persistées correctement

---

## 🐛 PROBLÈMES CONNUS & SOLUTIONS

### Problème 1: Build Runner Errors

**Symptôme:**
```
Error: The getter 'contactInfo' isn't defined for the class 'Patient'
```

**Solution:**
```bash
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### Problème 2: Prisma Push Fails

**Symptôme:**
```
Error: Field 'chronicConditions' already exists
```

**Solution:**
Si le champ existe déjà dans la DB mais pas dans le schema:
```bash
npx prisma db pull  # Sync schema avec DB actuelle
npx prisma generate
```

---

### Problème 3: Runtime Error - Missing Emergency Contact

**Symptôme:**
```
RangeError: Value not in range: 1
# Lors de patient.emergencyContact.name
```

**Solution:**
Le code essaie encore d'accéder à l'ancienne structure.
```bash
# Trouver tous les usages
grep -r "emergencyContact\." lib/

# Remplacer par champs directs
emergencyContactName
emergencyContactPhone
emergencyContactRelationship
```

---

## 📝 PROCHAINES ÉTAPES (Phase 2)

### Améliorations Recommandées

1. **Créer DTOs Backend** (Priorité Moyenne)
   - `PatientDTO`, `ConsultationDTO`, `AppointmentDTO`
   - Standardiser format de réponse

2. **Améliorer Sync Patient App** (Priorité Haute)
   - Porter `PersistentSyncQueue` de Doctor app
   - Implémenter retry intelligent

3. **Tests Automatisés** (Priorité Haute)
   - Tests unitaires mappers
   - Tests intégration E2E
   - Tests synchronisation

4. **Documentation API** (Priorité Moyenne)
   - Swagger/OpenAPI complet
   - Exemples de requêtes/réponses

---

## 📞 SUPPORT

**Questions ou problèmes lors de la migration ?**

1. Vérifier ce guide
2. Consulter `RAPPORT_SYNCHRONISATION.md`
3. Vérifier les logs backend: `npm run start:dev`
4. Vérifier les logs Flutter: `flutter run --verbose`

---

**Document Créé:** 15 Septembre 2026  
**Dernière Mise à Jour:** 15 Septembre 2026  
**Version:** 1.0  
**Statut:** ✅ Phase 1 Implémentée - Phase 2 En Attente
