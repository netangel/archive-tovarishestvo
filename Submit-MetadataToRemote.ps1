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

    Push-GitCommit

}
catch {
    <#Do this if a terminating exception happens#>
}