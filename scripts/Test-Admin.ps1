[CmdletBinding()]
param([ValidatePattern('^https?://(localhost|127\.0\.0\.1)(:\d+)?/?$')][string]$BaseUrl = 'http://127.0.0.1:5175')

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot
$taskSuffix = [Guid]::NewGuid().ToString('N')
$taskEmail = "codex-admin-check-$taskSuffix@example.invalid"
$taskDuplicateEmail = "codex-auth-duplicate-$taskSuffix@example.invalid"
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
    $script:taskDbUser = [string]$taskCompose.services.db.environment.POSTGRES_USER
    $script:taskDbName = [string]$taskCompose.services.db.environment.POSTGRES_DB
    Refresh-Token
    $taskRegistration = @{name='Проверка';lastName='Админки';phoneNumber=$taskPhone;email=$taskEmail;password=$taskPassword;confirmPassword=$taskPassword}
    Assert-Status (Send-Account 'Register' $taskRegistration) 200 'Регистрация проверочного пользователя'
    Run-TestSql ('INSERT INTO "AspNetUserRoles" ("UserId","RoleId") SELECT u."Id",r."Id" FROM "AspNetUsers" u CROSS JOIN "AspNetRoles" r WHERE u."Email"='''+$taskEmail+''' AND r."Name"=''admin'';')
    Assert-Status (Send-Account 'Login' @{email=$taskEmail;password=$taskPassword}) 200 'Вход администратора'
    Refresh-Token
    $taskHeaders=@{Accept='application/json';'X-CSRF-TOKEN'=$script:taskToken}
    function Send-Admin([string]$Path,[string]$Method,$Data) {
        Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method $Method -ContentType 'application/json' -Body ($Data|ConvertTo-Json) "$BaseUrl/Admin/$Path"
    }
    $taskGenreName='Проверка-'+$taskSuffix
    Assert-Status (Send-Admin 'Genres/Create' Post @{name=''}) 400 'Пустое имя жанра'
    $taskResponse=Send-Admin 'Genres/Create' Post @{name=$taskGenreName}
    Assert-Status $taskResponse 200 'Создание жанра'
    $taskGenreId=($taskResponse.Content|ConvertFrom-Json).id
    Assert-Status (Send-Admin 'Genres/Create' Post @{name=$taskGenreName.ToUpper()}) 409 'Дубль жанра без учёта регистра'
    Assert-Status (Send-Admin 'Genres/GetAll' Post @{skipCount=-1;pageSize=10}) 400 'Неверная пагинация'
    Assert-Status (Send-Admin 'Genres/GetAll' Post @{skipCount=0;pageSize=101}) 400 'Слишком большая страница'
    $taskSearch=(Send-Admin 'Genres/GetAll' Post @{skipCount=0;pageSize=10;keyword=$taskSuffix}).Content|ConvertFrom-Json
    if($taskSearch.filteredCount -ne 1 -or $taskSearch.totalCount -lt 12){throw 'Неверный поиск жанров'}
    $taskUsedGenre=1
    Assert-Status (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Delete "$BaseUrl/Admin/Genres/Delete?id=$taskUsedGenre") 409 'Удаление связанного жанра'
    Assert-Status (Send-Admin 'Genres/Update' Put @{id=$taskGenreId;name=$taskGenreName+'-изменён'}) 200 'Изменение жанра'
    Assert-Status (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Delete "$BaseUrl/Admin/Genres/Delete?id=$taskGenreId") 200 'Удаление своего проверочного жанра'
    $taskPromoName='codex-admin-'+$taskSuffix
    $taskForm=@{Name=$taskPromoName;DisplayName='Проверочная акция';Description='Русское описание';DateTime='2026-10-11';ButtonText='Подробнее';Link='/kids';Image=Get-Item OnlineCinema.Mvc/wwwroot/images/movies/1990s/the-matrix.png}
    $taskResponse=Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Post -Form $taskForm "$BaseUrl/Admin/Promotions/Create"
    Assert-Status $taskResponse 200 'Создание акции с PNG'
    $taskPromoId=($taskResponse.Content|ConvertFrom-Json).id
    $taskPromo=Invoke-RestMethod -NoProxy -WebSession $taskClient "$BaseUrl/Admin/Promotions/Get?id=$taskPromoId"
    Assert-Status (Invoke-WebRequest -NoProxy "$BaseUrl/$($taskPromo.imagePath)") 200 'Изображение новой акции'
    $taskOldPath=$taskPromo.imagePath
    $taskForm.Id=$taskPromoId
    $taskForm.Remove('Image')
    $taskForm.DisplayName='Изменённая акция'
    Assert-Status (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Put -Form $taskForm "$BaseUrl/Admin/Promotions/Update") 200 'Редактирование без изображения'
    $taskPromo=Invoke-RestMethod -NoProxy -WebSession $taskClient "$BaseUrl/Admin/Promotions/Get?id=$taskPromoId"
    if($taskPromo.imagePath -ne $taskOldPath -or $taskPromo.displayName -ne 'Изменённая акция'){throw 'Редактирование не сохранилось'}
    $taskForm.Link='javascript:alert(1)'
    Assert-Status (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Put -Form $taskForm "$BaseUrl/Admin/Promotions/Update") 400 'Недопустимая ссылка'
    $taskForm.Link='/kids'
    'Это не изображение' | Set-Content backups/invalid-promotion.txt
    $taskForm.Image=Get-Item backups/invalid-promotion.txt
    Assert-Status (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Put -Form $taskForm "$BaseUrl/Admin/Promotions/Update") 400 'Неверный формат изображения'
    Assert-Status (Invoke-WebRequest -NoProxy "$BaseUrl/$taskOldPath") 200 'Старое изображение сохранилось после отказа'
    $taskForm.Image=Get-Item OnlineCinema.Mvc/wwwroot/images/movies/1990s/forrest-gump.jpg
    Assert-Status (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Put -Form $taskForm "$BaseUrl/Admin/Promotions/Update") 200 'Замена изображения'
    Assert-Status (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck "$BaseUrl/$taskOldPath") 404 'Старый управляемый файл удалён'
    $taskPromo=Invoke-RestMethod -NoProxy -WebSession $taskClient "$BaseUrl/Admin/Promotions/Get?id=$taskPromoId"
    $taskFinalPath=$taskPromo.imagePath
    Assert-Status (Invoke-WebRequest -NoProxy "$BaseUrl/promotions/$taskPromoName") 200 'Публичная страница акции'
    Assert-Status (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Delete "$BaseUrl/Admin/Promotions/Delete?id=$taskPromoId") 200 'Удаление своей проверочной акции'
    Assert-Status (Invoke-WebRequest -NoProxy -SkipHttpErrorCheck "$BaseUrl/$taskFinalPath") 404 'Файл удалённой акции убран'
    Write-Host 'Проверены CRUD жанров/акций, дубли, связанные жанры, пагинация, поиск, multipart, ссылки и безопасная замена изображений.'
} finally {
    if($taskPromoId){
        Invoke-WebRequest -NoProxy -SkipHttpErrorCheck -WebSession $taskClient -Headers $taskHeaders -Method Delete "$BaseUrl/Admin/Promotions/Delete?id=$taskPromoId" | Out-Null
    }
    if($script:taskDbUser -and $script:taskDbName){
        Run-TestSql ('DELETE FROM "Genres" WHERE "Name" LIKE ''Проверка-'+$taskSuffix+'%''; DELETE FROM "AspNetUsers" WHERE "Email"='''+$taskEmail+''';')
    }
    Pop-Location
}
