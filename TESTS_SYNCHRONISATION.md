# 🧪 PLAN DE TESTS - SYNCHRONISATION DES DONNÉES

**Date:** 15 Septembre 2026  
**Version:** 1.0  
**Objectif:** Valider le flux de données Create → Sync → Retrieve entre Doctor app, Patient app et Backend

---

## 📋 PRÉREQUIS

### Environnement de Test

```bash
# Backend démarré
cd backend
npm run start:dev
# Port: 3000 (ou selon configuration)

# MongoDB accessible
# Connection string: voir backend/.env

# Doctor app lancée
cd apps/doctor_flutter
flutter run
# Appareil: Android Emulator / iOS Simulator / Device

# Patient app lancée
cd apps/patient_flutter
flutter run
# Appareil: Différent de Doctor app (2e émulateur ou device physique)
```

### Comptes de Test

**Doctor:**
- Email: `doctor.test@tosumo.cm`
- Phone: `+237677000001`
- Password: `Test123456!`

**Patient:**
- Email: `patient.test@tosumo.cm`
- Phone: `+237677000002`
- Password: `Test123456!`

---

## 🎯 SCÉNARIOS DE TEST

### 📱 TEST 1: Création Patient → Synchronisation Backend

**Objectif:** Vérifier que les données créées dans Patient app sont correctement envoyées au backend

**Étapes:**

1. **Connexion Patient App**
   ```
   ✅ Ouvrir Patient app
   ✅ Se connecter avec patient.test@tosumo.cm
   ✅ Accéder au profil
   ```

2. **Compléter Profil Patient**
   ```
   ✅ Nom: "Alice Martin"
   ✅ Date de naissance: 15/05/1990 (⚠️ Doit être DateTime maintenant)
   ✅ Sexe: Féminin
   ✅ Groupe sanguin: A+
   ✅ Téléphone: +237677000002
   ✅ Email: patient.test@tosumo.cm
   ✅ Ville: Douala
   ✅ Adresse: Akwa, Rue 123
   ```

3. **Ajouter Allergies et Maladies**
   ```
   ✅ Allergies: Pénicilline, Arachides
   ✅ Maladies chroniques: Diabète Type 2
   ✅ Médicaments actuels: Metformine 500mg
   ```

4. **Configurer Contact d'Urgence**
   ```
   ✅ Nom: Bob Martin
   ✅ Relation: Époux
   ✅ Téléphone: +237688000001
   ```

5. **Sauvegarder et Attendre Sync**
   ```
   ✅ Cliquer "Enregistrer"
   ✅ Observer message de succès
   ✅ Attendre 35 secondes (sync automatique)
   ```

**Vérification Backend:**

```bash
# Méthode 1: Via Prisma Studio
npx prisma studio
# Ouvrir Patient model
# Chercher patient avec phone +237677000002
# ✅ Vérifier tous les champs présents

# Méthode 2: Via API
curl -X GET "http://localhost:3000/api/v1/patients/profile" \
  -H "Authorization: Bearer PATIENT_TOKEN"

# ✅ Vérifier JSON response contient:
# - firstName: "Alice"
# - lastName: "Martin"
# - dateOfBirth: "1990-05-15T00:00:00.000Z"
# - bloodType: "A+"
# - allergies: ["Pénicilline", "Arachides"]
# - chronicConditions: ["Diabète Type 2"]
# - emergencyContactName: "Bob Martin"
# - emergencyContactRelationship: "Époux"
# - emergencyContactPhone: "+237688000001"
```

**Résultat Attendu:**
- ✅ Profil sauvegardé localement (Hive)
- ✅ Données synchronisées au backend < 35s
- ✅ Tous les champs présents dans MongoDB
- ✅ Types corrects (DateTime, etc.)

---

### 🩺 TEST 2: Doctor Scan QR → Accès Patient → Modification

**Objectif:** Vérifier que le docteur peut scanner le QR d'un patient, accéder à son dossier et le modifier

