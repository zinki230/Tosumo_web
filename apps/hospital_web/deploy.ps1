# Script de déploiement TOSUMO sur Vercel
Write-Host "🚀 Déploiement TOSUMO Hospital Web sur Vercel"
Write-Host ""

# Vérifier les variables d'environnement
if (-not $env:VITE_API_BASE_URL) {
    Write-Host "⚠️  VITE_API_BASE_URL non définie"
    Write-Host "Exemple: $env:VITE_API_BASE_URL = 'https://tosumo-api.railway.app/api/v1'"
    exit 1
}

Write-Host "🔧 Configuration:"
Write-Host "API URL: $env:VITE_API_BASE_URL"
Write-Host ""

# Build de production
Write-Host "📦 Construction de l'application..."
npm run build

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build réussi!"
    Write-Host ""
    Write-Host "🌐 Prêt pour déploiement Vercel:"
    Write-Host "1. Connectez votre repo GitHub à Vercel"
    Write-Host "2. Configurez les variables d'environnement sur Vercel:"
    Write-Host "   VITE_API_BASE_URL = $env:VITE_API_BASE_URL"
    Write-Host "3. Déployez automatiquement sur push"
    Write-Host ""
    Write-Host "🔗 Après déploiement, testez sur votre domaine Vercel"
} else {
    Write-Host "❌ Échec du build"
    exit 1
}