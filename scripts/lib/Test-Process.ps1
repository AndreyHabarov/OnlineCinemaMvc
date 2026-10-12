function Start-CinemaTestProcess {
    param([string]$MvcPath, [string]$BaseUrl, [string]$Logs, [string[]]$ExtraArgs = @())
    $taskArguments = @(
        (Join-Path $MvcPath 'bin/Debug/net8.0/OnlineCinema.Mvc.dll'),
        '--environment', 'Production', '--urls', $BaseUrl,
        '--DataProtection:KeysPath', (Join-Path $Logs 'keys'),
        '--Logging:EventLog:LogLevel:Default', 'None'
    ) + $ExtraArgs
    # Start-Process соединяет ArgumentList в строку; сохраняем пробелы в путях.
    $taskStart = @{
        FilePath = 'dotnet'
        ArgumentList = @($taskArguments | ForEach-Object { '"' + $_ + '"' })
        WorkingDirectory = $MvcPath
        PassThru = $true
        RedirectStandardOutput = (Join-Path $Logs 'stdout.log')
        RedirectStandardError = (Join-Path $Logs 'stderr.log')
    }
    if ($IsWindows) { $taskStart.WindowStyle = 'Hidden' }
    Start-Process @taskStart
}
