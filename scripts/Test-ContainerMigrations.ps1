[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
. (Join-Path $PSScriptRoot 'lib/Docker-TestEnvironment.ps1')
$taskScope = $null
$taskProcesses = @()
try {
    $taskScope = New-CinemaDockerTestEnvironment
    docker compose up -d --wait db *> (Join-Path $taskScope.Logs 'db.log')
    if ($LASTEXITCODE) { throw 'Тестовый PostgreSQL не запущен.' }
    # Два процесса мигрируют одну изначально пустую БД одновременно.
    foreach ($taskIndex in 0..1) {
        $taskStart = @{
            FilePath = 'docker'; ArgumentList = @('compose','run','--rm','-T','initialize')
            PassThru = $true
            RedirectStandardOutput = (Join-Path $taskScope.Logs "initialize-$taskIndex.log")
            RedirectStandardError = (Join-Path $taskScope.Logs "initialize-$taskIndex-error.log")
        }
        if ($IsWindows) { $taskStart.WindowStyle = 'Hidden' }
        $taskProcesses += Start-Process @taskStart
    }
    foreach ($taskProcess in $taskProcesses) {
        $taskProcess.WaitForExit()
        if ($taskProcess.ExitCode) { throw 'Конкурирующий процесс миграций завершился с ошибкой.' }
    }
    $taskCount = 'SELECT count(*) FROM "__EFMigrationsHistory";' | docker compose exec -T db psql -X -At -U cinema -d demo_check -v ON_ERROR_STOP=1
    $taskExpected = @(Get-ChildItem OnlineCinema.Domain/Migrations/*_*.cs | Where-Object Name -NotLike '*.Designer.cs').Count
    if ($LASTEXITCODE -or [int]$taskCount -ne $taskExpected) { throw 'История миграций неполная или содержит дубли.' }
    docker compose up -d --wait web *> (Join-Path $taskScope.Logs 'web.log')
    if ($LASTEXITCODE) { throw 'Сайт не дождался инициализации.' }
    $taskResponse = Invoke-WebRequest $taskScope.BaseUrl -NoProxy -TimeoutSec 10
    if ($taskResponse.StatusCode -ne 200) { throw 'Пустая схема не открывается.' }
    docker compose run --rm -T initialize *> (Join-Path $taskScope.Logs 'repeat.log')
    if ($LASTEXITCODE) { throw 'Повторная миграция не прошла.' }
    $taskFailureFile = Join-Path $taskScope.Logs 'failed-init.yml'
    [IO.File]::WriteAllText($taskFailureFile, "services:`n  initialize:`n    environment:`n      Database__Password: TEST_ONLY_INVALID`n")
    docker compose -f docker-compose.yml -f $taskFailureFile up -d --wait --force-recreate web *> (Join-Path $taskScope.Logs 'expected-failure.log')
    if (!$LASTEXITCODE) { throw 'Compose разрешил запуск после отказа инициализации.' }
    $taskWeb = docker compose ps --all --format json web | ConvertFrom-Json
    if ($taskWeb.State -eq 'running') { throw 'Сайт работает после отказа инициализации.' }
    Write-Host 'Контейнерные миграции с нуля, два параллельных процесса, ожидание/отказ сайта и повторный запуск прошли.'
} finally {
    try {
        foreach ($taskProcess in $taskProcesses) { if (!$taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id; $taskProcess.WaitForExit() } }
    } finally {
        try { if ($taskScope) { Remove-CinemaDockerTestEnvironment $taskScope } }
        finally { Pop-Location }
    }
}
