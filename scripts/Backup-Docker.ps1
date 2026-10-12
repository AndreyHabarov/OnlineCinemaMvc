[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Push-Location $taskRoot
try {
    $taskConfig = docker compose config --format json | ConvertFrom-Json
    if ($LASTEXITCODE) { throw 'Compose недоступен.' }
    $taskUser = [string]$taskConfig.services.db.environment.POSTGRES_USER
    $taskDb = [string]$taskConfig.services.db.environment.POSTGRES_DB
    $taskStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $taskBackup = Join-Path $taskRoot "backups/docker-$taskStamp"
    New-Item -ItemType Directory -Path $taskBackup -Force | Out-Null
    if ([Environment]::OSVersion.Platform -eq 'Unix') {
        [IO.File]::SetUnixFileMode($taskBackup, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)
    }
    docker compose exec -T db pg_dump -U $taskUser -d $taskDb -Fc --no-owner --no-privileges --file="/tmp/cinema-$taskStamp.dump"
    if ($LASTEXITCODE) { throw 'Дамп не создан.' }
    docker compose cp "db:/tmp/cinema-$taskStamp.dump" (Join-Path $taskBackup 'database.dump') *> $null
    if ($LASTEXITCODE) { throw 'Дамп не скопирован.' }
    $taskArchive = @(docker compose exec -T db pg_restore --list "/tmp/cinema-$taskStamp.dump")
    if ($LASTEXITCODE -or $taskArchive.Count -lt 20) { throw 'Архив БД не прошёл проверку.' }
    foreach ($taskVolumeKey in @('promotion_uploads','protection_keys')) {
        $taskVolume = [string]$taskConfig.volumes.PSObject.Properties[$taskVolumeKey].Value.name
        if (!$taskVolume) { throw 'Не найден volume файлов.' }
        docker run --rm --entrypoint tar --mount "type=volume,source=$taskVolume,target=/data,readonly" --mount "type=bind,source=$taskBackup,target=/backup" postgres:17-alpine -czf "/backup/$taskVolumeKey.tar.gz" -C /data .
        if ($LASTEXITCODE) { throw 'Файлы volume не сохранены.' }
    }
    Write-Host "Приватная копия БД/изображений/ключей сохранена: $taskBackup"
} finally { Pop-Location }
