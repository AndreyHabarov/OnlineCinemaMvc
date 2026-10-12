[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
. (Join-Path $PSScriptRoot 'lib/Docker-TestEnvironment.ps1')
$taskScope = $null
try {
    $taskScope = New-CinemaDockerTestEnvironment
    $env:DEMO_ADMIN_ENABLED = 'true'
    $env:DEMO_ADMIN_PASSWORD = 'A1a' + [Guid]::NewGuid().ToString('N')
    docker compose up -d --wait *> (Join-Path $taskScope.Logs 'demo.log')
    if ($LASTEXITCODE) { throw 'Демоокружение не подготовлено.' }
    ./scripts/Backup-Docker.ps1
    $env:CINEMA_MODE = 'production'
    $env:DEMO_ADMIN_ENABLED = 'false'
    $env:DEMO_ADMIN_PASSWORD = $null
    docker compose up -d --wait --force-recreate initialize web *> (Join-Path $taskScope.Logs 'expected-production-refusal.log')
    if (!$LASTEXITCODE) { throw 'Production разрешил БД с демоадминистратором.' }
    $taskWeb = docker compose ps --all --format json web | ConvertFrom-Json
    if ($taskWeb.State -eq 'running') { throw 'Production-сайт неожиданно работает.' }
    # Отдельная пустая production-БД внутри disposable проекта.
    docker compose exec -T db createdb -U cinema production_check
    if ($LASTEXITCODE) { throw 'Тестовая production-БД не создана.' }
    $env:POSTGRES_DB = 'production_check'
    docker compose up -d --wait --force-recreate initialize web *> (Join-Path $taskScope.Logs 'production.log')
    if ($LASTEXITCODE) { throw 'Production на отдельной БД не запустился.' }
    $taskCount = 'SELECT (SELECT count(*) FROM "Movies"),(SELECT count(*) FROM "AspNetUsers"),(SELECT count(*) FROM "AspNetRoles");' |
        docker compose exec -T db psql -X -At -U cinema -d production_check -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -or $taskCount.Trim() -ne '0|0|1') { throw 'Production загрузил демоданные.' }
    $null = Invoke-WebRequest "$($taskScope.BaseUrl)/health" -NoProxy -TimeoutSec 15
    Write-Host 'Резервные копии и production: запрет демоадминистратора, отдельная БД без демоданных/учётных записей, readiness проверены.'
} finally {
    try { if ($taskScope) { Remove-CinemaDockerTestEnvironment $taskScope } }
    finally { Pop-Location }
}
