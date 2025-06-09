Import-Module (Join-Path $PSScriptRoot "libs/GitHelper.psm1")  -Force

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$branchName = "test-branch-1"

New-GitLabMergeRequest -Branch $branchName -Title "Результаты обработки $timestamp"