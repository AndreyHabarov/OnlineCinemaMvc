function New-CinemaDockerTestEnvironment {
    $taskVariables = @('COMPOSE_PROJECT_NAME','POSTGRES_USER','POSTGRES_DB','POSTGRES_PASSWORD','POSTGRES_PORT','APP_PORT','ConnectionStrings__Default')
    $taskPrevious = @{}
    foreach ($taskName in $taskVariables) { $taskPrevious[$taskName] = [Environment]::GetEnvironmentVariable($taskName, 'Process') }
    $taskProject = 'codex-container-' + [Guid]::NewGuid().ToString('N')
    $taskLogs = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "backups/$taskProject"
    New-Item -ItemType Directory -Path $taskLogs -Force | Out-Null
    $taskSockets = @()
    $taskPorts = @()
    try {
        foreach ($taskIndex in 0..1) {
            $taskSocket = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
            $taskSocket.Start()
            $taskSockets += $taskSocket
            $taskPorts += $taskSocket.LocalEndpoint.Port
        }
    } finally { $taskSockets | ForEach-Object { $_.Stop() } }
    $env:COMPOSE_PROJECT_NAME = $taskProject
    $env:POSTGRES_USER = 'cinema'
    $env:POSTGRES_DB = 'demo_check'
    $env:POSTGRES_PASSWORD = 'TestOnly;' + [Guid]::NewGuid().ToString('N')
    $env:POSTGRES_PORT = [string]$taskPorts[0]
    $env:APP_PORT = [string]$taskPorts[1]
    $env:ConnectionStrings__Default = $null
    [pscustomobject]@{ Project = $taskProject; Logs = $taskLogs; Previous = $taskPrevious; Variables = $taskVariables; BaseUrl = "http://127.0.0.1:$($taskPorts[1])" }
}

function Remove-CinemaDockerTestEnvironment($Scope) {
    try {
        if ($Scope.Project -notmatch '^codex-container-[a-f0-9]{32}$') { throw 'Недопустимое имя проекта очистки.' }
        # -p задаёт именно наш случайный проект, даже если окружение успело измениться.
        docker compose -p $Scope.Project down --volumes --remove-orphans *> (Join-Path $Scope.Logs 'cleanup.log')
        if ($LASTEXITCODE) { Write-Warning "Не удалось очистить свой Compose-проект $($Scope.Project)." }
    } finally {
        foreach ($taskName in $Scope.Variables) { [Environment]::SetEnvironmentVariable($taskName, $Scope.Previous[$taskName], 'Process') }
    }
}
