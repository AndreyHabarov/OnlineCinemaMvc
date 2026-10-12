[CmdletBinding()]
param([string]$BaseUrl='http://127.0.0.1:5175')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskCasts=Get-Content (Join-Path $taskRoot 'data/movie-casts.json') -Raw -Encoding utf8 | ConvertFrom-Json
$taskActors=Get-Content (Join-Path $taskRoot 'data/actor-photo-sources.json') -Raw -Encoding utf8 | ConvertFrom-Json
$taskConfig=docker compose config --format json | ConvertFrom-Json
if($LASTEXITCODE){throw 'Не прочитана конфигурация Compose.'}
$taskUser=[string]$taskConfig.services.db.environment.POSTGRES_USER
$taskDatabase=[string]$taskConfig.services.db.environment.POSTGRES_DB
$taskRows='SELECT "Id"||''|''||"OriginalName" FROM "Movies" WHERE "IsVisible";' | docker compose exec -T db psql -X -At -U $taskUser -d $taskDatabase -v ON_ERROR_STOP=1
if($LASTEXITCODE){throw 'Не прочитаны фильмы.'}
$taskIds=@{};foreach($taskRow in $taskRows){$taskFields=$taskRow.Split('|',2);$taskIds[$taskFields[1]]=[int]$taskFields[0]}
$taskPhotos=@{}
foreach($taskCast in $taskCasts){
    if(!$taskIds.ContainsKey($taskCast.OriginalName)){throw 'Не найден видимый фильм демокаталога.'}
    $taskHtml=(Invoke-WebRequest "$BaseUrl/movies/$($taskIds[$taskCast.OriginalName])" -NoProxy -TimeoutSec 20).Content
    if([regex]::Matches($taskHtml,'class="cast-card"').Count -ne 5){throw "Нет пяти исполнителей: $($taskCast.Slug)"}
    foreach($taskSlug in $taskCast.Actors){
        $taskActor=@($taskActors | Where-Object Slug -eq $taskSlug)[0]
        if(!$taskHtml.Contains($taskActor.PhotoPath) -or !([Net.WebUtility]::HtmlDecode($taskHtml)).Contains($taskActor.Name)){throw 'Портрет или имя потеряны.'}
        $taskPhotos[$taskActor.PhotoPath]=$true
    }
    if($taskCast.IsVoiceCast -and [Net.WebUtility]::HtmlDecode($taskHtml) -notmatch 'Голоса персонажей'){throw 'Не подписана оригинальная озвучка.'}
    if([Net.WebUtility]::HtmlDecode($taskHtml) -notmatch 'Источники и лицензии фотографий'){throw 'Нет атрибуции фотографий.'}
}
foreach($taskPath in $taskPhotos.Keys){$taskResponse=Invoke-WebRequest "$BaseUrl/$taskPath" -NoProxy -TimeoutSec 20;if($taskResponse.Headers.'Content-Type' -notmatch '^image/'){throw 'Вместо фото возвращён другой файл.'}}
Write-Host "Проверены пять исполнителей в 36 фильмах, оригинальные голоса, русские имена, атрибуция и $($taskPhotos.Count) локальных изображений."