**Étapes:**

1. **Générer QR Code Patient**
   ```
   ✅ Patient app: Aller dans "Ma Carte Médicale"
   ✅ Afficher QR code
   ✅ Note: Le QR contient un token JWT signé (pas de données sensibles)
   ```

2. **Doctor Scan QR**
   ```
   ✅ Doctor app: Aller dans "Scanner"
   ✅ Scanner le QR code du patient
   ✅ Observer: "Patient identifié"
   ✅ Affichage: Nom, groupe sanguin, allergies, contact urgence
   ```

3. **Accéder au Dossier**
   ```
   ✅ Cliquer "Compléter les informations" (si non vérifié)
   OU
   ✅ Cliquer "Ouvrir le dossier patient" (si vérifié)
   ✅ Navigation vers /patient/:id
   ```

4. **Vérifier Patient (Premier Accès)**
   ```
   ✅ Vérifier informations affichées:
     - Nom: Alice Martin
     - Date naissance: 15/05/1990 (âge: 36 ans)
     - Groupe sanguin: A+
     - Allergies: Pénicilline, Arachides
     - Maladies chroniques: Diabète Type 2
     - Contact urgence: Bob Martin (Époux) +237688000001
   ```

5. **Ajouter Informations Médicales**
   ```
   ✅ Onglet "Informations"
   ✅ Ajouter:
     - Assurance: CNPS
     - N° Assurance: INS-12345-2024
     - Score santé: 75
   ✅ Marquer "Patient vérifié" ✓
   ✅ Sauvegarder
   ```

6. **Attendre Synchronisation**
   ```
   ✅ Observer message "Synchronisation en cours..."
   ✅ Attendre 35 secondes
   ✅ Observer message "Synchronisé ✓"
   ```

**Vérification Backend:**

```bash
# Vérifier via API
curl -X GET "http://localhost:3000/api/v1/doctors/patients/qr?token=PATIENT_QR_TOKEN" \
  -H "Authorization: Bearer DOCTOR_TOKEN"

# ✅ Vérifier réponse contient:
# - isVerified: true
# - verifiedBy: DOCTOR_USER_ID
# - verifiedAt: timestamp récent
# - insuranceProvider: "CNPS"
# - insuranceNumber: "INS-12345-2024"
# - healthScore: 75
```

**Résultat Attendu:**
- ✅ QR scan fonctionne (timeout réduit à 5s)
- ✅ Patient non vérifié permet navigation vers détail
- ✅ Doctor peut compléter informations
- ✅ Nouveau champs (assurance, healthScore) sauvegardés
- ✅ isVerified = true après validation doctor
- ✅ Sync vers backend < 35s

---

### 🔄 TEST 3: Doctor Update → Patient Voit Changements

**Objectif:** Vérifier synchronisation Doctor → Backend → Patient

**Étapes:**

1. **Doctor Crée Consultation**
   ```
   ✅ Doctor app: Ouvrir dossier Alice Martin
   ✅ Onglet "Consultations"
   ✅ Créer nouvelle consultation:
     - Motif: "Contrôle diabète"
     - Symptômes: "Fatigue, soif excessive"
     - Diagnostic: "Diabète Type 2 déséquilibré"
     - Tension: 130/85
     - Glycémie: 1.85 g/L
     - Poids: 68 kg
   ✅ Sauvegarder
   ```

2. **Doctor Prescrit Médicaments**
   ```
   ✅ Ajouter prescription:
     - Médicament: Metformine 850mg
     - Posologie: 1 cp matin et soir
     - Durée: 3 mois
   ✅ Signer prescription
   ✅ Sauvegarder
   ```

3. **Doctor Met à Jour healthScore**
   ```
   ✅ Onglet "Informations"
   ✅ Modifier healthScore: 75 → 68 (déséquilibre)
   ✅ Ajouter note: "Revoir dans 1 mois"
   ✅ Sauvegarder
   ```

