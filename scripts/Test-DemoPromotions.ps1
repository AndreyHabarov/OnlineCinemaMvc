[CmdletBinding()]
param([string]$BaseUrl='http://127.0.0.1:5175')
$ErrorActionPreference='Stop'
$taskItems=Get-Content (Join-Path $PSScriptRoot '../data/demo-promotions.json') -Raw -Encoding utf8 | ConvertFrom-Json
foreach($taskPath in @('/','/promotions')) {
    $taskHtml=(Invoke-WebRequest "$BaseUrl$taskPath" -NoProxy -TimeoutSec 20).Content
    if([regex]::Matches($taskHtml,'class="promotion-card"').Count -ne 3){throw 'Нужны три карточки предложений.'}
    foreach($taskItem in $taskItems){if(!$taskHtml.Contains('/promotions/'+$taskItem.Name)){throw 'Карточка не открывает подробности.'}}
}
foreach($taskItem in $taskItems){
    $taskHtml=(Invoke-WebRequest "$BaseUrl/promotions/$($taskItem.Name)" -NoProxy -TimeoutSec 20).Content
    if(!([Net.WebUtility]::HtmlDecode($taskHtml)).Contains($taskItem.DisplayName) -or !$taskHtml.Contains($taskItem.ImagePath)){throw 'Страница предложения не соответствует карточке.'}
    $taskTag=[regex]::Match($taskHtml,'<a[^>]*class="btn btn-primary"[^>]*>').Value
    $taskLink=[Net.WebUtility]::HtmlDecode([regex]::Match($taskTag,'href="([^"]+)"').Groups[1].Value)
    if(!$taskLink.StartsWith('/') -or $taskLink.StartsWith('//')){throw 'Нет внутреннего перехода к выбору.'}
    $null=Invoke-WebRequest "$BaseUrl$taskLink" -NoProxy -TimeoutSec 20
    $taskImage=Invoke-WebRequest "$BaseUrl$($taskItem.ImagePath)" -NoProxy -TimeoutSec 20
    if($taskImage.Headers.'Content-Type' -notmatch '^image/'){throw 'Иллюстрация недоступна.'}
    if([Net.WebUtility]::HtmlDecode($taskHtml) -notmatch 'Дополнительные скидки не применяются'){throw 'Цена предложения не объяснена.'}
}
Write-Host 'Три предложения: карточки и подробности, внутренние переходы, отдельные иллюстрации и обычная цена сеанса проверены.'
