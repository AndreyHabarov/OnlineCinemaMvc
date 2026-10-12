[CmdletBinding()]
param([switch]$PrepareOnly)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    if (!(Test-Path -LiteralPath .env)) {
        [byte[]]$taskBytes = New-Object byte[] 32
        $taskRandom = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $taskRandom.GetBytes($taskBytes) } finally { $taskRandom.Dispose() }
        $taskPassword = [BitConverter]::ToString($taskBytes).Replace('-', '').ToLowerInvariant()
        $taskTemplate = [IO.File]::ReadAllText((Join-Path $PWD '.env.example'))
        if ($taskTemplate -notmatch '(?m)^POSTGRES_PASSWORD=') { throw 'В шаблоне нет настройки PostgreSQL.' }
        $taskTemplate = [regex]::Replace($taskTemplate, '(?m)^POSTGRES_PASSWORD=[^\r\n]*', 'POSTGRES_PASSWORD=' + $taskPassword)
        # CreateNew исключает перезапись конфигурации другого запуска.
        $taskStream = [IO.File]::Open((Join-Path $PWD '.env'), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
        try {
            $taskWriter = [IO.StreamWriter]::new($taskStream, [Text.UTF8Encoding]::new($false))
            try { $taskWriter.Write($taskTemplate) } finally { $taskWriter.Dispose() }
        } finally { $taskStream.Dispose() }
        if ([Environment]::OSVersion.Platform -eq 'Unix') {
            [IO.File]::SetUnixFileMode((Join-Path $PWD '.env'), [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
        }
        Write-Host 'Создан локальный .env со случайным паролем. Существующие настройки сохраняются.'
    }
    if ($PrepareOnly) { return }
    docker info --format '{{.ServerVersion}}' *> $null
    if ($LASTEXITCODE) { throw 'Запустите Docker Desktop/Engine и повторите команду.' }
    docker compose config --quiet
    if ($LASTEXITCODE) { throw 'Проверьте локальные настройки .env.' }
    docker compose up --build -d --wait
    if ($LASTEXITCODE) { throw 'Запуск не завершён. Проверьте docker compose logs initialize web.' }
    $taskAddress = docker compose port web 8080
    if ($LASTEXITCODE) { throw 'Не удалось определить порт сайта.' }
    Write-Host "Кинотеатр готов: http://$taskAddress"
} finally { Pop-Location }
