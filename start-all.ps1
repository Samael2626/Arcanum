# start-all.ps1 - abre Windows Terminal con dos paneles: backend + flutter
# Uso: .\start-all.ps1  (desde D:\Proyectos\Arcanum)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$wt = (Get-Command wt.exe -ErrorAction SilentlyContinue).Source
if (-not $wt) {
    Write-Warning 'Windows Terminal no instalado. Abrir dos ventanas a mano y correr cada script.'
    exit 1
}

$be = Join-Path $root 'start-backend.ps1'
$fe = Join-Path $root 'start-flutter.ps1'

# Panel izquierdo = backend, derecho = flutter
$argList = @(
    '-F'
    '-d', $root
    'pwsh', '-NoExit', '-File', $be
    ';', 'split-pane', '-V', '-d', $root,
    'pwsh', '-NoExit', '-File', $fe
)
& $wt -ArgumentList $argList
