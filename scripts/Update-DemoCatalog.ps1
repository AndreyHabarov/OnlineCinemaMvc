[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOldOutputEncoding = $OutputEncoding
Push-Location $taskRoot

try {
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $taskMovies = @(Get-Content -LiteralPath data/demo-movies.json -Raw -Encoding utf8 | ConvertFrom-Json)
    $taskSources = @(Get-Content -LiteralPath data/movie-poster-sources.json -Raw -Encoding utf8 | ConvertFrom-Json)
    if ($taskMovies.Count -ne 36 -or @($taskMovies.OriginalName | Select-Object -Unique).Count -ne 36) {
        throw 'В каталоге должны быть 36 разных фильмов.'
    }

    foreach ($taskMovie in $taskMovies) {
        $taskReleaseDate = [DateTime]::ParseExact($taskMovie.ReleaseDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        if ($taskReleaseDate.Year -lt 1990 -or $taskReleaseDate.Year -gt 1999 -or $taskMovie.Country -notmatch 'США') {
            throw "Фильм не соответствует подборке американского кино 90-х: $($taskMovie.Name)"
        }
        if ($taskMovie.Description -notmatch '[А-Яа-яЁё]' -or $taskMovie.Duration -le 0 -or @($taskMovie.Genres).Count -eq 0) {
            throw "Неполные данные фильма: $($taskMovie.Name)"
        }

        $taskPoster = @($taskSources | Where-Object { $_.Slug -eq $taskMovie.Slug })
        if ($taskPoster.Count -ne 1 -or $taskPoster[0].PosterPath -notmatch '^images/movies/1990s/[a-z0-9-]+\.(jpg|jpeg|png)$') {
            throw "Некорректный постер: $($taskMovie.Name)"
        }
        $taskPosterFile = Join-Path $taskRoot ('OnlineCinema.Mvc/wwwroot/' + $taskPoster[0].PosterPath)
        if (-not (Test-Path -LiteralPath $taskPosterFile -PathType Leaf)) {
            throw "Отсутствует изображение: $($taskMovie.Name)"
        }
        $taskMovie | Add-Member -NotePropertyName PosterPath -NotePropertyValue $taskPoster[0].PosterPath -Force
    }

    $taskComposeJson = & docker compose config --format json
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось прочитать конфигурацию Docker Compose.' }
    $taskCompose = ($taskComposeJson -join "`n") | ConvertFrom-Json
    $taskUser = [string]$taskCompose.services.db.environment.POSTGRES_USER
    $taskDatabase = [string]$taskCompose.services.db.environment.POSTGRES_DB

    # Приватная резервная копия создаётся до изменения каталога.
    $taskBackupRoot = Join-Path $taskRoot 'backups'
    New-Item -ItemType Directory -Path $taskBackupRoot -Force | Out-Null
    $taskBackupName = 'cinemadb-before-catalog-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.dump'
    & docker compose exec -T db pg_dump -U $taskUser -d $taskDatabase --format=custom --no-owner --no-privileges --file="/tmp/$taskBackupName"
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось создать резервную копию каталога.' }
    & docker compose cp "db:/tmp/$taskBackupName" (Join-Path $taskBackupRoot $taskBackupName)
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось сохранить резервную копию локально.' }
    & docker compose exec -T db pg_restore --list "/tmp/$taskBackupName" *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Резервная копия не прошла проверку.' }

    $taskCatalogJson = ConvertTo-Json -InputObject $taskMovies -Depth 5 -Compress
    $taskSqlTemplate = Get-Content -LiteralPath scripts/sql/update-demo-catalog.sql -Raw -Encoding utf8
    $taskSql = $taskSqlTemplate.Replace('__DEMO_CATALOG_JSON__', $taskCatalogJson.Replace("'", "''"))
    $taskSql | & docker compose exec -T -e PGCLIENTENCODING=UTF8 db psql -X -U $taskUser -d $taskDatabase --set=ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось обновить каталог. Изменения транзакции откатились.' }

    Write-Host 'Каталог обновлён: 36 американских фильмов 90-х. Существующие карточки и заказы сохранены.'
    Write-Host "Резервная копия: backups/$taskBackupName"
}
finally {
    $OutputEncoding = $taskOldOutputEncoding
    Pop-Location
}
