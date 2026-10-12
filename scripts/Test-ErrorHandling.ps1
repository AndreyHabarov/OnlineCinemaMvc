[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$taskOldEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$taskRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/Test-Process.ps1')
$taskMvc = Join-Path $taskRoot 'OnlineCinema.Mvc'
$taskDll = Join-Path $taskMvc 'bin/Debug/net8.0/OnlineCinema.Mvc.dll'
if (!(Test-Path $taskDll)) { throw 'Сначала выполните dotnet build OnlineCinemaMvc.sln.' }

# Отдельный сайт в Production с намеренно недоступной тестовой БД.
# Рабочее подключение, контейнер и записи проекта не изменяются.
$taskSocket = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$taskSocket.Start()
$taskPort = $taskSocket.LocalEndpoint.Port
$taskSocket.Stop()
$taskDbSocket = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$taskDbSocket.Start()
$taskDbPort = $taskDbSocket.LocalEndpoint.Port
$taskBase = "http://127.0.0.1:$taskPort"
$taskLogs = Join-Path $taskRoot "backups/error-check-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $taskLogs -Force | Out-Null
$taskProcess = $null
try {
    $taskProcess = Start-CinemaTestProcess -MvcPath $taskMvc -BaseUrl $taskBase -Logs $taskLogs -ExtraArgs @('--ConnectionStrings:Default', "Host=127.0.0.1;Port=$taskDbPort;Database=error_probe;Username=probe;Password=TEST_ONLY_SECRET;Timeout=1;SSLMode=Disable")

    $taskReady = $false
    for ($taskAttempt = 0; $taskAttempt -lt 40; $taskAttempt++) {
        if ($taskProcess.HasExited) { throw 'Проверочный сайт завершился до запуска.' }
        try {
            $taskResponse = Invoke-WebRequest "$taskBase/Home/Error" -NoProxy -SkipHttpErrorCheck -TimeoutSec 2
            $taskReady = $true
            break
        } catch { Start-Sleep -Milliseconds 250 }
    }
    if (!$taskReady) { throw 'Проверочный сайт не запустился.' }

    foreach ($taskMethod in @('GET', 'POST')) {
        $taskResponse = Invoke-WebRequest "$taskBase/Home/Error" -Method $taskMethod -NoProxy -SkipHttpErrorCheck -TimeoutSec 10
        if ($taskResponse.StatusCode -ne 500) { throw "Обработчик $taskMethod не вернул 500." }
        if ($taskResponse.Headers['Cache-Control'] -notmatch 'no-store') { throw 'Ошибка может кэшироваться.' }
        if ($taskResponse.Content -notmatch 'Не удалось открыть страницу' -or $taskResponse.Content -notmatch 'Код обращения:') { throw 'Отсутствует русская страница ошибки или код обращения.' }
    }

    $taskResponse = Invoke-WebRequest "$taskBase/?private=TEST_ONLY_SECRET" -NoProxy -SkipHttpErrorCheck -TimeoutSec 15
    if ($taskResponse.StatusCode -ne 500 -or $taskResponse.Content -notmatch 'Не удалось открыть страницу') { throw 'Реальное исключение БД не обработано.' }
    if ($taskResponse.Content -match 'TEST_ONLY_SECRET|Npgsql|Exception|StackTrace|Development Mode') { throw 'Технические подробности раскрыты пользователю.' }
    $taskId = [regex]::Match($taskResponse.Content, '<code>([^<]+)</code>').Groups[1].Value
    if (!$taskId) { throw 'У ошибки нет идентификатора.' }
    $taskLog = Get-Content (Join-Path $taskLogs 'stdout.log') -Raw
    if ($taskLog -notmatch [regex]::Escape($taskId) -or $taskLog -notmatch 'fail: OnlineCinema.Mvc.Controllers.ErrorController\[0\]') { throw 'Нет связанного безопасного сообщения об ошибке.' }
    if ($taskLog -match 'TEST_ONLY_SECRET') { throw 'Тестовый секрет попал в журнал.' }

    $taskResponse = Invoke-WebRequest "$taskBase/not-an-existing-page" -NoProxy -SkipHttpErrorCheck -TimeoutSec 10
    if ($taskResponse.StatusCode -ne 404) { throw 'Несуществующий маршрут неожиданно превращён в 500.' }
    $taskResponse = Invoke-WebRequest "$taskBase/css/error.css" -NoProxy -TimeoutSec 10
    if ($taskResponse.StatusCode -ne 200) { throw 'Стили страницы ошибки недоступны.' }
    Write-Host 'Проверены: Production, ошибка БД, GET/POST обработчика, 500, no-store, русский текст, безопасный журнал, 404 и CSS.'
} finally {
    [Console]::OutputEncoding = $taskOldEncoding
    $taskDbSocket.Stop()
    if ($taskProcess -and !$taskProcess.HasExited) {
        Stop-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue
        $taskProcess.WaitForExit()
    }
}
