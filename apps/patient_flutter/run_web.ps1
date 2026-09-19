# Script pour lancer l'application Flutter patient en mode web
Write-Host "🏥 Lancement de l'application TOSUMO Patient"
Write-Host "Port: 8081"
Write-Host "URL: http://localhost:8081"
Write-Host ""

# Vérifier les dépendances
Write-Host "📦 Installation des dépendances..."
flutter pub get

Write-Host ""
Write-Host "🚀 Démarrage de l'application web..."
Write-Host "Appuyez sur Ctrl+C pour arrêter"
Write-Host ""

flutter run -d web-server --web-port=8081 --web-hostname=localhost