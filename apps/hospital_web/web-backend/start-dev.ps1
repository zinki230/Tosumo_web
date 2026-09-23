# Script simple pour démarrer le backend web TOSUMO en mode développement

Write-Host "🚀 Démarrage TOSUMO Web Backend..." -ForegroundColor Green

# Vérifier Node.js
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js requis" -ForegroundColor Red
    exit 1
}

# Installer les dépendances si nécessaire
if (!(Test-Path "node_modules")) {
    Write-Host "📦 Installation des dépendances..." -ForegroundColor Yellow
    npm install
}

# Vérifier le fichier .env
if (!(Test-Path ".env")) {
    Write-Host "⚠️  Fichier .env non trouvé, copie depuis .env.example" -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
}

Write-Host "✅ Configuration OK" -ForegroundColor Green
Write-Host ""
Write-Host "🔧 Backend disponible sur : http://localhost:4000" -ForegroundColor Cyan  
Write-Host "📊 Health check : http://localhost:4000/health" -ForegroundColor Cyan
Write-Host "🔗 API Base : http://localhost:4000/api/v1" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔐 Identifiants de démonstration :" -ForegroundColor White
Write-Host "   📱 Téléphone : +237691234570" -ForegroundColor Yellow
Write-Host "   🔑 Mot de passe : WebAdmin@2024" -ForegroundColor Yellow
Write-Host ""

# Démarrer le serveur
npm run dev