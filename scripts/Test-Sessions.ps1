[CmdletBinding()]
param([string]$BaseUrl = 'http://127.0.0.1:5175')

$ErrorActionPreference = 'Stop'
$taskZoneName = if ([Environment]::OSVersion.Platform -eq 'Win32NT') { 'Russian Standard Time' } else { 'Europe/Moscow' }
$taskNow = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, [TimeZoneInfo]::FindSystemTimeZoneById($taskZoneName))
$taskTomorrow = $taskNow.Date.AddDays(1).ToString('dd.MM.yyyy')

function Get-SessionsResponse([string]$Query) {
    Invoke-WebRequest -NoProxy -TimeoutSec 20 -SkipHttpErrorCheck "$BaseUrl/Movies/GetAllSessions$Query"
}

foreach ($taskQuery in @('', '?date=bad', '?date=31.02.2026', '?date=31.12.9999', "?date=$taskTomorrow&movieId=0", "?date=$taskTomorrow&hallId=-1", "?date=$taskTomorrow&hallId=abc")) {
    $taskResponse = Get-SessionsResponse $taskQuery
    if ($taskResponse.StatusCode -ne 400) { throw "Ожидался 400 для $taskQuery" }
}

$taskResponse = Get-SessionsResponse "?date=$taskTomorrow"
if ($taskResponse.StatusCode -ne 200) { throw 'Расписание недоступно.' }
$taskSessions = @($taskResponse.Content | ConvertFrom-Json)
if ($taskSessions.Count -ne 20) { throw 'Загрузите демонстрационное расписание: завтра ожидаются 20 показов.' }
if (@($taskSessions.MovieId | Sort-Object -Unique).Count -ne 20) { throw 'Ожидались 20 разных фильмов.' }
foreach ($taskSession in $taskSessions) {
    if (!$taskSession.HallName -or !$taskSession.MovieName -or $taskSession.Price -le 0) { throw 'Неполные данные сеанса.' }
    if ($taskSession.PSObject.Properties.Name -contains 'movie' -or $taskSession.PSObject.Properties.Name -contains 'hall') { throw 'В ответе присутствуют EF-навигации.' }
}
if ($taskResponse.Content -match '"dateStart"\s*:\s*"[^"\r\n]*(?:Z|\+\d{2}:\d{2})"') { throw 'Московское время неожиданно содержит смещение.' }
if (($taskSessions.DateStart -join ',') -ne (($taskSessions.DateStart | Sort-Object) -join ',')) { throw 'Нарушен порядок сеансов.' }

$taskHall = $taskSessions[0].HallId
$taskFiltered = @((Get-SessionsResponse "?date=$taskTomorrow&hallId=$taskHall").Content | ConvertFrom-Json)
if ($taskFiltered.Count -ne 4 -or @($taskFiltered | Where-Object HallId -ne $taskHall).Count) { throw 'Фильтр зала не работает.' }
$taskMovie = $taskSessions[0].MovieId
$taskFiltered = @((Get-SessionsResponse "?date=$taskTomorrow&movieId=$taskMovie&hallId=$taskHall").Content | ConvertFrom-Json)
if ($taskFiltered.Count -ne 1 -or $taskFiltered[0].MovieId -ne $taskMovie) { throw 'Фильтр фильма не работает.' }

foreach ($taskQuery in @('?date=08.10.2025', "?date=$taskTomorrow&movieId=2147483647", "?date=$taskTomorrow&hallId=2147483647")) {
    $taskResponse = Get-SessionsResponse $taskQuery
    if ($taskResponse.StatusCode -ne 200 -or $taskResponse.Content.Trim() -ne '[]') { throw "Ожидался пустой список для $taskQuery" }
}
$taskToday = $taskNow.ToString('dd.MM.yyyy')
$taskCurrent = @((Get-SessionsResponse "?date=$taskToday").Content | ConvertFrom-Json)
if (@($taskCurrent | Where-Object { [DateTime]$_.DateStart -lt $taskNow }).Count) { throw 'Возвращены начавшиеся сеансы.' }
$taskPage = Invoke-WebRequest -NoProxy -TimeoutSec 20 "$BaseUrl/movies/$taskMovie"
if ($taskPage.Content -notmatch 'session-date active' -or $taskPage.Content -notmatch 'data-date=') { throw 'Не выбрана первая доступная дата фильма.' }
Write-Host 'Проверены: 20 показов, фильтры фильма/зала, сортировка, DTO, московское время, неверные параметры, прошедшие/скрытые сеансы и активная дата.'
