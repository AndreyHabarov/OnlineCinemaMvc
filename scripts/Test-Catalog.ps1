[CmdletBinding()]
param([string]$BaseUrl = 'http://127.0.0.1:5175')
$ErrorActionPreference = 'Stop'
function Get-Catalog([string]$Query) {
    (Invoke-WebRequest "$BaseUrl/$Query" -NoProxy -TimeoutSec 20).Content
}
function Get-CatalogIds([string]$Html) {
    @([regex]::Matches($Html,'<article class="movie-card">\s*<a href="/movies/(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value })
}
$taskIds = @()
foreach ($taskPage in 1..3) {
    $taskHtml = Get-Catalog "?page=$taskPage"
    $taskPageIds = @(Get-CatalogIds $taskHtml)
    if ($taskPageIds.Count -ne 12) { throw "На странице $taskPage должны быть 12 фильмов." }
    $taskIds += $taskPageIds
}
if (@($taskIds | Sort-Object -Unique).Count -ne 36) { throw 'Страницы дублируют или теряют фильмы.' }
foreach ($taskSearch in @('мАтРиЦа','The Matrix')) {
    $taskHtml = Get-Catalog ('?search='+[uri]::EscapeDataString($taskSearch))
    if (@(Get-CatalogIds $taskHtml).Count -ne 1) { throw 'Поиск русского/оригинального названия не работает.' }
}
foreach ($taskQuery in @('?search=%25','?search=absent-movie-unique-1990s','?genreId=2147483647')) {
    $taskHtml = Get-Catalog $taskQuery
    if (@(Get-CatalogIds $taskHtml).Count -ne 0 -or [Net.WebUtility]::HtmlDecode($taskHtml) -notmatch 'Ничего не найдено') { throw 'Неверная пустая выдача.' }
}
$taskHtml = Get-Catalog ''
$taskDrama = [regex]::Match([Net.WebUtility]::HtmlDecode($taskHtml),'<option value="(\d+)"[^>]*>Драма</option>').Groups[1].Value
if (!$taskDrama) { throw 'Не показан доступный жанр.' }
$taskHtml = Get-Catalog "?genreId=$taskDrama"
if (@(Get-CatalogIds $taskHtml).Count -eq 0 -or $taskHtml -notmatch "genreId=$taskDrama") { throw 'Жанр или сохранение фильтра в пагинации не работает.' }
$taskHtml = Get-Catalog '?page=999'
if (@(Get-CatalogIds $taskHtml).Count -ne 12 -or $taskHtml -notmatch 'aria-current="page"[^>]*aria-label="[^"<>]*3"') { throw 'Не обработана страница вне диапазона.' }
Write-Host 'Каталог: 36 уникальных фильмов, три страницы, русский/оригинальный поиск, буквальный %, жанр, пустая выдача и границы пагинации проверены.'
