# Architecture du portail hospitalier TOSUMO

## Applications et données

Le portail web (Vercel), l’application patient et l’application médecin utilisent la même API de production : `https://tosumo-production.up.railway.app/api/v1`. Les identités et dossiers sont donc gérés par un backend et une base de données partagés. Les accès restent soumis aux rôles et autorisations de chaque compte.

```text
Portail hospitalier ─┐
Application patient ─┼─> API TOSUMO (Railway) ─> base de données partagée
Application médecin ┘
```

## Développement local

- Frontend : Vite, démarré depuis `apps/hospital_web` avec `npm run dev`.
- API : backend partagé du dépôt, démarré depuis `backend`.
- URL API locale : `http://localhost:3000/api/v1`.
- URL API de production : `https://tosumo-production.up.railway.app/api/v1`.

La variable `VITE_API_BASE_URL` configure l’URL utilisée par le frontend. Le fichier `.env.production` contient l’URL de production partagée.

## Parcours principaux

- Le personnel autorisé consulte les statistiques, patients, médecins, rendez-vous et institutions selon ses permissions.
- La création d’un médecin depuis le portail crée son compte et son profil dans l’API partagée. Le médecin se connecte ensuite à l’application médecin avec le numéro enregistré et complète les informations de son profil.
- Le médecin peut rechercher/scanner un patient et compléter son dossier. Le statut médical vérifié est distinct de la simple reconnaissance du QR code.

Pour les paramètres de build et le déploiement Vercel, voir [DEPLOYMENT.md](./DEPLOYMENT.md). Ne jamais inscrire de secrets ou d’identifiants de base de données dans la documentation versionnée.
