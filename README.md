# TOSUMO - Application Web Hospitalière

## 🏥 Description

TOSUMO est une plateforme de gestion hospitalière moderne permettant aux centres de santé de gérer leurs médecins, patients et rendez-vous avec une architecture multi-tenants sécurisée.

## 🚀 Déploiement

### Architecture
- **Frontend** : React + TypeScript + Tailwind CSS
- **Déploiement** : Vercel
- **Backend** : Node.js + Express (Railway)
- **Base de données** : PostgreSQL (Railway)

### Configuration Vercel

1. **Connectez votre repo GitHub à Vercel**
2. **Configurez les variables d'environnement sur Vercel** :
   ```
   VITE_API_BASE_URL=https://tosumo-production.up.railway.app/api/v1
   ```
3. **Déployez automatiquement**

## 📱 Compatibilité

Cette application web partage la même base de données et API que les applications mobiles (médecin et patient), garantissant une synchronisation parfaite des données.

## ✨ Fonctionnalités

- 🏥 Multi-tenancy : Isolation des données par centre hospitalier
- 👨‍⚕️ Gestion des médecins
- 👥 Gestion des patients  
- 📅 Suivi des rendez-vous
- 📊 Tableau de bord avec statistiques
- 🔐 Authentification sécurisée JWT
- 📱 Interface responsive

## 🛠️ Installation locale

```bash
cd apps/hospital_web
npm install
npm run dev
```

## 🌐 URL de production

L'application sera disponible sur votre domaine Vercel après déploiement.

---

**TOSUMO** - L'essentiel de votre santé au creux de vos mains