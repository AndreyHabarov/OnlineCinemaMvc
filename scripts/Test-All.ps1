[CmdletBinding()]
param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Push-Location $taskRoot
. (Join-Path $PSScriptRoot 'lib/Test-Process.ps1')
$taskDb = 'codex_suite_' + [Guid]::NewGuid().ToString('N')
$taskLogs = Join-Path $taskRoot "backups/$taskDb"
New-Item -ItemType Directory -Path $taskLogs -Force | Out-Null
$taskOldConnection = $env:ConnectionStrings__Default
$taskOldDatabase = $env:POSTGRES_DB
$taskCreated = $false
$taskProcess = $null
try {
    if (!$SkipBuild) {
        dotnet build OnlineCinemaMvc.sln --no-restore -warnaserror
        if ($LASTEXITCODE) { throw 'Сборка не прошла. При необходимости сначала выполните restore.' }
    }
    $taskConfig = docker compose config --format json | ConvertFrom-Json
    ./scripts/Test-DemoCalendarPolicy.ps1
    if ($LASTEXITCODE) { throw 'Не удалось прочитать Compose.' }
    $taskUser = [string]$taskConfig.services.db.environment.POSTGRES_USER
    $taskConnection = [Data.Common.DbConnectionStringBuilder]::new()
    $taskConnection['Host'] = '127.0.0.1'
    $taskConnection['Port'] = [int]$taskConfig.services.db.ports[0].published
    $taskConnection['Database'] = $taskDb
    $taskConnection['Username'] = $taskUser
    $taskConnection['Password'] = [string]$taskConfig.services.db.environment.POSTGRES_PASSWORD
    docker compose exec -T db createdb -U $taskUser $taskDb
    if ($LASTEXITCODE) { throw 'Не удалось создать отдельную тестовую БД.' }
    $taskCreated = $true
    $env:ConnectionStrings__Default = $taskConnection.ConnectionString
    # Только окружение процесса: CLI-скрипты обращаются к своей БД, .env не меняется.
    $env:POSTGRES_DB = $taskDb
    dotnet ef database update --no-build --project OnlineCinema.Domain --startup-project OnlineCinema.Mvc -- --environment Production *> (Join-Path $taskLogs 'migrations.log')
    if ($LASTEXITCODE) { throw 'Миграции с нуля не прошли.' }
    dotnet ef migrations has-pending-model-changes --no-build --project OnlineCinema.Domain --startup-project OnlineCinema.Mvc -- --environment Production *> (Join-Path $taskLogs 'model.log')
    if ($LASTEXITCODE) { throw 'Модель отличается от миграций.' }
    ./scripts/Update-DemoCatalog.ps1 *> (Join-Path $taskLogs 'catalog.log')
    ./scripts/Update-DemoCast.ps1 *> (Join-Path $taskLogs 'cast.log')
    ./scripts/Update-DemoPromotions.ps1 *> (Join-Path $taskLogs 'promotions.log')
    ./scripts/Update-DemoNews.ps1 *> (Join-Path $taskLogs 'news.log')
    ./scripts/Update-DemoSeats.ps1 *> (Join-Path $taskLogs 'seats.log')
    ./scripts/Update-DemoSchedule.ps1 *> (Join-Path $taskLogs 'schedule.log')
    'INSERT INTO "AspNetRoles" ("Name","NormalizedName","ConcurrencyStamp") VALUES (''admin'',''ADMIN'',''codex-suite'');' |
        docker compose exec -T db psql -X -q -U $taskUser -d $taskDb -v ON_ERROR_STOP=1
    if ($LASTEXITCODE) { throw 'Не удалось подготовить роль в тестовой БД.' }
    $taskSocket = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $taskSocket.Start()
    $taskPort = $taskSocket.LocalEndpoint.Port
    $taskSocket.Stop()
    $taskBase = "http://127.0.0.1:$taskPort"
    $taskProcess = Start-CinemaTestProcess -MvcPath (Join-Path $taskRoot 'OnlineCinema.Mvc') -BaseUrl $taskBase -Logs $taskLogs
    $taskReady = $false
    for ($taskAttempt = 0; $taskAttempt -lt 40; $taskAttempt++) {
        if ($taskProcess.HasExited) { throw 'Тестовый сайт завершился.' }
        try { $null = Invoke-WebRequest $taskBase -NoProxy -TimeoutSec 2; $taskReady = $true; break }
        catch { Start-Sleep -Milliseconds 250 }
    }
    if (!$taskReady) { throw 'Тестовый сайт недоступен.' }
    foreach ($taskTest in @('Test-Catalog','Test-Cast','Test-DemoPromotions','Test-DemoNews','Test-Authentication','Test-Sessions','Test-Admin','Test-TicketPurchases')) {
        & (Join-Path $PSScriptRoot "$taskTest.ps1") -BaseUrl $taskBase
    }
    ./scripts/Test-PublicPages.ps1
    ./scripts/Test-ErrorHandling.ps1
    ./scripts/Test-Migrations.ps1
    Write-Host 'Все проверки прошли на отдельных тестовых БД. Рабочие пользователи и билеты не изменялись.'
} finally {
    try {
        if ($taskProcess -and !$taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id; $taskProcess.WaitForExit() }
    } finally {
        $env:ConnectionStrings__Default = $taskOldConnection
        $env:POSTGRES_DB = $taskOldDatabase
        try {
            if ($taskCreated -and $taskDb -match '^codex_suite_[a-f0-9]{32}$') {
                docker compose exec -T db dropdb -U $taskUser --force $taskDb
                if ($LASTEXITCODE) { Write-Warning "Не удалось удалить свою БД $taskDb." }
            }
        } finally { Pop-Location }
    }
}
