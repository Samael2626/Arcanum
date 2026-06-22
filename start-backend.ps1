# start-backend.ps1 - arranca FastAPI en :8000 matando instancia previa
# Uso: .\start-backend.ps1  (desde D:\Proyectos\Arcanum)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$apiDir = Join-Path $root 'arcanum-api'
$venvPy = Join-Path $apiDir 'venv\Scripts\python.exe'

if (-not (Test-Path $venvPy)) {
    Write-Error ("No existe " + $venvPy + " - recrear venv en arcanum-api")
    exit 1
}

# Libera puerto 8000 si quedo ocupado
Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

Set-Location $apiDir
$msg = "[backend] " + $apiDir
Write-Host $msg -ForegroundColor Cyan
& $venvPy -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