4. **Attendre Synchronisation**
   ```
   ✅ Observer sync queue: 3 opérations en attente
   ✅ Attendre 35 secondes
   ✅ Vérifier sync queue: 0 opérations (toutes envoyées)
   ```

5. **Patient Rafraîchit Dossier**
   ```
   ✅ Patient app: Aller dans "Carnet de Santé"
   ✅ Pull-to-refresh (tirer vers le bas)
   ✅ Observer chargement
   ```

**Vérification Patient App:**

```
✅ Nouvelle entrée affichée:
  - Date: Aujourd'hui
  - Titre: "Contrôle diabète"
  - Docteur: Dr. [Nom du docteur]
  - Établissement: [Nom hôpital]
  
✅ Cliquer sur l'entrée pour détails:
  - Diagnostic: "Diabète Type 2 déséquilibré"
  - Symptômes: "Fatigue, soif excessive"
  - Tension: 130/85
  - Glycémie: 1.85 g/L
  - Poids: 68 kg
  
✅ Prescription visible:
  - Metformine 850mg
  - 1 cp matin et soir
  - Durée: 3 mois
  - Statut: Active
```

**Résultat Attendu:**
- ✅ Consultation créée par Doctor → backend < 35s
- ✅ Patient voit consultation dans carnet < 1 min après refresh
- ✅ Prescription visible dans patient app
- ✅ healthScore mis à jour (pas visible patient mais dans backend)

---

### 📲 TEST 4: Patient Update → Doctor Voit Changements

**Objectif:** Vérifier synchronisation Patient → Backend → Doctor

**Étapes:**

1. **Patient Met à Jour Profil**
   ```
   ✅ Patient app: Aller dans "Profil"
   ✅ Modifier:
     - Téléphone: +237677000002 → +237677000099
     - Adresse: Akwa, Rue 123 → Bonanjo, Avenue de la Liberté
     - Ajouter allergie: Latex
   ✅ Sauvegarder
   ✅ Observer: "Enregistré ✓"
   ```

2. **Attendre Synchronisation Patient→Backend**
   ```
   ✅ Attendre 35 secondes (sync automatique)
   ✅ Vérifier dans logs app: "Synchronisation réussie"
   ```

3. **Doctor Rafraîchit Patient**
   ```
   ✅ Doctor app: Retourner sur dossier Alice Martin
   ✅ Pull-to-refresh
   ✅ Observer chargement
   ```

**Vérification Doctor App:**

```
✅ Informations mises à jour:
  - Téléphone: +237677000099 (changé)
  - Adresse: Bonanjo, Avenue de la Liberté (changé)
  - Allergies: Pénicilline, Arachides, Latex (ajouté)
```

**Vérification Backend:**

```bash
curl -X GET "http://localhost:3000/api/v1/patients/ALICE_PATIENT_ID" \
  -H "Authorization: Bearer DOCTOR_TOKEN"

# ✅ Vérifier JSON:
# - user.phone: "+237677000099"
# - address: "Bonanjo, Avenue de la Liberté"
# - allergies: ["Pénicilline", "Arachides", "Latex"]
```

**Résultat Attendu:**
- ✅ Patient modifie profil → backend < 35s
- ✅ Doctor refresh → voit changements
- ✅ Pas de perte de données
- ✅ Allergies additives (pas écrasées)

---

### 🔌 TEST 5: Mode Hors Ligne → Reconnexion → Sync

**Objectif:** Vérifier que la queue de synchronisation persistante fonctionne

**Étapes:**

1. **Doctor Hors Ligne**
   ```
   ✅ Doctor app en ligne
   ✅ Activer mode avion sur le device
   ✅ Vérifier: Indicateur "Hors ligne" affiché
   ```

