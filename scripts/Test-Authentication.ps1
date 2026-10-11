[CmdletBinding()]
param([ValidatePattern('^https?://(localhost|127\.0\.0\.1)(:\d+)?/?$')][string]$BaseUrl = 'http://127.0.0.1:5175')

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot
$taskSuffix = [Guid]::NewGuid().ToString('N')
$taskEmail = "codex-auth-check-$taskSuffix@example.invalid"
$taskDuplicateEmail = "codex-auth-duplicate-$taskSuffix@example.invalid"
$taskRaceEmails = @("codex-auth-race-a-$taskSuffix@example.invalid", "codex-auth-race-b-$taskSuffix@example.invalid")
$taskPassword = 'A1a' + [Guid]::NewGuid().ToString('N')
$taskPhone = '+79' + (Get-Random -Minimum 100000000 -Maximum 999999999)
$taskClient = [Microsoft.PowerShell.Commands.WebRequestSession]::new()

function Refresh-Token {
    $taskPage = Invoke-WebRequest -NoProxy -TimeoutSec 20 -WebSession $taskClient $BaseUrl
    $script:taskToken = [regex]::Match($taskPage.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
    if (!$script:taskToken) { throw 'Нет CSRF-токена страницы.' }
}
function Send-Account([string]$Action, $Body, [bool]$Token = $true) {
    $taskHeaders = @{ Accept = 'application/json' }
    if ($Token) { $taskHeaders['X-CSRF-TOKEN'] = $script:taskToken }
    Invoke-WebRequest -NoProxy -TimeoutSec 20 -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Post -ContentType 'application/json' -Body ($Body | ConvertTo-Json) "$BaseUrl/Account/$Action"
}
function Assert-Status($Response, [int]$Expected, [string]$Scenario) {
    if ($Response.StatusCode -ne $Expected) { throw "$Scenario : ожидался $Expected, получен $($Response.StatusCode)" }
}
function Run-TestSql([string]$Sql) {
    $taskResult = $Sql | docker compose exec -T db psql -X -U $script:taskDbUser -d $script:taskDbName -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) { throw 'Ошибка подготовки/очистки тестовой учётной записи.' }
}

