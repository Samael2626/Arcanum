# start-flutter.ps1 - arranca Flutter con ruta completa
# Uso: .\start-flutter.ps1  (desde D:\Proyectos\Arcanum)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$appDir = Join-Path $root 'arcanum_app'
$flutter = 'D:\flutter\bin\flutter.bat'

if (-not (Test-Path $flutter)) {
    Write-Error ("Flutter no encontrado en " + $flutter)
    exit 1
}

Set-Location $appDir
$msg = "[flutter] " + $appDir
Write-Host $msg -ForegroundColor Cyan
& $flutter run -d chrome