2. **Créer Données Hors Ligne**
   ```
   ✅ Ouvrir dossier patient
   ✅ Créer consultation:
     - Motif: "Suivi post-traitement"
     - Diagnostic: "Amélioration constatée"
   ✅ Sauvegarder
   ✅ Observer: "Enregistré localement - Sera synchronisé"
   
   ✅ Créer deuxième consultation:
     - Motif: "Renouvellement ordonnance"
   ✅ Sauvegarder
   ```

3. **Vérifier Queue Locale**
   ```
   ✅ Observer indicateur: "2 opérations en attente"
   ✅ Données visibles localement (Hive)
   ```

4. **Reconnexion**
   ```
   ✅ Désactiver mode avion
   ✅ Attendre reconnexion réseau
   ✅ Observer: "En ligne ✓"
   ```

5. **Synchronisation Automatique**
   ```
   ✅ Attendre max 35 secondes
   ✅ Observer: "Synchronisation en cours... 2 opérations"
   ✅ Observer: "Synchronisation terminée ✓"
   ✅ Vérifier: "0 opérations en attente"
   ```

**Vérification Backend:**

```bash
# Vérifier que les 2 consultations sont présentes
curl -X GET "http://localhost:3000/api/v1/medical-records/consultations" \
  -H "Authorization: Bearer DOCTOR_TOKEN"

# ✅ Doit contenir:
# - "Suivi post-traitement"
# - "Renouvellement ordonnance"
# - createdAt récent (timestamp de la sync, pas de création locale)
```

**Résultat Attendu:**
- ✅ Données créées hors ligne sauvegardées dans Hive
- ✅ Queue persistante contient 2 opérations
- ✅ Reconnexion détectée automatiquement
- ✅ Sync automatique < 35s après reconnexion
- ✅ Toutes les opérations synchronisées avec succès
- ✅ Queue vidée après sync
- ✅ Données présentes dans backend

---

### 🔄 TEST 6: Retry Automatique sur Erreur Serveur

**Objectif:** Vérifier le mécanisme de retry intelligent

**Étapes:**

1. **Simuler Erreur Serveur**
   ```bash
   # Arrêter temporairement le backend
   cd backend
   # Ctrl+C pour stopper le serveur
   ```

2. **Doctor Crée Donnée**
   ```
   ✅ Doctor app: Créer consultation
   ✅ Sauvegarder
   ✅ Observer: "Erreur de connexion - Sera synchronisé automatiquement"
   ✅ Vérifier queue: 1 opération en attente
   ```

3. **Redémarrer Backend**
   ```bash
   cd backend
   npm run start:dev
   # Attendre que le serveur soit prêt
   ```

4. **Attendre Retry**
   ```
   ✅ SyncService détecte serveur disponible
   ✅ Retry automatique après 30s
   ✅ Observer: "Synchronisation réussie ✓"
   ✅ Queue: 0 opérations
   ```

**Vérification:**
- ✅ Donnée créée pendant downtime présente dans backend
- ✅ Retry count incrémenté (max 3 tentatives)
- ✅ Pas de perte de données

---

### 🔁 TEST 7: Redémarrage Application → Persistence Queue

**Objectif:** Vérifier que la queue survit au redémarrage de l'app

**Étapes:**

1. **Créer Données en Queue**
   ```
   ✅ Doctor app hors ligne
   ✅ Créer 3 consultations
   ✅ Queue: 3 opérations en attente
   ```

2. **Fermer App Complètement**
   ```
   ✅ Forcer fermeture app (swipe up / kill process)
   ✅ Attendre 10 secondes
   ```

3. **Redémarrer App**
   ```
   ✅ Lancer Doctor app
   ✅ Se reconnecter si nécessaire
   ```

4. **Vérifier Queue Restaurée**
   ```
   ✅ Observer: "3 opérations en attente de synchronisation"
   ✅ Queue chargée depuis Hive
   ```

5. **Activer Réseau et Sync**
   ```
   ✅ Activer connexion
   ✅ Attendre sync automatique
   ✅ Vérifier: Toutes les opérations synchronisées
   ```

