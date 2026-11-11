# TOSUMO — Console d’administration

Console web sécurisée pour superviser les applications patient et médecin ainsi que le portail web TOSUMO. Les données sont chargées depuis l’API partagée de production.

## Fonctionnalités

- Tableau de bord des patients, médecins, rendez-vous et validations en attente.
- Recherche de patients et médecins, profils et relations de suivi.
- Validation ou retrait de validation des dossiers médecins.
- Consultation et suspension/réactivation des comptes patients, médecins et administrateurs.
- Filtrage et export CSV des rendez-vous.
- Journal d’audit des actions administratives.
- Accès adapté au rôle d’administrateur système ou d’administrateur d’établissement.

## Pages

| Route | Description |
| --- | --- |
| `/login` | Connexion administrateur |
| `/` | Statistiques et activité récente |
| `/suivi` | Suivi médecin ↔ patient |
| `/medecins` | Répertoire des médecins |
| `/patients` | Répertoire des patients |
| `/comptes` | Gestion des comptes (admin système) |
| `/verifications` | Validation des médecins (admin système) |
| `/rendez-vous` | Consultations et export CSV (admin système) |
| `/journal` | Journal d’audit (admin système) |

## Développement

Prérequis : Node.js 18 ou plus récent.

```bash
npm install
npm run dev
```

Pour exécuter la vérification et le build de production :

```bash
npm run build
```

L’API locale est configurable avec `VITE_API_BASE_URL`. En production, la console utilise l’API Railway commune aux applications TOSUMO.

## Déploiement Vercel

Ce dépôt contient l’application à sa racine. Vercel utilise Vite, la commande `npm run build` et le dossier de sortie `dist`. Les routes de l’application web sont réécrites vers `index.html` et `/api/*` est redirigé vers le backend Railway.

Ne pas ajouter de mot de passe, jeton ou URI privée de base de données au dépôt.
