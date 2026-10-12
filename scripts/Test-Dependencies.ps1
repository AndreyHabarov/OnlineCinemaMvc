[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $taskJson = dotnet list OnlineCinemaMvc.sln package --vulnerable --include-transitive --no-restore --format json
    if ($LASTEXITCODE) { throw 'Аудит NuGet недоступен.' }
    $taskReport = ($taskJson -join "`n") | ConvertFrom-Json
    $taskPackages = @($taskReport.projects | ForEach-Object {
        $_.frameworks | ForEach-Object { @($_.topLevelPackages) + @($_.transitivePackages) }
    } | Where-Object { $_ -and $_.vulnerabilities })
    if ($taskPackages.Count) {
        $taskPackages | ForEach-Object { Write-Host "$($_.id) $($_.resolvedVersion)" }
        throw 'Найдены известные уязвимости NuGet; проверьте обновления перед публикацией.'
    }
    Write-Host 'Известных уязвимостей прямых и транзитивных NuGet-зависимостей не обнаружено.'
} finally { Pop-Location }