**Résultat Attendu:**
- ✅ Queue persistante dans Hive
- ✅ Queue restaurée au redémarrage
- ✅ Toutes les opérations présentes
- ✅ Sync réussie après redémarrage

---

### 📊 TEST 8: Types de Données - DateTime Consistency

**Objectif:** Vérifier que les types DateTime sont corrects partout

**Étapes:**

1. **Patient Crée Profil avec Date**
   ```
   ✅ Patient app: Entrer date naissance 15/05/1990
   ✅ Sauvegarder
   ```

2. **Vérifier Type Local**
   ```dart
   // Dans Patient app (debug)
   final patient = await repo.getPatientProfile(id);
   print(patient.dateOfBirth.runtimeType);
   // ✅ Doit afficher: DateTime
   
   // Calcul âge
   final age = DateTime.now().year - patient.dateOfBirth.year;
   print(age);
   // ✅ Doit afficher: 36
   ```

3. **Vérifier Backend**
   ```bash
   curl -X GET "http://localhost:3000/api/v1/patients/profile" \
     -H "Authorization: Bearer PATIENT_TOKEN"
   
   # ✅ dateOfBirth: "1990-05-15T00:00:00.000Z" (ISO 8601)
   ```

4. **Doctor App Lit Date**
   ```
   ✅ Doctor scan patient QR
   ✅ Afficher dossier
   ✅ Vérifier: "Date naissance: 15/05/1990 (36 ans)"
   ✅ Âge calculé correctement
   ```

**Vérification:**
- ✅ Patient app: DateTime natif
- ✅ Backend: DateTime ISO 8601 string
- ✅ Doctor app: DateTime parsé correctement
- ✅ Calculs d'âge corrects
- ✅ Pas d'erreurs de parsing

---

## 📈 RÉSULTATS ATTENDUS GLOBAUX

### Métriques de Performance

| Métrique | Objectif | Test |
|----------|---------|------|
| Sync local → backend | < 35s | TEST 1, 2, 3, 4 |
| Sync backend → app | < 1 min (avec refresh) | TEST 3, 4 |
| Retry après erreur | < 60s | TEST 6 |
| Restoration queue redémarrage | < 5s | TEST 7 |
| Mode offline fonctionnel | 100% | TEST 5 |

### Intégrité des Données

- ✅ Aucune perte de données lors sync
- ✅ Types cohérents (DateTime, etc.)
- ✅ Structures aplaties correctement (pas de ContactInfo imbriqué)
- ✅ EmergencyContact dans format correct
- ✅ chronicConditions ET chronicDiseases supportés

### Cas Limites

- ✅ Patient non vérifié → Doctor peut compléter
- ✅ Champs optionnels (insurance, healthScore) gérés
- ✅ Retry max 3 fois puis abandon (évite boucle infinie)
- ✅ Queue persistante même après crash app

---

## 🐛 TESTS DE RÉGRESSION

### Anciens Bugs Corrigés

#### Bug 1: QR Scanner Timeout
**Avant:** Timeout 15s → trop long  
**Après:** Timeout 5s + retry  
**Test:** Scanner QR → doit répondre < 5s

#### Bug 2: Patient Non Vérifié Bloqué
**Avant:** "Patient non vérifié" → blocage  
**Après:** Bouton "Compléter les informations"  
**Test:** Scan QR non vérifié → navigation vers détail possible

#### Bug 3: dateOfBirth String vs DateTime
**Avant:** Patient app String, Doctor app DateTime  
**Après:** Les deux DateTime  
**Test:** Calcul âge fonctionne dans les 2 apps

