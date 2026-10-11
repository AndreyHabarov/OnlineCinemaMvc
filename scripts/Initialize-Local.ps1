[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot

try {
    $taskEnvPath = Join-Path $taskRoot '.env'
    if (-not (Test-Path -LiteralPath $taskEnvPath)) {
        $taskRandomBytes = New-Object byte[] 32
        $taskRandom = [Security.Cryptography.RandomNumberGenerator]::Create()
        try {
            $taskRandom.GetBytes($taskRandomBytes)
        }
        finally {
            $taskRandom.Dispose()
        }

        $taskPassword = [BitConverter]::ToString($taskRandomBytes).Replace('-', '').ToLowerInvariant()
        @(
            'POSTGRES_USER=cinema'
            'POSTGRES_DB=cinemadb'
            "POSTGRES_PASSWORD=$taskPassword"
            'POSTGRES_PORT=5434'
        ) | Set-Content -LiteralPath $taskEnvPath -Encoding utf8
        Write-Host 'Создан локальный .env со случайным паролем.'
    }

    # Compose читает .env и переменные среды по тем же правилам, что и команда up.
    $taskComposeJson = & docker compose config --format json
    if ($LASTEXITCODE -ne 0) {
        throw 'Не удалось прочитать Docker Compose. Проверьте Docker Desktop и .env.'
    }

    $taskCompose = ($taskComposeJson -join "`n") | ConvertFrom-Json
    $taskDatabase = $taskCompose.services.db
    $taskPassword = [string]$taskDatabase.environment.POSTGRES_PASSWORD
    if ($taskPassword -eq 'replace-with-a-local-password') {
        throw 'Замените пример пароля в .env на собственный пароль.'
    }

    $taskPort = [int]$taskDatabase.ports[0].published
    if ($taskPort -lt 1 -or $taskPort -gt 65535) {
        throw 'POSTGRES_PORT должен быть в диапазоне 1–65535.'
    }

    & docker compose up -d --wait --wait-timeout 60 db
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось запустить PostgreSQL. Проверьте доступность порта $taskPort."
    }

    $taskConnection = New-Object System.Data.Common.DbConnectionStringBuilder
    $taskConnection['Host'] = '127.0.0.1'
    $taskConnection['Port'] = $taskPort
    $taskConnection['Database'] = [string]$taskDatabase.environment.POSTGRES_DB
    $taskConnection['Username'] = [string]$taskDatabase.environment.POSTGRES_USER
    $taskConnection['Password'] = $taskPassword
    $taskConnection['Pooling'] = $true

    $taskLocalSettings = @{
        ConnectionStrings = @{ Default = $taskConnection.ConnectionString }
    }
    $taskLocalSettings | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (
        Join-Path $taskRoot 'OnlineCinema.Mvc/appsettings.Development.local.json'
    ) -Encoding utf8

    & dotnet tool restore
    if ($LASTEXITCODE -ne 0) {
        throw 'Не удалось восстановить локальный dotnet-ef.'
    }

    & dotnet ef database update --project OnlineCinema.Domain --startup-project OnlineCinema.Mvc -- --environment Development
    if ($LASTEXITCODE -ne 0) {
        throw 'Не удалось применить миграции PostgreSQL.'
    }

    Write-Host "PostgreSQL готов: 127.0.0.1:$taskPort."
    Write-Host 'Запуск сайта: dotnet run --project OnlineCinema.Mvc --launch-profile http'
}
finally {
    Pop-Location
}
