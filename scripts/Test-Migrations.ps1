[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Push-Location $taskRoot
$taskDb = 'codex_migration_' + [Guid]::NewGuid().ToString('N')
$taskLog = Join-Path $taskRoot "backups/$taskDb"
New-Item -ItemType Directory -Path $taskLog -Force | Out-Null
$taskPreviousConnection = $env:ConnectionStrings__Default
$taskCreated = $false
try {
    $taskConfig = docker compose config --format json | ConvertFrom-Json
    if ($LASTEXITCODE) { throw 'Compose недоступен.' }
    $taskUser = [string]$taskConfig.services.db.environment.POSTGRES_USER
    $taskConnection = [Data.Common.DbConnectionStringBuilder]::new()
    $taskConnection['Host'] = '127.0.0.1'
    $taskConnection['Port'] = [int]$taskConfig.services.db.ports[0].published
    $taskConnection['Database'] = $taskDb
    $taskConnection['Username'] = $taskUser
    $taskConnection['Password'] = [string]$taskConfig.services.db.environment.POSTGRES_PASSWORD
    $env:ConnectionStrings__Default = $taskConnection.ConnectionString
    docker compose exec -T db createdb -U $taskUser $taskDb
    if ($LASTEXITCODE) { throw 'Не удалось создать тестовую БД.' }
    $taskCreated = $true
    dotnet ef database update AddDemoTicketPurchases --no-build --project OnlineCinema.Domain --startup-project OnlineCinema.Mvc -- --environment Development *> (Join-Path $taskLog 'before-phone.log')
    if ($LASTEXITCODE) { throw 'Предыдущие миграции не прошли.' }
    @'
INSERT INTO "AspNetUsers" ("Name","LastName","IsMan","PhoneNumber","EmailConfirmed","PhoneNumberConfirmed","TwoFactorEnabled","LockoutEnabled","AccessFailedCount")
VALUES ('Проверка','Первый',false,'+7 (900) 000-00-01',false,false,false,true,0),
       ('Проверка','Второй',false,'8 900 000-00-01',false,false,false,true,0);
'@ | docker compose exec -T db psql -X -q -U $taskUser -d $taskDb -v ON_ERROR_STOP=1
    if ($LASTEXITCODE) { throw 'Подготовка конфликта не прошла.' }
    dotnet ef database update UniqueNormalizedPhone --no-build --project OnlineCinema.Domain --startup-project OnlineCinema.Mvc -- --environment Development *> (Join-Path $taskLog 'expected-conflict.log')
    if (!$LASTEXITCODE) { throw 'Миграция ошибочно разрешила повторный телефон.' }
    $taskState = 'SELECT count(*) FROM information_schema.columns WHERE table_name=''AspNetUsers'' AND column_name=''NormalizedPhoneNumber'';' |
        docker compose exec -T db psql -X -At -U $taskUser -d $taskDb -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -or [int]$taskState -ne 0) { throw 'Миграция с конфликтом не откатилась.' }
    'UPDATE "AspNetUsers" SET "PhoneNumber"=''9000000002'' WHERE "LastName"=''Второй'';' |
        docker compose exec -T db psql -X -q -U $taskUser -d $taskDb -v ON_ERROR_STOP=1
    if ($LASTEXITCODE) { throw 'Подготовка бесконфликтных данных не прошла.' }
    dotnet ef database update --no-build --project OnlineCinema.Domain --startup-project OnlineCinema.Mvc -- --environment Development *> (Join-Path $taskLog 'latest.log')
    if ($LASTEXITCODE) { throw 'Миграции на существующих данных не прошли.' }
    $taskPhones = 'SELECT "NormalizedPhoneNumber" FROM "AspNetUsers" ORDER BY "NormalizedPhoneNumber";' |
        docker compose exec -T db psql -X -At -U $taskUser -d $taskDb -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -or ($taskPhones -join ',') -ne '+79000000001,+79000000002') { throw 'Старые данные потеряны или неверно нормализованы.' }
    dotnet ef database update --no-build --project OnlineCinema.Domain --startup-project OnlineCinema.Mvc -- --environment Development *> (Join-Path $taskLog 'repeat.log')
    if ($LASTEXITCODE) { throw 'Повторное применение не прошло.' }
    Write-Host 'Проверены миграции PostgreSQL: откат конфликта телефонов, сохранение старых пользователей, нормализация 8/+7/10 цифр, повторное применение.'
} finally {
    $env:ConnectionStrings__Default = $taskPreviousConnection
    try {
        if ($taskCreated -and $taskDb -match '^codex_migration_[a-f0-9]{32}$') {
            docker compose exec -T db dropdb -U $taskUser --force $taskDb
            if ($LASTEXITCODE) { Write-Warning "Не удалена собственная тестовая БД $taskDb." }
        }
    } finally { Pop-Location }
}
