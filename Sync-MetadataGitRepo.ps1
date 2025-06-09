Param(
    [Parameter(Mandatory=$true)]
    [string]$GitDirectory,
    
    [Parameter(Mandatory=$true)]
    [string]$UpstreamUrl,

    [Parameter(Mandatory=$true)]
    [string]$BranchName 
)

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
    
    Test-GitConnection $UpstreamUrl
    
    Switch-ToMainBranch

    Update-MainBranch

    New-ProcessingBranch $BranchName
    
    Write-Host "Мы теперь в новой ветке $BranchName и готовы работать дальше!"
    
    # Return success
    exit 0
    
} catch {
    Exit-WithError "Unexpected error: $($_.Exception.Message)"
}