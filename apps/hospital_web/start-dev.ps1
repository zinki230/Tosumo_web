# Script PowerShell pour démarrer TOSUMO Hospital Web en mode développement
# Démarre le backend web dédié et le frontend en parallèle

Write-Host "🚀 TOSUMO Hospital Web - Mode Développement" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

# Vérifier si Node.js est installé
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js n'est pas installé" -ForegroundColor Red
    exit 1
}

# Vérifier si npm est installé  
if (!(Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "❌ npm n'est pas installé" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Node.js et npm détectés" -ForegroundColor Green

# Vérifier la structure des dossiers
if (!(Test-Path "web-backend")) {
    Write-Host "❌ Dossier web-backend non trouvé" -ForegroundColor Red
    Write-Host "   Assurez-vous d'exécuter ce script depuis apps/hospital_web/" -ForegroundColor Yellow
    exit 1
}

if (!(Test-Path "src")) {
    Write-Host "❌ Dossier src du frontend non trouvé" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Structure des dossiers OK" -ForegroundColor Green

# Installer les dépendances si nécessaire
Write-Host "🔧 Vérification des dépendances..." -ForegroundColor Yellow

if (!(Test-Path "web-backend/node_modules")) {
    Write-Host "📦 Installation des dépendances backend..." -ForegroundColor Yellow
    Set-Location web-backend
    npm install
    Set-Location ..
}

if (!(Test-Path "node_modules")) {
    Write-Host "📦 Installation des dépendances frontend..." -ForegroundColor Yellow
    npm install
}

Write-Host "✅ Dépendances installées" -ForegroundColor Green

# Fonction pour démarrer le backend
$backendJob = Start-Job -ScriptBlock {
    Set-Location $args[0]
    Set-Location web-backend
    Write-Host "🔧 Démarrage du backend web dédié sur http://localhost:4000" -ForegroundColor Cyan
    npm run dev
} -ArgumentList (Get-Location)

# Attendre un peu que le backend démarre
Start-Sleep -Seconds 3

# Fonction pour démarrer le frontend
$frontendJob = Start-Job -ScriptBlock {
    Set-Location $args[0]
    Write-Host "🌐 Démarrage du frontend sur http://localhost:5173" -ForegroundColor Cyan
    npm run dev
} -ArgumentList (Get-Location)

Write-Host "🎯 Applications démarrées !" -ForegroundColor Green
Write-Host ""
Write-Host "📍 URLs d'accès :" -ForegroundColor White
Write-Host "   🌐 Frontend : http://localhost:5173" -ForegroundColor Cyan
Write-Host "   🔧 Backend  : http://localhost:4000" -ForegroundColor Cyan
Write-Host "   📊 API Health: http://localhost:4000/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔐 Identifiants de démonstration :" -ForegroundColor White
Write-Host "   📱 Téléphone : +237691234570" -ForegroundColor Yellow
Write-Host "   🔑 Mot de passe : WebAdmin@2024" -ForegroundColor Yellow
Write-Host "   👤 Rôle : institution_admin" -ForegroundColor Yellow
Write-Host ""
Write-Host "⏹️  Appuyez sur Ctrl+C pour arrêter les services" -ForegroundColor Red

# Attendre l'interruption de l'utilisateur
try {
    while ($true) {
        Start-Sleep -Seconds 1
        
        # Vérifier si les jobs sont encore actifs
        if ($backendJob.State -eq "Failed" -or $frontendJob.State -eq "Failed") {
            Write-Host "❌ Un des services a échoué" -ForegroundColor Red
            break
        }
    }
} finally {
    Write-Host "🔄 Arrêt des services..." -ForegroundColor Yellow
    
    # Arrêter les jobs
    if ($backendJob) {
        Stop-Job $backendJob -ErrorAction SilentlyContinue
        Remove-Job $backendJob -ErrorAction SilentlyContinue
    }
    
    if ($frontendJob) {
        Stop-Job $frontendJob -ErrorAction SilentlyContinue
        Remove-Job $frontendJob -ErrorAction SilentlyContinue
    }
    
    Write-Host "✅ Services arrêtés" -ForegroundColor Green
}