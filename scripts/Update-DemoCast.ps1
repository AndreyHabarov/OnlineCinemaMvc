[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskOldEncoding=$OutputEncoding
Push-Location $taskRoot
try {
    $OutputEncoding=[Text.UTF8Encoding]::new($false)
    $taskCasts=@(Get-Content data/movie-casts.json -Raw -Encoding utf8 | ConvertFrom-Json)
    $taskActors=@(Get-Content data/actor-photo-sources.json -Raw -Encoding utf8 | ConvertFrom-Json)
    if($taskCasts.Count -ne 36){throw 'Нужны составы 36 фильмов.'}
    $taskActorMap=@{}
    foreach($taskActor in $taskActors){
        if($taskActor.PhotoPath -notmatch '^images/actors/[a-z0-9-]+\.(jpg|jpeg|png)$' -or !(Test-Path -LiteralPath ('OnlineCinema.Mvc/wwwroot/'+$taskActor.PhotoPath))){throw 'Отсутствует локальный портрет.'}
        $taskActorMap[$taskActor.Slug]=$taskActor.Name
    }
    $taskData=@(foreach($taskCast in $taskCasts){
        if($taskCast.Actors.Count -lt 5 -or @($taskCast.Actors | Where-Object {!$taskActorMap.ContainsKey($_)}).Count){throw 'Неполный состав фильма.'}
        @{Slug=$taskCast.Slug;OriginalName=$taskCast.OriginalName;Actor=($taskCast.Actors | ForEach-Object {$taskActorMap[$_]}) -join ', ';LegacyActors=@($taskCast.LegacyActors)}
    })
    $taskConfig=docker compose config --format json | ConvertFrom-Json
    if($LASTEXITCODE){throw 'Не прочитана конфигурация Compose.'}
    $taskUser=[string]$taskConfig.services.db.environment.POSTGRES_USER
    $taskDatabase=[string]$taskConfig.services.db.environment.POSTGRES_DB
    New-Item -ItemType Directory backups -Force | Out-Null
    $taskBackup='cinemadb-before-cast-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.dump'
    docker compose exec -T db pg_dump -U $taskUser -d $taskDatabase -Fc --file="/tmp/$taskBackup"
    if($LASTEXITCODE){throw 'Не создана резервная копия.'}
    docker compose cp "db:/tmp/$taskBackup" (Join-Path $taskRoot "backups/$taskBackup")
    if($LASTEXITCODE){throw 'Не сохранена резервная копия.'}
    docker compose exec -T db pg_restore --list "/tmp/$taskBackup" *> $null
    if($LASTEXITCODE){throw 'Резервная копия не прошла проверку.'}
    $taskJson=ConvertTo-Json -InputObject $taskData -Compress -Depth 6
    $taskSql=(Get-Content scripts/sql/update-demo-cast.sql -Raw -Encoding utf8).Replace('__CAST_JSON__',$taskJson.Replace("'","''"))
    $taskSql | docker compose exec -T -e PGCLIENTENCODING=UTF8 db psql -X -U $taskUser -d $taskDatabase -v ON_ERROR_STOP=1
    if($LASTEXITCODE){throw 'Обновление состава фильмов отменено.'}
    Write-Host 'Состав фильмов обновлён; пользовательские изменения сохранены. Портреты доступны локально.'
} finally {$OutputEncoding=$taskOldEncoding;Pop-Location}
