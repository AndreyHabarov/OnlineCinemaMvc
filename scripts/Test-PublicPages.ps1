[CmdletBinding()]
param([ValidateRange(0, 300)][int]$UiHoldSeconds = 0)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Push-Location $taskRoot
$taskSuffix = [Guid]::NewGuid().ToString('N')
$taskDb = "codex_public_$taskSuffix"
$taskLogs = Join-Path $taskRoot "backups/public-check-$taskSuffix"
New-Item -ItemType Directory -Path $taskLogs -Force | Out-Null
$taskOldConnection = $env:ConnectionStrings__Default
$taskProcess = $null
$taskCreated = $false
try {
    $taskConfig = docker compose config --format json | ConvertFrom-Json
    if ($LASTEXITCODE) { throw 'Не удалось прочитать Compose.' }
    $taskUser = [string]$taskConfig.services.db.environment.POSTGRES_USER
    $taskConnection = [Data.Common.DbConnectionStringBuilder]::new()
    $taskConnection['Host'] = '127.0.0.1'
    $taskConnection['Port'] = [int]$taskConfig.services.db.ports[0].published
    $taskConnection['Database'] = $taskDb
    $taskConnection['Username'] = $taskUser
    $taskConnection['Password'] = [string]$taskConfig.services.db.environment.POSTGRES_PASSWORD
    $env:ConnectionStrings__Default = $taskConnection.ConnectionString

    docker compose exec -T db createdb -U $taskUser $taskDb
    if ($LASTEXITCODE) { throw 'Не удалось создать отдельную тестовую БД.' }
    $taskCreated = $true
    dotnet ef database update --no-build --project OnlineCinema.Domain --startup-project OnlineCinema.Mvc -- --environment Development *> (Join-Path $taskLogs 'migrations.log')
    if ($LASTEXITCODE) { throw "Миграции тестовой БД не прошли. Приватный журнал: $taskLogs" }

    $taskSocket = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $taskSocket.Start()
    $taskPort = $taskSocket.LocalEndpoint.Port
    $taskSocket.Stop()
    $taskBase = "http://127.0.0.1:$taskPort"
    $taskMvc = Join-Path $taskRoot 'OnlineCinema.Mvc'
    $taskProcess = Start-Process dotnet -ArgumentList @(
        (Join-Path $taskMvc 'bin/Debug/net8.0/OnlineCinema.Mvc.dll'),
        '--environment', 'Production', '--urls', $taskBase,
        '--DataProtection:KeysPath', (Join-Path $taskLogs 'keys'),
        '--Logging:EventLog:LogLevel:Default', 'None'
    ) -WorkingDirectory $taskMvc -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $taskLogs 'stdout.log') `
        -RedirectStandardError (Join-Path $taskLogs 'stderr.log')
    $taskReady = $false
    for ($taskAttempt = 0; $taskAttempt -lt 40; $taskAttempt++) {
        try {
            $taskResponse = Invoke-WebRequest $taskBase -NoProxy -TimeoutSec 2
            $taskReady = $true
            break
        } catch {
            if ($taskProcess.HasExited) { throw 'Проверочный сайт завершился.' }
            Start-Sleep -Milliseconds 250
        }
    }
    if (!$taskReady) { throw 'Сайт с пустой тестовой БД недоступен.' }

    $taskChecks = @{
        '/' = 'Фильмов в каталоге пока нет.'
        '/kids' = 'Фильмов для детей пока нет.'
        '/art' = 'Фильмов в разделе «Арт» пока нет.'
        '/promotions' = 'Акций пока нет.'
        '/news' = 'Новостей пока нет.'
        '/halls' = 'Информация о залах пока не добавлена.'
    }
    foreach ($taskCheck in $taskChecks.GetEnumerator()) {
        $taskPage = Invoke-WebRequest "$taskBase$($taskCheck.Key)" -NoProxy -TimeoutSec 15
        if ($taskPage.StatusCode -ne 200 -or ![Net.WebUtility]::HtmlDecode($taskPage.Content).Contains($taskCheck.Value)) {
            throw "Нет пустого состояния: $($taskCheck.Key)"
        }
        if ($taskPage.Content -match 'href="#"') { throw 'На публичной странице есть неработающая ссылка.' }
        if ($taskCheck.Key -eq '/' -and $taskPage.Content -match 'id="CarouselExampleDark"') { throw 'Пустой слайдер показан.' }
    }
    foreach ($taskRoute in @('/movies/2147483647', '/news/2147483647', '/promotions/codex-missing')) {
        $taskPage = Invoke-WebRequest "$taskBase$taskRoute" -NoProxy -SkipHttpErrorCheck -TimeoutSec 15
        if ($taskPage.StatusCode -ne 404) { throw "Отсутствующая запись не вернула 404: $taskRoute" }
    }
    Write-Host 'Проверены пустые каталоги/списки: HTTP 200 и сообщения, отсутствие заглушек и пустого слайдера, HTTP 404 отсутствующих записей; миграции с нуля.'
    # В старых данных могут быть URL, сохранённые до серверной валидации.
    @'
INSERT INTO "Promotions" ("Name", "DisplayName", "Description", "DateTime", "ImagePath", "ButtonText", "Link")
VALUES
('codex-unsafe-1', 'Проверка <img src=x onerror=alert(1)>', '<script>alert(1)</script>', now()::timestamp, '/images/logo/logo.png', 'Перейти', 'javascript:alert(1)'),
('codex-unsafe-2', 'Проверка', 'Тест', now()::timestamp, '/images/logo/logo.png', 'Перейти', 'data:text/html,<script>alert(1)</script>'),
('codex-unsafe-3', 'Проверка', 'Тест', now()::timestamp, '/images/logo/logo.png', 'Перейти', '//example.invalid'),
('codex-unsafe-4', 'Проверка', 'Тест', now()::timestamp, '/images/logo/logo.png', 'Перейти', '/\example.invalid'),
('codex-safe-1', 'Проверка', 'Тест', now()::timestamp, '/images/logo/logo.png', 'Перейти', 'https://example.invalid/path'),
('codex-safe-2', 'Проверка', 'Тест', now()::timestamp, '/images/logo/logo.png', 'Перейти', '/news?x=1&y=2');
'@ | docker compose exec -T db psql -X -q -U $taskUser -d $taskDb -v ON_ERROR_STOP=1
    if ($LASTEXITCODE) { throw 'Не удалось подготовить данные проверки HTML/URL в тестовой БД.' }
    foreach ($taskRoute in @('/', '/promotions')) {
        $taskPage = Invoke-WebRequest "$taskBase$taskRoute" -NoProxy -TimeoutSec 15
        if ($taskPage.Content -match '<script>alert|<img src=x onerror') { throw 'Данные БД вставлены как исполняемый HTML.' }
        $taskLinks = @([regex]::Matches($taskPage.Content, 'href="([^"]*)"') | ForEach-Object { [Net.WebUtility]::HtmlDecode($_.Groups[1].Value) })
        if (@($taskLinks | Where-Object { $_ -match '^(javascript:|data:|//|/\\)' }).Count) { throw 'Небезопасная ссылка показана.' }
        foreach ($taskFallback in @('/promotions/codex-unsafe-1','/promotions/codex-unsafe-2','/promotions/codex-unsafe-3','/promotions/codex-unsafe-4')) {
            if ($taskFallback -notin $taskLinks) { throw 'Нет безопасного перехода к акции.' }
        }
        if ('https://example.invalid/path' -notin $taskLinks -or '/news?x=1&y=2' -notin $taskLinks) { throw 'Допустимая ссылка потеряна.' }
    }
    Write-Host 'Проверены HTML-экранирование и блокировка опасных URL старых акций; локальные и HTTPS ссылки сохранены.'
    if ($UiHoldSeconds) {
        Write-Host "Браузерная проверка: $taskBase; остановка — файл $taskLogs/stop.flag"
        $taskDeadline = [DateTime]::UtcNow.AddSeconds($UiHoldSeconds)
        while ([DateTime]::UtcNow -lt $taskDeadline -and !(Test-Path (Join-Path $taskLogs 'stop.flag'))) { Start-Sleep -Milliseconds 500 }
    }
} finally {
    try {
        if ($taskProcess -and !$taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id; $taskProcess.WaitForExit() }
    } finally {
        $env:ConnectionStrings__Default = $taskOldConnection
        try {
            if ($taskCreated -and $taskDb -match '^codex_public_[a-f0-9]{32}$') {
                docker compose exec -T db dropdb -U $taskUser --force $taskDb
                if ($LASTEXITCODE) { Write-Warning "Не удалось удалить свою тестовую БД $taskDb." }
            }
        } finally { Pop-Location }
    }
}
