# TOSUMO — Application Web Hospitalière

Application web de gestion de suivi patient pour les centres hospitaliers TOSUMO.

## Fonctionnalité principale

**Suivi médecin → patient** : savoir en temps réel quel médecin suit quel patient,
avec historique des rendez-vous, statut, prochain RDV.

## Pages

| Route | Description |
|-------|-------------|
| `/login` | Connexion administrateur |
| `/` | Tableau de bord — stats globales + activité récente |
| `/suivi` | Table complète médecin ↔ patient (filtres, tri) |
| `/medecins` | Liste des médecins avec nb de patients |
| `/medecins/:id` | Profil médecin + liste de ses patients |
| `/patients` | Liste des patients avec médecin traitant |
| `/patients/:id` | Profil patient + médecins consultés + historique RDV |

## Lancer l'app

### Prérequis

- Node.js 18+
- Backend TOSUMO démarré sur `http://localhost:3000`

### Installation & démarrage

```bash
cd apps/hospital_web
npm install
npm run dev
```

Ouvrir : http://localhost:5173

### Compte de test

```
Téléphone : +237691000101
Mot de passe : Demo@1234
```

## Architecture

```
src/
├── services/
│   └── api.ts          # Client Axios + mappers + tous les appels API
├── components/
│   ├── Layout.tsx       # Sidebar + topbar
│   └── ui.tsx           # Composants partagés (Avatar, Badge, StatCard…)
├── pages/
│   ├── Login.tsx
│   ├── Dashboard.tsx
│   ├── TrackingPage.tsx  # Page suivi (fonctionnalité principale)
│   ├── DoctorsList.tsx
│   ├── DoctorDetail.tsx
│   ├── PatientsList.tsx
│   └── PatientDetail.tsx
└── App.tsx              # Router + RequireAuth guard
```

## Connexion au backend

Le proxy Vite redirige `/api/*` vers `http://localhost:3000`.
Pour changer l'URL backend, modifier `vite.config.ts` :

```ts
proxy: {
  '/api': {
    target: 'http://votre-backend:3000',
    changeOrigin: true,
  },
},
```

## Comment fonctionne le suivi

La relation médecin → patient est déduite des **rendez-vous** (table `Appointment`).
Pour chaque paire `(doctorId, patientId)` on calcule :
- le dernier rendez-vous
- le prochain rendez-vous planifié
- le nombre total de rendez-vous
- le statut du dernier rendez-vous

Le "médecin traitant" d'un patient est celui qui a le **plus de rendez-vous** avec lui.
