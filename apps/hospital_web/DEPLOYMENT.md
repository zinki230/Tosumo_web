# Déploiement du portail hospitalier

Le portail hospitalier, l’application patient et l’application médecin utilisent la même API et la même base de données. Cela garantit que les comptes, les dossiers patients, les médecins et le suivi sont cohérents entre les trois applications.

## Vercel

- Dépôt : `zinki230/tosumo_web`
- Répertoire racine : `apps/hospital_web`
- Framework : Vite
- Variable de production : `VITE_API_BASE_URL=https://tosumo-production.up.railway.app/api/v1`
- Commande de build : `npm run build`
- Répertoire de sortie : `dist`

Le fichier `.env.production` contient déjà l’URL de l’API partagée. Après chaque push sur la branche principale, Vercel doit reconstruire le portail. Vérifier dans les paramètres du projet Vercel que la variable `VITE_API_BASE_URL`, si elle est définie dans le tableau de bord, utilise la même URL.

## API partagée

L’API de production est hébergée sur Railway à `https://tosumo-production.up.railway.app`. Elle sert les applications web et mobiles avec les mêmes comptes et données. Les parcours du portail utilisent notamment les statistiques administrateur, les médecins, les patients, les rendez-vous et les institutions. La création d’un médecin depuis le portail crée son compte et son profil dans cette API ; il peut ensuite se connecter dans l’application médecin avec le numéro enregistré et compléter son profil.

Ne pas ajouter de mot de passe, jeton ou URI privée de base de données aux fichiers du dépôt. Configurer les secrets uniquement dans les paramètres sécurisés du service qui en a besoin.
