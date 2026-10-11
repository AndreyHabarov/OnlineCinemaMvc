[CmdletBinding()]
param([ValidatePattern('^https?://(localhost|127\.0\.0\.1)(:\d+)?/?$')][string]$BaseUrl = 'http://127.0.0.1:5175')
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
$taskSuffix = [Guid]::NewGuid().ToString('N')
$taskEmails = @("purchase-a-$taskSuffix@example.invalid", "purchase-b-$taskSuffix@example.invalid")
$taskClients = @()
$taskSessionIds = @()
function Sql([string]$Query) {
    $taskOutput = $Query | docker compose exec -T db psql -X -At -U $taskDbUser -d $taskDbName -v ON_ERROR_STOP=1
    if ($LASTEXITCODE) { throw 'Ошибка SQL проверки билетов.' }
    return $taskOutput
}
function Expect($Response, [int]$Code, [string]$Scenario) {
    if ([int]$Response.StatusCode -ne $Code) { throw "$Scenario : ожидался $Code, получен $($Response.StatusCode): $($Response.Content)" }
}
function Post($Client, [string]$Path, $Body, [bool]$WithToken = $true) {
    $taskHeaders = @{Accept='application/json'}
    if ($WithToken) { $taskHeaders['X-CSRF-TOKEN'] = $Client.Token }
    Invoke-WebRequest -NoProxy -TimeoutSec 30 -SkipHttpErrorCheck -WebSession $Client.Session -Headers $taskHeaders -Method Post -ContentType 'application/json' -Body ($Body|ConvertTo-Json -Depth 8) "$BaseUrl/$Path"
}
function Body([int[]]$Seats, [Guid]$Key = [Guid]::NewGuid()) {
    @{requestId=$Key;sessionId=$taskFuture;seatIds=$Seats;viewerAge=30;price=1;total=1}
}
function Parallel-Purchase($ClientA, $BodyA, $ClientB, $BodyB) {
    $taskHttpClients = @(); $taskRequests = @(); $taskPending = @()
    try {
        foreach ($taskPair in @(@($ClientA,$BodyA),@($ClientB,$BodyB))) {
            $taskHandler = [System.Net.Http.HttpClientHandler]::new()
            $taskHandler.UseProxy = $false
            $taskHandler.CookieContainer = $taskPair[0].Session.Cookies
            $taskHttp = [System.Net.Http.HttpClient]::new($taskHandler)
            $taskHttpClients += $taskHttp
            $taskRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, "$BaseUrl/orders/purchase")
            $taskRequests += $taskRequest
            $taskRequest.Headers.Add('Accept','application/json')
            $taskRequest.Headers.Add('X-CSRF-TOKEN',$taskPair[0].Token)
            $taskRequest.Content = [System.Net.Http.StringContent]::new(($taskPair[1]|ConvertTo-Json -Depth 8),[Text.Encoding]::UTF8,'application/json')
            $taskPending += $taskHttp.SendAsync($taskRequest)
        }
        foreach ($taskPendingRequest in $taskPending) {
            $taskResponse = $taskPendingRequest.GetAwaiter().GetResult()
            @{StatusCode=[int]$taskResponse.StatusCode;Content=$taskResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()}
            $taskResponse.Dispose()
        }
    } finally {
        foreach ($taskRequest in $taskRequests) { $taskRequest.Dispose() }
        foreach ($taskHttp in $taskHttpClients) { $taskHttp.Dispose() }
    }
}
try {
    $taskConfig = docker compose config --format json | Out-String | ConvertFrom-Json
    $taskDbUser = $taskConfig.services.db.environment.POSTGRES_USER
    $taskDbName = $taskConfig.services.db.environment.POSTGRES_DB
    foreach ($taskEmail in $taskEmails) {
        $taskClient = @{Session=[Microsoft.PowerShell.Commands.WebRequestSession]::new();Token=''}
        $taskPage = Invoke-WebRequest -NoProxy -WebSession $taskClient.Session $BaseUrl
        $taskClient.Token = [regex]::Match($taskPage.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
        $taskPassword = 'A1a'+[Guid]::NewGuid().ToString('N')
        Expect (Post $taskClient 'Account/Register' @{name='Проверка';lastName='Билетов';email=$taskEmail;phoneNumber=('+79'+(Get-Random -Minimum 100000000 -Maximum 999999999));password=$taskPassword;confirmPassword=$taskPassword}) 200 'Регистрация'
        Expect (Post $taskClient 'Account/Login' @{email=$taskEmail;password=$taskPassword}) 200 'Вход'
        $taskPage = Invoke-WebRequest -NoProxy -WebSession $taskClient.Session $BaseUrl
        $taskClient.Token = [regex]::Match($taskPage.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
        $taskClients += $taskClient
    }
    $taskMovie = [int](Sql 'SELECT "Id" FROM "Movies" WHERE "IsVisible" AND "AgeRating">0 ORDER BY "Id" LIMIT 1;')
    $taskHall = [int](Sql 'SELECT "HallId" FROM "Seats" GROUP BY "HallId" HAVING count(*)>=8 ORDER BY "HallId" LIMIT 1;')
    $taskSeats = @((Sql "SELECT `"Id`" FROM `"Seats`" WHERE `"HallId`"=$taskHall ORDER BY `"Row`",`"Number`" LIMIT 8;") | ForEach-Object {[int]$_})
    $taskForeign = [int](Sql "SELECT `"Id`" FROM `"Seats`" WHERE `"HallId`"<>$taskHall LIMIT 1;")
    foreach ($taskDays in @(30,-30)) {
        $taskId = [int]((Sql "INSERT INTO `"Sessions`" (`"DateStart`",`"Price`",`"MovieId`",`"HallId`") VALUES (timezone('Europe/Moscow',now())+interval '$taskDays days',350,$taskMovie,$taskHall) RETURNING `"Id`";") | Select-Object -First 1)
        $taskSessionIds += $taskId
    }
    $taskFuture=$taskSessionIds[0]; $taskPast=$taskSessionIds[1]
    $taskA=$taskClients[0]; $taskB=$taskClients[1]
    Expect (Post $taskA 'orders/purchase' (Body @($taskSeats[0])) $false) 400 'CSRF'
    foreach ($taskBadSeats in @(@(),@(0),@($taskSeats[0],$taskSeats[0]),@($taskForeign),$taskSeats[0..6])) {
        Expect (Post $taskA 'orders/purchase' (Body $taskBadSeats)) 400 'Неверные места'
    }
    $taskBody=Body @($taskSeats[0]);$taskBody.requestId=[Guid]::Empty
    Expect (Post $taskA 'orders/purchase' $taskBody) 400 'Пустой ключ запроса'
    $taskBody=Body @($taskSeats[0]);$taskBody.viewerAge=0
    Expect (Post $taskA 'orders/purchase' $taskBody) 400 'Возраст'
    $taskBody=Body @($taskSeats[0]);$taskBody.sessionId=$taskPast
    Expect (Post $taskA 'orders/purchase' $taskBody) 400 'Прошедший сеанс'
    $taskBody.sessionId=[int]::MaxValue
    Expect (Post $taskA 'orders/purchase' $taskBody) 400 'Отсутствующий сеанс'
    $taskGuest=@{Session=[Microsoft.PowerShell.Commands.WebRequestSession]::new();Token=''}
    Expect (Post $taskGuest 'orders/purchase' (Body @($taskSeats[0]))) 401 'Покупка гостя'
    $taskRace=@(Parallel-Purchase $taskA (Body @($taskSeats[0])) $taskB (Body @($taskSeats[0])))
    if ((($taskRace.StatusCode|Sort-Object) -join ',') -ne '200,409') { throw "Конкурентная покупка: $($taskRace|ConvertTo-Json)" }
    $taskWinner=if($taskRace[0].StatusCode -eq 200){$taskA}else{$taskB}
    $taskOther=if($taskRace[0].StatusCode -eq 200){$taskB}else{$taskA}
    $taskReceipt=($taskRace|Where-Object StatusCode -eq 200).Content|ConvertFrom-Json
    Expect (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskWinner.Session "$BaseUrl$($taskReceipt.receiptUrl)") 200 'Билет владельца'
    Expect (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskOther.Session "$BaseUrl$($taskReceipt.receiptUrl)") 404 'Чужой билет'
    $taskBody=Body @($taskSeats[1],$taskSeats[2])
    $taskRepeated=@(Parallel-Purchase $taskA $taskBody $taskA $taskBody)
    foreach($taskResponse in $taskRepeated){Expect $taskResponse 200 'Повтор параллельного запроса'}
    if (($taskRepeated[0].Content|ConvertFrom-Json).orderId -ne ($taskRepeated[1].Content|ConvertFrom-Json).orderId) {throw 'Повтор создал другой заказ'}
    Expect (Post $taskA 'orders/purchase' $taskBody) 200 'Последующий повтор'
    $taskBody.seatIds=@($taskSeats[3])
    Expect (Post $taskA 'orders/purchase' $taskBody) 409 'Ключ использован для другого заказа'
    Expect (Post $taskA 'orders/purchase' (Body @($taskSeats[0],$taskSeats[3]))) 409 'Откат заказа с занятым местом'
    $taskCounts=(Sql "SELECT count(*),sum(`"Price`") FROM `"Tickets`" WHERE `"SessionId`"=$taskFuture;")
    if ($taskCounts -ne '3|1050') {throw "Дубли или подмена серверной цены: $taskCounts"}
    if ((Sql "SELECT count(*) FROM `"PurchaseOrders`" WHERE `"SessionId`"=$taskFuture;") -ne '2') {throw 'Лишние заказы'}
    if ((Sql ("SELECT count(*) FROM `"Customers`" WHERE `"Email`" IN ('"+($taskEmails -join "','")+"');")) -ne '2') {throw 'Не откатилась запись покупателя'}
    $taskDashboard=Invoke-WebRequest -NoProxy -WebSession $taskWinner.Session "$BaseUrl/lk"
    if (!$taskDashboard.Content.Contains([string]$taskReceipt.orderId)) {throw 'Билет отсутствует в личном кабинете'}
    Write-Host 'Проверены цена, места, возраст, CSRF, права владельца, атомарность, одновременная покупка и идемпотентность.'
} finally {
    if($taskDbUser -and $taskDbName){
        $taskEmailList="'"+($taskEmails -join "','")+"'"
        Sql "DELETE FROM `"PurchaseOrders`" WHERE `"UserId`" IN (SELECT `"Id`" FROM `"AspNetUsers`" WHERE `"Email`" IN ($taskEmailList)); DELETE FROM `"Customers`" WHERE `"Email`" IN ($taskEmailList); DELETE FROM `"AspNetUsers`" WHERE `"Email`" IN ($taskEmailList);" | Out-Null
        if($taskSessionIds.Count){Sql "DELETE FROM `"Sessions`" WHERE `"Id`" IN ($($taskSessionIds -join ','));"|Out-Null}
    }
    Pop-Location
}
