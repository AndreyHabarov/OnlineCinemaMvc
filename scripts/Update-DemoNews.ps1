[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskOldEncoding=$OutputEncoding
Push-Location $taskRoot
try {
    $OutputEncoding=[Text.UTF8Encoding]::new($false)
    $taskData=@(Get-Content data/demo-news.json -Raw -Encoding utf8 | ConvertFrom-Json)
    if($taskData.Count -ne 3){throw 'Нужны три демонстрационные новости.'}
    foreach($taskItem in $taskData){
        if($taskItem.ImagePath -notmatch '^/images/news/[a-z0-9-]+\.png$' -or !(Test-Path -LiteralPath ('OnlineCinema.Mvc/wwwroot'+$taskItem.ImagePath))){throw 'Отсутствует иллюстрация новости.'}
    }
    $taskConfig=docker compose config --format json | ConvertFrom-Json
    if($LASTEXITCODE){throw 'Не прочитана конфигурация Compose.'}
    $taskUser=[string]$taskConfig.services.db.environment.POSTGRES_USER
    $taskDatabase=[string]$taskConfig.services.db.environment.POSTGRES_DB
    New-Item -ItemType Directory backups -Force | Out-Null
    $taskBackup='cinemadb-before-news-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.dump'
    docker compose exec -T db pg_dump -U $taskUser -d $taskDatabase -Fc --file="/tmp/$taskBackup"
    if($LASTEXITCODE){throw 'Не создана резервная копия.'}
    docker compose cp "db:/tmp/$taskBackup" (Join-Path $taskRoot "backups/$taskBackup")
    if($LASTEXITCODE){throw 'Не сохранена резервная копия.'}
    docker compose exec -T db pg_restore --list "/tmp/$taskBackup" *> $null
    if($LASTEXITCODE){throw 'Резервная копия не прошла проверку.'}
    $taskJson=ConvertTo-Json -InputObject $taskData -Compress -Depth 8
    $taskSql=(Get-Content scripts/sql/update-demo-news.sql -Raw -Encoding utf8).Replace('__NEWS_JSON__',$taskJson.Replace("'","''"))
    $taskSql | docker compose exec -T -e PGCLIENTENCODING=UTF8 db psql -X -U $taskUser -d $taskDatabase -v ON_ERROR_STOP=1
    if($LASTEXITCODE){throw 'Обновление новостей отменено.'}
    Write-Host 'Новости обновлены. Распознанные старые шаблоны заменены; пользовательские правки и удаления сохранены.'
} finally {$OutputEncoding=$taskOldEncoding;Pop-Location}