try {
    $taskCompose = (docker compose config --format json | Out-String | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0) { throw 'Недоступен Docker Compose.' }
    $script:taskDbUser = [string]$taskCompose.services.db.environment.POSTGRES_USER
    $script:taskDbName = [string]$taskCompose.services.db.environment.POSTGRES_DB
    Refresh-Token
    $taskCredentials = @{ email = $taskEmail; password = $taskPassword; rememberMe = $false }
    Assert-Status (Send-Account 'Login' $taskCredentials $false) 400 'CSRF без токена'
    Assert-Status (Send-Account 'Login' $taskCredentials) 401 'Неизвестный email'
    Assert-Status (Send-Account 'Login' @{ password = $taskPassword }) 400 'Нет способа входа'
    $taskRegistration = @{ name = 'Проверка'; lastName = 'Авторизации'; phoneNumber = $taskPhone; email = $taskEmail; password = $taskPassword; confirmPassword = 'mismatch' }
    Assert-Status (Send-Account 'Register' $taskRegistration) 400 'Пароли не совпадают'
    $taskRegistration.confirmPassword = $taskPassword
    Assert-Status (Send-Account 'Register' $taskRegistration) 200 'Регистрация'
    Assert-Status (Send-Account 'Register' $taskRegistration) 400 'Повторная регистрация'
    $taskLogin = Send-Account 'Login' $taskCredentials
    Assert-Status $taskLogin 200 'Вход по email'
    if (($taskLogin.Headers['Set-Cookie'] -join ';') -match 'Identity.Application=[^;]+;[^\r\n]*expires=') { throw 'Без RememberMe cookie стала постоянной.' }
    Refresh-Token
    $taskAccount = Invoke-WebRequest -NoProxy -WebSession $taskClient -SkipHttpErrorCheck "$BaseUrl/lk"
    Assert-Status $taskAccount 200 'Личный кабинет'
    $taskDenied = Invoke-WebRequest -NoProxy -WebSession $taskClient -Headers @{Accept='application/json'} -SkipHttpErrorCheck "$BaseUrl/Admin/Genres"
    Assert-Status $taskDenied 403 'Доступ обычного пользователя к админке'
    Assert-Status (Send-Account 'LogOut' @{} $false) 400 'CSRF выхода'
    Assert-Status (Send-Account 'LogOut' @{}) 200 'Выход'
    Refresh-Token
    $taskPhoneInput = '8 (' + $taskPhone.Substring(2,3) + ') ' + $taskPhone.Substring(5,3) + '-' + $taskPhone.Substring(8,2) + '-' + $taskPhone.Substring(10,2)
    $taskLogin = Send-Account 'Login' @{ phone = $taskPhoneInput; password = $taskPassword; rememberMe = $true }
    Assert-Status $taskLogin 200 'Вход по форматированному телефону'
    if (($taskLogin.Headers['Set-Cookie'] -join ';') -notmatch 'Identity.Application=[^;]+;[^\r\n]*expires=') { throw 'RememberMe не создаёт постоянную cookie.' }
    Refresh-Token
    Assert-Status (Send-Account 'LogOut' @{}) 200 'Выход после телефона'
    Refresh-Token
    $taskDuplicateSql = @'
DO $$ DECLARE collision text; BEGIN
 BEGIN
  INSERT INTO "AspNetUsers" ("Name","LastName","IsMan","UserName","NormalizedUserName","Email","NormalizedEmail","EmailConfirmed","PasswordHash","SecurityStamp","ConcurrencyStamp","PhoneNumber","PhoneNumberConfirmed","TwoFactorEnabled","LockoutEnabled","AccessFailedCount")
  SELECT "Name","LastName","IsMan",'__DUPLICATE__',upper('__DUPLICATE__'),'__DUPLICATE__',upper('__DUPLICATE__'),false,"PasswordHash","SecurityStamp","ConcurrencyStamp",'8'||substring(regexp_replace("PhoneNumber", '[^0-9]', '', 'g') from 2),false,false,true,0
  FROM "AspNetUsers" WHERE "Email"='__ORIGINAL__';
  RAISE EXCEPTION 'Повторный нормализованный телефон ошибочно сохранён';
 EXCEPTION WHEN unique_violation THEN
  GET STACKED DIAGNOSTICS collision = CONSTRAINT_NAME;
  IF collision <> 'IX_AspNetUsers_NormalizedPhoneNumber' THEN RAISE; END IF;
 END;
END $$;
'@
    Run-TestSql ($taskDuplicateSql.Replace('__DUPLICATE__', $taskDuplicateEmail).Replace('__ORIGINAL__', $taskEmail))
    $taskDuplicateRegistration = $taskRegistration.Clone()
    $taskDuplicateRegistration.email = $taskDuplicateEmail
    $taskDuplicateRegistration.phoneNumber = $taskPhoneInput
    Assert-Status (Send-Account 'Register' $taskDuplicateRegistration) 400 'Повторный телефон в другом формате'
    $taskRacePhone = '+79' + (Get-Random -Minimum 100000000 -Maximum 999999999)
    $taskHandler = [Net.Http.HttpClientHandler]::new()
    $taskHandler.CookieContainer = $taskClient.Cookies
    $taskHttp = [Net.Http.HttpClient]::new($taskHandler)
    $taskHttp.Timeout = [TimeSpan]::FromSeconds(30)
    $taskHttp.DefaultRequestHeaders.Add('X-CSRF-TOKEN', $script:taskToken)
    $taskContents = @()
    $taskReplies = @()
    try {
        $taskPending = foreach ($taskIndex in 0..1) {
            $taskBody = $taskRegistration.Clone()
            $taskBody.email = $taskRaceEmails[$taskIndex]
            $taskBody.phoneNumber = if ($taskIndex -eq 0) { $taskRacePhone } else { '8' + $taskRacePhone.Substring(2) }
            $taskContent = [Net.Http.StringContent]::new(($taskBody | ConvertTo-Json), [Text.Encoding]::UTF8, 'application/json')
            $taskContents += $taskContent
            $taskHttp.PostAsync("$BaseUrl/Account/Register", $taskContent)
        }
        $taskReplies = @($taskPending | ForEach-Object { $_.GetAwaiter().GetResult() })
        if ((@($taskReplies | ForEach-Object { [int]$_.StatusCode } | Sort-Object) -join ',') -ne '200,400') {
            throw 'Параллельная регистрация одного телефона должна дать один успех и один отказ.'
        }
    } finally {
        $taskReplies | ForEach-Object { $_.Dispose() }
        $taskContents | ForEach-Object { $_.Dispose() }
        $taskHttp.Dispose()
    }
    $taskWrong = @{ email = $taskEmail; password = 'wrong' }
    for ($taskAttempt = 0; $taskAttempt -lt 5; $taskAttempt++) { Assert-Status (Send-Account 'Login' $taskWrong) 401 'Неверный пароль' }
    Assert-Status (Send-Account 'Login' $taskCredentials) 401 'Блокировка после пяти попыток'
    Run-TestSql ('UPDATE "AspNetUsers" SET "AccessFailedCount"=0, "LockoutEnd"=NULL WHERE "Email"='''+$taskEmail+'''; INSERT INTO "AspNetUserRoles" ("UserId","RoleId") SELECT u."Id",r."Id" FROM "AspNetUsers" u CROSS JOIN "AspNetRoles" r WHERE u."Email"='''+$taskEmail+''' AND r."Name"=''admin'';')
    Assert-Status (Send-Account 'Login' $taskCredentials) 200 'Вход проверочного администратора'
    Refresh-Token
    Assert-Status (Invoke-WebRequest -NoProxy -WebSession $taskClient -SkipHttpErrorCheck "$BaseUrl/Admin/Genres") 200 'Доступ администратора'
    $taskAdminRequest = @{ NoProxy=$true; WebSession=$taskClient; SkipHttpErrorCheck=$true; Method='Post'; ContentType='application/json'; Body='{"skipCount":0,"pageSize":10}' }
    Assert-Status (Invoke-WebRequest @taskAdminRequest -Headers @{Accept='application/json'} "$BaseUrl/Admin/Genres/GetAll") 400 'CSRF админки без токена'
    Assert-Status (Invoke-WebRequest @taskAdminRequest -Headers @{Accept='application/json'; 'X-CSRF-TOKEN'=$script:taskToken} "$BaseUrl/Admin/Genres/GetAll") 200 'Запрос админки с токеном'
    Assert-Status (Send-Account 'LogOut' @{}) 200 'Выход администратора'
    Refresh-Token
    Assert-Status (Invoke-WebRequest -NoProxy -WebSession $taskClient -Headers @{Accept='application/json'} -SkipHttpErrorCheck "$BaseUrl/lk") 401 'Гость в личном кабинете'
    $taskGuest = Invoke-WebRequest -NoProxy -WebSession $taskClient -Headers @{Accept='text/html'} "$BaseUrl/lk"
    if ($taskGuest.BaseResponse.RequestMessage.RequestUri.Query -notmatch 'login=') { throw 'Гостю не открывается форма входа.' }
    Write-Host 'Проверены регистрация, уникальность телефона в БД и при параллельных запросах, валидация, вход по email/телефону, RememberMe, выход, блокировка, CSRF и роли.'
} finally {
    if ($script:taskDbUser -and $script:taskDbName) {
        $taskOwnEmails = @($taskEmail, $taskDuplicateEmail) + $taskRaceEmails
        Run-TestSql ('DELETE FROM "AspNetUsers" WHERE "Email" IN (' + (($taskOwnEmails | ForEach-Object { "'$_'" }) -join ',') + ');')
    }
    Pop-Location
}
