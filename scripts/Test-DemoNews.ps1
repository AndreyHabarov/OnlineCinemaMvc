[CmdletBinding()]
param([string]$BaseUrl='http://127.0.0.1:5175')
$ErrorActionPreference='Stop'
$taskItems=Get-Content (Join-Path $PSScriptRoot '../data/demo-news.json') -Raw -Encoding utf8 | ConvertFrom-Json
$taskHtml=(Invoke-WebRequest "$BaseUrl/news" -NoProxy -TimeoutSec 20).Content
if([regex]::Matches($taskHtml,'class="card news-card"').Count -ne 3){throw 'Нужны три новости.'}
foreach($taskItem in $taskItems){
    $taskDecoded=[Net.WebUtility]::HtmlDecode($taskHtml)
    $taskLink=[regex]::Match($taskDecoded,'href="(/news/\d+)"[^>]*>'+[regex]::Escape($taskItem.Name)+'</a>').Groups[1].Value
    if(!$taskLink){throw 'Нет ссылки с названия статьи.'}
    $taskDetails=(Invoke-WebRequest "$BaseUrl$taskLink" -NoProxy -TimeoutSec 20).Content
    $taskDetailsDecoded=[Net.WebUtility]::HtmlDecode($taskDetails)
    if(!$taskDetailsDecoded.Contains('Из истории кино') -or !$taskDetailsDecoded.Contains($taskItem.Description) -or !$taskDetails.Contains($taskItem.SourceUrl)){throw 'Статья или источник не соответствует.'}
    $taskMovie=[regex]::Match($taskDetails,'href="(/movies/\d+)"').Groups[1].Value
    if(!$taskMovie){throw 'Нет перехода к фильму.'}
    $null=Invoke-WebRequest "$BaseUrl$taskMovie" -NoProxy -TimeoutSec 20
    $taskImage=Invoke-WebRequest "$BaseUrl$($taskItem.ImagePath)" -NoProxy -TimeoutSec 20
    if($taskImage.Headers.'Content-Type' -notmatch '^image/'){throw 'Иллюстрация отсутствует.'}
}
Write-Host 'Три новости: статьи, источники фактов, иллюстрации и переходы к фильмам проверены.'
