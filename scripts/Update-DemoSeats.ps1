[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOldEncoding = $OutputEncoding
Push-Location $taskRoot
try {
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $taskCompose = (docker compose config --format json | Out-String | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось прочитать Docker Compose.' }
    $taskUser = [string]$taskCompose.services.db.environment.POSTGRES_USER
    $taskDatabase = [string]$taskCompose.services.db.environment.POSTGRES_DB
    New-Item -ItemType Directory -Path backups -Force | Out-Null
    $taskBackup = 'cinemadb-before-seats-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.dump'
    docker compose exec -T db pg_dump -U $taskUser -d $taskDatabase -Fc --file="/tmp/$taskBackup"
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось создать резервную копию.' }
    docker compose cp "db:/tmp/$taskBackup" (Join-Path $taskRoot "backups/$taskBackup")
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось сохранить резервную копию.' }
    Get-Content scripts/sql/update-demo-seats.sql -Raw -Encoding utf8 | docker compose exec -T -e PGCLIENTENCODING=UTF8 db psql -X -U $taskUser -d $taskDatabase -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) { throw 'Подготовка мест отменена.' }
} finally { $OutputEncoding=$taskOldEncoding; Pop-Location }
