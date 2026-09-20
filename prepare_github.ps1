# Script pour préparer le déploiement GitHub + Vercel
Write-Host "🚀 Préparation du projet TOSUMO pour GitHub et Vercel"
Write-Host ""

# Vérification des fichiers critiques
$files = @(
    "apps/hospital_web/package.json",
    "apps/hospital_web/vercel.json", 
    "apps/hospital_web/.env.production",
    "apps/hospital_web/src/services/api.ts"
)

Write-Host "🔍 Vérification des fichiers..."
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "✅ $file"
    } else {
        Write-Host "❌ $file manquant"
    }
}

Write-Host ""
Write-Host "📋 Étapes suivantes:"
Write-Host "1. Commitez tous les changements"
Write-Host "2. Changez l'origine vers votre repo:"
Write-Host "   git remote set-url origin https://github.com/zinki230/tosumo_web.git"
Write-Host "3. Poussez vers GitHub:"
Write-Host "   git push -u origin main"
Write-Host "4. Connectez le repo à Vercel"
Write-Host "5. Configurez VITE_API_BASE_URL sur Vercel"
Write-Host ""
Write-Host "🎯 Backend Railway: https://tosumo-production.up.railway.app/"
Write-Host "🎯 Repo GitHub: https://github.com/zinki230/tosumo_web"