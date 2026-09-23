#!/bin/bash

# TOSUMO Web Backend - Railway Deployment Script
# Ce script prépare et guide le déploiement sur Railway

set -e

echo "🚀 TOSUMO Web Backend - Railway Deployment"
echo "=========================================="

# Vérifier les prérequis
echo "🔍 Checking prerequisites..."

if ! command -v git &> /dev/null; then
    echo "❌ Git is required but not installed"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required but not installed"
    exit 1
fi

echo "✅ Prerequisites OK"

# Vérifier la structure du projet
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found. Run this script from web-backend directory"
    exit 1
fi

if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found"
    exit 1
fi

echo "✅ Project structure OK"

# Vérifier les variables d'environnement
echo "🔧 Environment variables to set in Railway:"
echo "   NODE_ENV=production"
echo "   PORT=4000"
echo "   MONGODB_URI=mongodb+srv://russeltsague3_db_user:bPRLbVhxwQpfF7W1@cluster0.5id4izm.mongodb.net/tosumo"
echo "   JWT_ACCESS_SECRET=<generate-strong-32-char-secret>"
echo "   JWT_REFRESH_SECRET=<generate-strong-32-char-secret>"
echo "   CORS_ORIGINS=https://tosumo-web-hospital-web.vercel.app"
echo "   BCRYPT_ROUNDS=12"
echo "   API_RATE_LIMIT=100"
echo "   DEMO_MODE=true"
echo "   DEMO_ADMIN_PHONE=+237691234570"
echo "   DEMO_ADMIN_EMAIL=admin@hospital-web.tosumo.cm"
echo "   DEMO_ADMIN_PASSWORD=WebAdmin@2024"

echo ""
echo "📋 Railway Deployment Steps:"
echo "1. Create new Railway project: https://railway.app/new"
echo "2. Connect your GitHub repository"
echo "3. Set root directory to: apps/hospital_web/web-backend"
echo "4. Add all environment variables listed above"
echo "5. Deploy!"

echo ""
echo "🔗 Useful links:"
echo "   Railway Dashboard: https://railway.app/dashboard"
echo "   Railway Docs: https://docs.railway.app/"
echo "   MongoDB Atlas: https://cloud.mongodb.com/"

echo ""
echo "✅ Deployment preparation complete!"
echo "   Your backend will be available at: https://your-app.railway.app"
echo "   Health check: https://your-app.railway.app/health"
echo "   API Base: https://your-app.railway.app/api/v1"

# Générer des secrets JWT pour copier-coller
echo ""
echo "🔐 JWT Secrets (copy these for Railway env vars):"
echo "   JWT_ACCESS_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")"
echo "   JWT_REFRESH_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")"