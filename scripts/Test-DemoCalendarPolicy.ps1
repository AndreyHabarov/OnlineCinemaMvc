[CmdletBinding()]
param([ValidateSet('Debug','Release')][string]$Configuration='Debug')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskAssembly=[Reflection.Assembly]::LoadFrom((Join-Path $taskRoot "OnlineCinema.Application/bin/$Configuration/net8.0/OnlineCinema.Application.dll"))
$taskType=$taskAssembly.GetType('OnlineCinema.Application.SessionAvailability',$true)
$taskCalendar=Get-Content (Join-Path $taskRoot 'data/demo-calendar.json') -Raw -Encoding utf8 | ConvertFrom-Json
$taskDates=[DateTime[]]@($taskCalendar.dates | ForEach-Object {[DateTime]::ParseExact($_,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)})
$taskConstructor=$taskType.GetConstructor(@([bool],[DateTime[]]))
$taskDemo=$taskConstructor.Invoke(@($true,$taskDates))
$taskProduction=$taskConstructor.Invoke(@($false,$taskDates))
foreach($taskNow in @([DateTime]'2010-01-01',[DateTime]'2025-11-04T12:00:00',[DateTime]'2026-10-12',[DateTime]'2050-01-01')) {
    foreach($taskDate in $taskDates) {
        $taskStart=$taskDate.AddHours(14)
        if(!$taskDemo.CanPurchase($taskStart,$taskNow)){throw 'Демосеанс зависит от текущей даты'}
        if($taskProduction.CanPurchase($taskStart,$taskNow) -ne ($taskStart -gt $taskNow)){throw 'Временные ограничения production нарушены'}
    }
    foreach($taskOutside in @($taskDates[0].AddDays(-1),$taskDates[-1].AddDays(1))) {
        if($taskDemo.CanPurchase($taskOutside,$taskNow)){throw 'Разрешена дата вне демокалендаря'}
    }
}
if($taskProduction.CanPurchase([DateTime]'2026-10-12',[DateTime]'2026-10-12')){throw 'Production разрешил начавшийся сеанс'}
Write-Host 'Политика сеансов: семь демодат доступны при часах до, внутри и после периода (2010–2050); границы и запрет прошедших/начавшихся production-сеансов сохранены.'
