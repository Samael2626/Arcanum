$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $projectDir ".env.example"
$targetPath = Join-Path $projectDir ".env"

if (Test-Path -LiteralPath $targetPath) {
    throw ".env ya existe. No se sobrescribe."
}

function New-Secret([int]$byteCount) {
    $bytes = [byte[]]::new($byteCount)
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }
    return ([BitConverter]::ToString($bytes) -replace "-", "").ToLowerInvariant()
}

$content = Get-Content -Raw -LiteralPath $templatePath
$content = $content.Replace("GENERATE_WITH_SETUP_SCRIPT", (New-Secret 32))
$firstSecretEnd = $content.IndexOf("`nN8N_ENCRYPTION_KEY=")
$postgresLine = $content.Substring(0, $firstSecretEnd)
$postgresSecret = ($postgresLine -split "POSTGRES_PASSWORD=")[1]
$content = $content.Replace("N8N_ENCRYPTION_KEY=$postgresSecret", "N8N_ENCRYPTION_KEY=$(New-Secret 32)")

[IO.File]::WriteAllText(
    $targetPath,
    $content,
    [Text.UTF8Encoding]::new($false)
)
Write-Output ".env creado. Secretos no mostrados."
