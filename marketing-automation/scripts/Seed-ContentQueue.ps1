param(
    [switch]$RequeueExisting
)

$ErrorActionPreference = 'Stop'

$marketingRoot = Split-Path -Parent $PSScriptRoot
$composePath = Join-Path $marketingRoot 'compose.yml'
$envPath = Join-Path $marketingRoot '.env'
$seedPath = Join-Path $marketingRoot 'seeds/content-briefs.json'
$migrationPath = Join-Path $marketingRoot 'db/migrations'

if (-not (Test-Path -LiteralPath $envPath)) {
    throw 'Falta marketing-automation/.env'
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

$seedJson = Get-Content -LiteralPath $seedPath -Raw -Encoding UTF8
$seedBytes = [Text.Encoding]::UTF8.GetBytes($seedJson)
$seedBase64 = [Convert]::ToBase64String($seedBytes)
$requeueSql = if ($RequeueExisting) { "'queued'::marketing.content_status" } else { 'marketing.content_items.status' }

$seedSql = @"
WITH payload AS (
    SELECT convert_from(decode('$seedBase64', 'base64'), 'UTF8')::jsonb AS data
), briefs AS (
    SELECT item.*
    FROM payload,
         jsonb_to_recordset(payload.data) AS item(
             external_key text,
             pillar text,
             objective text,
             audience text,
             angle text,
             primary_format text,
             derived_formats jsonb,
             premise text,
             facts jsonb,
             sources jsonb,
             warnings jsonb,
             asset jsonb
         )
)
INSERT INTO marketing.content_items (
    external_key,
    pillar,
    objective,
    audience,
    angle,
    primary_format,
    derived_formats,
    premise,
    facts,
    sources,
    warnings,
    asset,
    status
)
SELECT
    external_key,
    pillar,
    objective,
    audience,
    angle,
    primary_format,
    derived_formats,
    premise,
    facts,
    sources,
    warnings,
    asset,
    'queued'::marketing.content_status
FROM briefs
ON CONFLICT (external_key) DO UPDATE
SET pillar = EXCLUDED.pillar,
    objective = EXCLUDED.objective,
    audience = EXCLUDED.audience,
    angle = EXCLUDED.angle,
    primary_format = EXCLUDED.primary_format,
    derived_formats = EXCLUDED.derived_formats,
    premise = EXCLUDED.premise,
    facts = EXCLUDED.facts,
    sources = EXCLUDED.sources,
    warnings = EXCLUDED.warnings,
    asset = EXCLUDED.asset,
    status = $requeueSql,
    updated_at = now();

SELECT status::text, count(*)
FROM marketing.content_items
GROUP BY status
ORDER BY status::text;
"@

$seedSql | & docker exec -i $postgresContainer psql `
    -v ON_ERROR_STOP=1 -U $dbUser -d $dbName
if ($LASTEXITCODE -ne 0) {
    throw 'Fallo la carga de briefs'
}
