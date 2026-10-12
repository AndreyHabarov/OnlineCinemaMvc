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
    docker compose exec -T db pg_restore --list "/tmp/$taskBackup" *> $null
    if ($LASTEXITCODE) { throw 'Резервная копия не прошла проверку.' }
    $taskHalls = @(Get-Content data/demo-halls.json -Raw -Encoding utf8 | ConvertFrom-Json)
    if ($taskHalls.Count -ne 5) { throw 'Требуется каталог из пяти залов.' }
    foreach ($taskHall in $taskHalls) {
        if ($taskHall.rows -lt 1 -or $taskHall.rows -gt 30 -or $taskHall.seatsPerRow -lt 1 -or $taskHall.seatsPerRow -gt 40 -or !(Test-Path (Join-Path 'OnlineCinema.Mvc/wwwroot' $taskHall.picturePath.TrimStart('/')))) { throw 'Некорректные данные или отсутствующая иллюстрация зала.' }
    }
    $taskHallJson = ConvertTo-Json -InputObject $taskHalls -Depth 5 -Compress
    $taskSql = (Get-Content scripts/sql/update-demo-seats.sql -Raw -Encoding utf8).Replace('__HALLS_JSON__', $taskHallJson.Replace("'", "''"))
    $taskSql | docker compose exec -T -e PGCLIENTENCODING=UTF8 db psql -X -U $taskUser -d $taskDatabase -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) { throw 'Подготовка мест отменена.' }
} finally { $OutputEncoding=$taskOldEncoding; Pop-Location }
