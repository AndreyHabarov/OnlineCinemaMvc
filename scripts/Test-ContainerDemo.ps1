[CmdletBinding()]
param([ValidateRange(0, 600)][int]$UiHoldSeconds = 0, [switch]$CheckScheduleRefresh)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
. (Join-Path $PSScriptRoot 'lib/Docker-TestEnvironment.ps1')
$taskScope = $null
function Test-Sql([string]$Sql) {
    $taskResult = $Sql | docker compose exec -T db psql -X -At -U cinema -d demo_check -v ON_ERROR_STOP=1
    if ($LASTEXITCODE) { throw 'Ошибка SQL проверки демоданных.' }
    return $taskResult
}
function Refresh-Token {
    $taskPage = Invoke-WebRequest $taskScope.BaseUrl -WebSession $taskClient -NoProxy -TimeoutSec 20
    $script:taskToken = [regex]::Match($taskPage.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
    if (!$script:taskToken) { throw 'Нет токена формы.' }
}
function Test-Post([string]$Path, $Body) {
    $taskResponse = Invoke-WebRequest "$($taskScope.BaseUrl)/$Path" -Method Post -WebSession $taskClient -NoProxy -TimeoutSec 30 -SkipHttpErrorCheck -Headers @{'X-CSRF-TOKEN'=$script:taskToken;Accept='application/json'} -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 5)
    if ($taskResponse.StatusCode -ne 200) { throw "HTTP-проверка $Path не прошла: $($taskResponse.StatusCode)." }
    return $taskResponse
}
try {
    $taskScope = New-CinemaDockerTestEnvironment
    $env:DEMO_ADMIN_ENABLED = 'true'
    $env:DEMO_ADMIN_PASSWORD = 'A1a' + [Guid]::NewGuid().ToString('N')
    if ($CheckScheduleRefresh) { $env:DEMO_SCHEDULE_REFRESH_MINUTES = '1' }
    docker compose up -d --wait *> (Join-Path $taskScope.Logs 'startup.log')
    if ($LASTEXITCODE) { throw 'Чистый Docker-запуск не прошёл.' }
    $taskCounts = Test-Sql 'SELECT (SELECT count(*) FROM "Movies"),(SELECT count(*) FROM "Halls"),(SELECT count(*) FROM "Seats"),(SELECT count(*) FROM "News"),(SELECT count(*) FROM "Promotions"),(SELECT count(*) FROM "AspNetUsers");'
    if ($taskCounts.Trim() -ne '36|5|506|3|3|1') { throw 'Неполное сидирование.' }
    $taskPaths = @(Test-Sql 'SELECT "PosterPath" FROM "Movies" UNION SELECT "PicturePath" FROM "Halls" UNION SELECT "ImagePath" FROM "News" UNION SELECT "ImagePath" FROM "Promotions";')
    foreach ($taskPath in $taskPaths) { $null = Invoke-WebRequest "$($taskScope.BaseUrl)/$($taskPath.TrimStart('/'))" -NoProxy -TimeoutSec 15 }
    foreach ($taskTest in @('Test-Catalog','Test-Cast','Test-DemoPromotions','Test-Authentication','Test-Sessions','Test-Admin','Test-TicketPurchases')) {
        if ($taskTest -in @('Test-Sessions','Test-TicketPurchases')) {
            & (Join-Path $PSScriptRoot "$taskTest.ps1") -BaseUrl $taskScope.BaseUrl -DemoCalendar
        } else {
            & (Join-Path $PSScriptRoot "$taskTest.ps1") -BaseUrl $taskScope.BaseUrl
        }
    }
    # Сохраняем реальную регистрацию и покупку через HTTP для проверки перезапуска.
    $taskClient = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    $taskEmail = 'persist-' + [Guid]::NewGuid().ToString('N') + '@example.invalid'
    $taskPassword = 'A1a' + [Guid]::NewGuid().ToString('N')
    Refresh-Token
    $null = Test-Post 'Account/Register' @{name='Проверка';lastName='Сохранности';email=$taskEmail;phoneNumber=('+79'+(Get-Random -Minimum 100000000 -Maximum 999999999));password=$taskPassword;confirmPassword=$taskPassword;isMan=$false}
    $null = Test-Post 'Account/Login' @{email=$taskEmail;password=$taskPassword;rememberMe=$true}
    Refresh-Token
    $taskZone = [TimeZoneInfo]::FindSystemTimeZoneById($(if ($IsWindows) { 'Russian Standard Time' } else { 'Europe/Moscow' }))
    $taskCalendar = Get-Content data/demo-calendar.json -Raw -Encoding utf8 | ConvertFrom-Json
    $taskTomorrow = [DateTime]::ParseExact($taskCalendar.dates[1],'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture).ToString('dd.MM.yyyy')
    $taskSession = @((Invoke-WebRequest "$($taskScope.BaseUrl)/Movies/GetAllSessions?date=$taskTomorrow" -NoProxy).Content | ConvertFrom-Json)[0]
    $taskSeat = [int](Test-Sql ('SELECT "Id" FROM "Seats" WHERE "HallId"={0} ORDER BY "Id" LIMIT 1;' -f [int]$taskSession.HallId))
    $taskOrder = (Test-Post 'orders/purchase' @{requestId=[Guid]::NewGuid();sessionId=$taskSession.Id;seatIds=@($taskSeat);viewerAge=30}).Content | ConvertFrom-Json
    $taskReceipt = Invoke-WebRequest "$($taskScope.BaseUrl)$($taskOrder.receiptUrl)" -WebSession $taskClient -NoProxy
    if ($taskReceipt.StatusCode -ne 200) { throw 'Билет недоступен.' }
    foreach ($taskHallName in @('Комфорт', 'Камерный')) {
        $taskNewSession = @((Invoke-WebRequest "$($taskScope.BaseUrl)/Movies/GetAllSessions?date=$taskTomorrow" -NoProxy).Content | ConvertFrom-Json | Where-Object HallName -eq $taskHallName)[0]
        if (!$taskNewSession) { throw "Нет сеанса нового зала: $taskHallName" }
        $taskHallData = @(Get-Content data/demo-halls.json -Raw -Encoding utf8 | ConvertFrom-Json | Where-Object name -eq $taskHallName)[0]
        $taskCheckout = Invoke-WebRequest "$($taskScope.BaseUrl)/orders/$($taskNewSession.Id)" -WebSession $taskClient -NoProxy
        if (!$taskCheckout.Content.Contains($taskHallData.picturePath) -or !([Net.WebUtility]::HtmlDecode($taskCheckout.Content)).Contains($taskHallName)) { throw 'Заказ не показывает информацию выбранного зала.' }
        $taskNewSeat = [int](Test-Sql ('SELECT "Id" FROM "Seats" WHERE "HallId"={0} ORDER BY "Id" LIMIT 1;' -f [int]$taskNewSession.HallId))
        $taskNewOrder = (Test-Post 'orders/purchase' @{requestId=[Guid]::NewGuid();sessionId=$taskNewSession.Id;seatIds=@($taskNewSeat);viewerAge=30}).Content | ConvertFrom-Json
        $taskNewReceipt = Invoke-WebRequest "$($taskScope.BaseUrl)$($taskNewOrder.receiptUrl)" -WebSession $taskClient -NoProxy
        if (!([Net.WebUtility]::HtmlDecode($taskNewReceipt.Content)).Contains($taskHallName)) { throw 'Новый зал не соответствует выданному билету.' }
    }
    $taskHallsPage = Invoke-WebRequest "$($taskScope.BaseUrl)/halls" -NoProxy
    if (!$taskHallsPage.Content.Contains('506')) { throw 'Не показана фактическая вместимость залов.' }
    # Администратор меняет карточку/цену места и удаляет новость: seed не должен отменить это.
    $taskEdit = @'
UPDATE "Movies" SET "Name"='Сохранённое название' WHERE "Id"=__MOVIE__;
-- Имитируем пользовательский состав до одноразового обновления старой базы.
DELETE FROM "DemoSeedRecords" WHERE "Key" LIKE 'cast:v1:%' AND "EntityId"=__MOVIE__;
UPDATE "Movies" SET "Actor"='Пользовательский состав: сохранить' WHERE "Id"=__MOVIE__;
UPDATE "Seats" SET "Price"=60 WHERE "Id"=__SEAT__;
DELETE FROM "News" WHERE "Id"=(SELECT "EntityId" FROM "DemoSeedRecords" WHERE "Key"='news:welcome');
UPDATE "Promotions" SET "Name"='DEMO-CINEMA-1990S', "DisplayName"='Сохранённая акция' WHERE "Id"=(SELECT "EntityId" FROM "DemoSeedRecords" WHERE "Key"='promotion:1990s');
-- Только тестовая БД: моделируем старую акцию без служебного ключа.
DELETE FROM "DemoSeedRecords" WHERE "Key"='promotion:1990s';
'@
    $null = Test-Sql ($taskEdit.Replace('__MOVIE__',[string]$taskSession.MovieId).Replace('__SEAT__',[string]$taskSeat))
    $taskSnapshotSql = @'
SELECT md5(jsonb_build_object(
'movies',(SELECT jsonb_agg(to_jsonb(m) ORDER BY "Id") FROM "Movies" m),
'users',(SELECT jsonb_agg(to_jsonb(u) ORDER BY "Id") FROM "AspNetUsers" u),
'orders',(SELECT jsonb_agg(to_jsonb(o) ORDER BY "Id") FROM "PurchaseOrders" o),
'tickets',(SELECT jsonb_agg(to_jsonb(t) ORDER BY "Id") FROM "Tickets" t),
'seats',(SELECT jsonb_agg(to_jsonb(s) ORDER BY "Id") FROM "Seats" s),
'news',(SELECT jsonb_agg(to_jsonb(n) ORDER BY "Id") FROM "News" n),
'promotions',(SELECT jsonb_agg(to_jsonb(p) ORDER BY "Id") FROM "Promotions" p),
'genres',(SELECT jsonb_agg(to_jsonb(g) ORDER BY "Id") FROM "Genres" g),
'halls',(SELECT jsonb_agg(to_jsonb(h) ORDER BY "Id") FROM "Halls" h),
'paidSession',(SELECT to_jsonb(s) FROM "Sessions" s WHERE "Id"=__SESSION__)
)::text);
'@
    $taskSnapshotSql = $taskSnapshotSql.Replace('__SESSION__',[string]$taskSession.Id)
    $taskBefore = Test-Sql $taskSnapshotSql
    docker compose up -d --wait --force-recreate initialize web *> (Join-Path $taskScope.Logs 'restart.log')
    if ($LASTEXITCODE) { throw 'Повторный запуск не прошёл.' }
    if ((Test-Sql $taskSnapshotSql) -ne $taskBefore) { throw 'Перезапуск изменил пользователя, билет или админские правки.' }
    $taskReceipt = Invoke-WebRequest "$($taskScope.BaseUrl)$($taskOrder.receiptUrl)" -WebSession $taskClient -NoProxy
    if ($taskReceipt.StatusCode -ne 200) { throw 'Cookie/билет не пережили перезапуск.' }
    if ($CheckScheduleRefresh) {
        $taskSlot = (Test-Sql @'
SELECT s."Id"||'|'||s."HallId"||'|'||to_char(s."DateStart",'YYYY-MM-DD"T"HH24:MI:SS') FROM "Sessions" s
WHERE NOT EXISTS (SELECT 1 FROM "Tickets" t WHERE t."SessionId"=s."Id")
AND NOT EXISTS (SELECT 1 FROM "PurchaseOrders" o WHERE o."SessionId"=s."Id")
ORDER BY s."DateStart" DESC,s."Id" LIMIT 1;
'@).Split('|')
        $taskSlotId = [int]$taskSlot[0]
        $taskSlotHall = [int]$taskSlot[1]
        $taskSlotDate = [DateTime]::ParseExact($taskSlot[2],'yyyy-MM-ddTHH:mm:ss',[Globalization.CultureInfo]::InvariantCulture).ToString('yyyy-MM-ddTHH:mm:ss')
        # Только disposable БД: моделируем ещё не заполненный слот, без билетов.
        $null = Test-Sql ("BEGIN; SELECT pg_advisory_xact_lock(726401991); DELETE FROM ""DemoSeedRecords"" WHERE ""Key"" LIKE 'session:%' AND ""EntityId""=$taskSlotId; DELETE FROM ""Sessions"" WHERE ""Id""=$taskSlotId; COMMIT;")
        $taskProbe = "SELECT count(*) FROM ""Sessions"" WHERE ""HallId""=$taskSlotHall AND ""DateStart""='$taskSlotDate';"
        $taskDeadline = [DateTime]::UtcNow.AddSeconds(100)
        $taskRefreshed = $false
        Write-Host 'Ожидание фонового пополнения пустого демослота без перезапуска.'
        while ([DateTime]::UtcNow -lt $taskDeadline) {
            if ([int](Test-Sql $taskProbe) -eq 1) { $taskRefreshed = $true; break }
            Start-Sleep -Milliseconds 1000
        }
        if (!$taskRefreshed) { throw 'Фоновое расписание не пополнилось.' }
        if ((Test-Sql $taskSnapshotSql) -ne $taskBefore) { throw 'Фоновое обновление изменило пользователей/билеты/правки.' }
        Write-Host 'Фоновый процесс пополнил расписание, сохранив купленный сеанс и остальные данные.'
    }
    $taskDuplicates = Test-Sql 'SELECT count(*) FROM (SELECT "HallId","DateStart" FROM "Sessions" GROUP BY "HallId","DateStart" HAVING count(*)>1) conflicts;'
    if ([int]$taskDuplicates -ne 0) { throw 'Сеансы продублированы.' }
    Write-Host 'Чистый Docker-запуск: каталог/места/сеансы/картинки, роли/админка, регистрация/покупка/билет и повтор с сохранением cookies/данных/правок прошли.'
    if ($UiHoldSeconds) {
        Write-Host "UI: $($taskScope.BaseUrl); остановка — $($taskScope.Logs)/stop.flag"
        $taskDeadline = [DateTime]::UtcNow.AddSeconds($UiHoldSeconds)
        while ([DateTime]::UtcNow -lt $taskDeadline -and !(Test-Path (Join-Path $taskScope.Logs 'stop.flag'))) { Start-Sleep -Milliseconds 500 }
    }
} finally {
    try { if ($taskScope) { Remove-CinemaDockerTestEnvironment $taskScope } }
    finally { Pop-Location }
}
