param(
    [Parameter(Mandatory)]
    [string]$ContentPath,

    [Parameter(Mandatory)]
    [string]$ManifestPath,

    [string]$ApprovedBy = 'human:samuel'
)

$ErrorActionPreference = 'Stop'

$marketingRoot = Split-Path -Parent $PSScriptRoot
$composePath = Join-Path $marketingRoot 'compose.yml'
$envPath = Join-Path $marketingRoot '.env'
$migrationPath = Join-Path $marketingRoot 'db/migrations'

if (-not (Test-Path -LiteralPath $envPath)) {
    throw 'Falta marketing-automation/.env'
}

$resolvedContentPath = (Resolve-Path -LiteralPath $ContentPath).Path
$resolvedManifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path
$content = Get-Content -LiteralPath $resolvedContentPath -Raw -Encoding UTF8 | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $resolvedManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ($content.status -ne 'approved') {
    throw 'El copy debe estar approved antes de registrar el render'
}
if ($content.external_key -ne $manifest.external_key) {
    throw 'El manifiesto no corresponde al contenido aprobado'
}
if (-not $manifest.files -or $manifest.files.Count -ne $content.slides.Count) {
    throw 'El manifiesto no contiene todos los archivos del carrusel'
}

$postgresContainer = (& docker compose --env-file $envPath -f $composePath ps -q postgres).Trim()
if (-not $postgresContainer) {
    throw 'PostgreSQL de marketing no esta activo'
}

$dbUser = (& docker exec $postgresContainer printenv POSTGRES_USER).Trim()
$dbName = (& docker exec $postgresContainer printenv POSTGRES_DB).Trim()

Get-ChildItem -LiteralPath $migrationPath -Filter '*.sql' |
    Sort-Object Name |
    ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 |
            & docker exec -i $postgresContainer psql `
                -v ON_ERROR_STOP=1 -U $dbUser -d $dbName
        if ($LASTEXITCODE -ne 0) {
            throw "Fallo la migracion $($_.Name)"
        }
    }

$contentJson = $content | ConvertTo-Json -Depth 20 -Compress
$manifestJson = $manifest | ConvertTo-Json -Depth 20 -Compress
$contentBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($contentJson))
$manifestBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($manifestJson))
$approvedByBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ApprovedBy))

$updateSql = @"
WITH payload AS (
    SELECT
        convert_from(decode('$contentBase64', 'base64'), 'UTF8')::jsonb AS content,
        convert_from(decode('$manifestBase64', 'base64'), 'UTF8')::jsonb AS manifest,
        convert_from(decode('$approvedByBase64', 'base64'), 'UTF8') AS approved_by
)
UPDATE marketing.content_items AS item
SET generated_content = jsonb_build_object(
        'draft', payload.content->'approved_copy',
        'visual', payload.content
    ),
    status = 'rendered',
    approved_at = COALESCE(item.approved_at, now()),
    approved_by = payload.approved_by,
    rendered_at = now(),
    rendered_assets = payload.manifest,
    last_error = NULL,
    updated_at = now()
FROM payload
WHERE item.external_key = payload.content->>'external_key'
RETURNING item.external_key, item.status::text, item.approved_by,
          item.approved_at, item.rendered_at,
          jsonb_array_length(item.rendered_assets->'files') AS rendered_files;
"@

$result = $updateSql | & docker exec -i $postgresContainer psql `
    -v ON_ERROR_STOP=1 -U $dbUser -d $dbName
if ($LASTEXITCODE -ne 0) {
    throw 'Fallo el registro del carrusel renderizado'
}
if (-not ($result -match 'UPDATE 1')) {
    throw "No se encontro el contenido $($content.external_key)"
}

$result