#### Bug 4: ContactInfo Imbriqué
**Avant:** Update échoue (backend n'attend pas objet imbriqué)  
**Après:** Champs plats  
**Test:** Patient update phone → sync backend réussie

---

## 📋 CHECKLIST VALIDATION FINALE

### Backend ✅
- [ ] Prisma migration exécutée sans erreurs
- [ ] Serveur démarre sans warnings
- [ ] Tous les endpoints répondent correctement
- [ ] MongoDB contient nouvelles colonnes
- [ ] Logs ne montrent pas d'erreurs

### Patient App ✅
- [ ] Build réussit (build_runner executé)
- [ ] Aucune erreur de compilation
- [ ] Login fonctionne
- [ ] Profile update fonctionne
- [ ] Sync automatique fonctionne
- [ ] Mode offline fonctionne
- [ ] dateOfBirth est DateTime (pas String)
- [ ] Pas de références à ContactInfo.phone
- [ ] Emergency contact champs directs

### Doctor App ✅
- [ ] Build réussit
- [ ] QR scan fonctionne (< 5s)
- [ ] Patient non vérifié → navigation OK
- [ ] Update patient fonctionne
- [ ] Nouveaux champs visibles (insurance, healthScore)
- [ ] Consultation creation fonctionne
- [ ] Sync queue fonctionne
- [ ] Offline mode fonctionne

### Synchronisation E2E ✅
- [ ] TEST 1 passé: Patient → Backend
- [ ] TEST 2 passé: Doctor scan & update
- [ ] TEST 3 passé: Doctor → Patient
- [ ] TEST 4 passé: Patient → Doctor
- [ ] TEST 5 passé: Offline → Online
- [ ] TEST 6 passé: Retry sur erreur
- [ ] TEST 7 passé: Queue persiste
- [ ] TEST 8 passé: DateTime consistent

---

## 🎯 CRITÈRES DE SUCCÈS

### Obligatoires (Bloquants) 🔴
- ✅ Toutes les données créées sont sauvegardées
- ✅ Sync bidirectionnelle fonctionne (Doctor ↔ Patient)
- ✅ Aucune perte de données
- ✅ Mode offline fonctionnel
- ✅ Types de données corrects (DateTime)

### Importants (Priorité Haute) 🟠
- ✅ Sync < 35 secondes
- ✅ Retry automatique fonctionne
- ✅ Queue persiste après redémarrage
- ✅ QR scan < 5 secondes

### Souhaitables (Améliorations) 🟡
- ✅ Indicateurs visuels de sync clairs
- ✅ Messages d'erreur explicites
- ✅ Logs debugging disponibles

---

## 📝 RAPPORT DE TESTS

### Template à Compléter

```markdown
# RAPPORT DE TESTS SYNCHRONISATION
Date: _______________
Testeur: _______________
Environnement: Dev / Staging / Production

## Résultats

| Test | Statut | Temps | Notes |
|------|--------|-------|-------|
| TEST 1: Patient → Backend | ⬜ PASS ⬜ FAIL | ___s | _____________ |
| TEST 2: Doctor Scan & Update | ⬜ PASS ⬜ FAIL | ___s | _____________ |
| TEST 3: Doctor → Patient | ⬜ PASS ⬜ FAIL | ___s | _____________ |
| TEST 4: Patient → Doctor | ⬜ PASS ⬜ FAIL | ___s | _____________ |
| TEST 5: Offline → Online | ⬜ PASS ⬜ FAIL | ___s | _____________ |
| TEST 6: Retry Error | ⬜ PASS ⬜ FAIL | ___s | _____________ |
| TEST 7: Queue Persistence | ⬜ PASS ⬜ FAIL | ___s | _____________ |
| TEST 8: DateTime Consistency | ⬜ PASS ⬜ FAIL | ___s | _____________ |

## Bugs Identifiés
1. ______________________________
2. ______________________________
3. ______________________________

## Recommandations
1. ______________________________
2. ______________________________

Signature: _______________
```

---

**Document Créé:** 15 Septembre 2026  
**Version:** 1.0  
**Statut:** ✅ Prêt pour Exécution
