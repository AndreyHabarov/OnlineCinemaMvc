[CmdletBinding()]
param(
    [string]$StartDate,
    [ValidateRange(1, 14)][int]$Days = 7
)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOldEncoding = $OutputEncoding
Push-Location $taskRoot
try {
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $taskZoneName = if ([Environment]::OSVersion.Platform -eq 'Win32NT') { 'Russian Standard Time' } else { 'Europe/Moscow' }
    $taskToday = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, [TimeZoneInfo]::FindSystemTimeZoneById($taskZoneName)).Date
    $taskFirstDate = if ($StartDate) {
        [DateTime]::ParseExact($StartDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    } else { $taskToday }
    if ($taskFirstDate -lt $taskToday) { throw 'Начальная дата расписания не может быть в прошлом.' }
    $taskMovies = @(Get-Content data/demo-movies.json -Raw -Encoding utf8 | ConvertFrom-Json)
    if ($taskMovies.Count -ne 36) { throw 'Для расписания требуется каталог из 36 фильмов.' }
    $taskHalls = @(Get-Content data/demo-halls.json -Raw -Encoding utf8 | ConvertFrom-Json)
    $taskSlots = @(
        for ($taskDay = 0; $taskDay -lt $Days; $taskDay++) {
            $taskDate = $taskFirstDate.AddDays($taskDay)
            # Привязка к календарному дню сохраняет расписание при запуске завтра.
            $taskDayNumber = [int][Math]::Floor(($taskDate - [DateTime]::new(2000, 1, 1)).TotalDays)
            for ($taskSlot = 0; $taskSlot -lt 4; $taskSlot++) {
                for ($taskHall = 0; $taskHall -lt $taskHalls.Count; $taskHall++) {
                    @{
                        DateStart = $taskDate.AddHours(10 + 4 * $taskSlot).ToString('yyyy-MM-ddTHH:mm:ss')
                        MovieNumber = ($taskDayNumber * $taskHalls.Count * 4 + $taskHall * 4 + $taskSlot) % $taskMovies.Count
                        HallNumber = $taskHall
                        Price = $taskHalls[$taskHall].price
                    }
                }
            }
        }
    )
    $taskCompose = (docker compose config --format json | Out-String | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось прочитать Docker Compose.' }
    $taskUser = [string]$taskCompose.services.db.environment.POSTGRES_USER
    $taskDatabase = [string]$taskCompose.services.db.environment.POSTGRES_DB
    New-Item -ItemType Directory -Path backups -Force | Out-Null
    $taskBackup = 'cinemadb-before-schedule-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.dump'
    docker compose exec -T db pg_dump -U $taskUser -d $taskDatabase --format=custom --no-owner --no-privileges --file="/tmp/$taskBackup"
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось создать резервную копию.' }
    docker compose cp "db:/tmp/$taskBackup" (Join-Path $taskRoot "backups/$taskBackup")
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось сохранить резервную копию.' }
    $taskSql = Get-Content scripts/sql/update-demo-schedule.sql -Raw -Encoding utf8
    $taskNames = ConvertTo-Json -InputObject @($taskMovies.OriginalName) -Compress
    $taskJson = ConvertTo-Json -InputObject $taskSlots -Compress
    $taskSql = $taskSql.Replace('__MOVIE_NAMES__', $taskNames.Replace("'", "''")).Replace('__SCHEDULE_JSON__', $taskJson.Replace("'", "''")).Replace('__EXPECTED_COUNT__', [string]$taskSlots.Count).Replace('__HALL_SLUGS__', ((ConvertTo-Json -InputObject @($taskHalls.slug) -Compress).Replace("'", "''")))
    $taskSql | docker compose exec -T -e PGCLIENTENCODING=UTF8 db psql -X -U $taskUser -d $taskDatabase -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) { throw 'Загрузка расписания отменена. Проверьте каталог, залы и пересечения.' }
    Write-Host "Расписание подготовлено с $($taskFirstDate.ToString('dd.MM.yyyy')) на $Days дней: 20 сеансов в день, время московское."
} finally {
    $OutputEncoding = $taskOldEncoding
    Pop-Location
}
