# Exit codes: 0 = метаданные отправлены, 1 = ошибка, 2 = отправлять нечего (нет изменений).
# См. $PushResultNoChanges / Push-GitCommit в libs/GitHelper.psm1.
Param(
    [Parameter(Mandatory=$true)]
    [string]$GitDirectory,

    [Parameter(Mandatory=$true)]
    [string]$GitBranch
)

if ($env:PARENT_VERBOSE -eq "true") {
    $VerbosePreference = "Continue"
}

Import-Module (Join-Path $PSScriptRoot "libs/GitHelper.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "libs/ToolsHelper.psm1") -Force

try {
    if (-not (Test-Path $GitDirectory)) {
        Exit-WithError "Папка отсутствует: $GitDirectory"
    }
    
    Set-Location $GitDirectory
    Write-Host "Переход в директорию: $GitDirectory"
    
    if (-not (Test-Path ".git")) {
        Exit-WithError "В текущей папке нет инициализированного git-репозитория: $GitDirectory"
    }

    Add-AllNewFiles

    $pushResult = Push-GitCommit $GitBranch

    if ($pushResult -eq $PushResultNoChanges) {
        exit 2
    }

    exit 0
}
catch {
    Exit-WithError "Не удалось отправить метаданные в git-репозиторий: $($_.Exception.Message)"
}
