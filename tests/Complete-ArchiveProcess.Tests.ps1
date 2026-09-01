# Complete-ArchiveProcess.ps1 orchestrates four subprocess stages (validation, git sync,
# scan conversion, metadata submit) via `pwsh -File`. These tests stub all four child
# scripts with fixtures that record what they were called with and exit with a
# configurable code, then run the real orchestrator script as a real subprocess against
# that fixture directory.

BeforeAll {
    $repoRoot = Join-Path $PSScriptRoot ".."
    $script:workDir = Join-Path $TestDrive "complete-archive-process"
    $script:receiptDir = Join-Path $script:workDir "receipts"

    New-Item -ItemType Directory -Path $script:workDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:receiptDir -Force | Out-Null

    Copy-Item -Path (Join-Path $repoRoot "Complete-ArchiveProcess.ps1") -Destination $script:workDir -Force
    Copy-Item -Path (Join-Path $repoRoot "libs") -Destination $script:workDir -Recurse -Force

    # Stub for Test-EnvironmentConfiguration.ps1: writes the fixture JSON to -OutputFile
    # (the Step 3 contract) and also emits unrelated Write-Host chatter containing a
    # brace, to guard against the stdout-scraping bug the Step 3 fix removed.
    Set-Content -Path (Join-Path $script:workDir "Test-EnvironmentConfiguration.ps1") -Encoding UTF8 -Value @'
param(
    [string]$OutputFile = ""
)

Write-Host "Команда: git remote get-url origin, STDOUT: посторонний шум { не JSON"

$exitCode = 0
if ($env:STUB_VALIDATION_EXIT) { $exitCode = [int]$env:STUB_VALIDATION_EXIT }

if ($env:STUB_RECEIPT_DIR) {
    @{ OutputFile = $OutputFile } | ConvertTo-Json | Set-Content -Path (Join-Path $env:STUB_RECEIPT_DIR "validation.json") -Encoding UTF8
}

if ($exitCode -eq 0) {
    if ($OutputFile) {
        Set-Content -Path $OutputFile -Value $env:STUB_VALIDATION_JSON -Encoding UTF8
    }
} else {
    Write-Error "stub validation failure"
}

exit $exitCode
'@

    Set-Content -Path (Join-Path $script:workDir "Sync-MetadataGitRepo.ps1") -Encoding UTF8 -Value @'
param(
    [string]$GitDirectory = "",
    [string]$UpstreamUrl = "",
    [string]$BranchName = ""
)

if ($env:STUB_RECEIPT_DIR) {
    @{ GitDirectory = $GitDirectory; UpstreamUrl = $UpstreamUrl; BranchName = $BranchName } |
        ConvertTo-Json | Set-Content -Path (Join-Path $env:STUB_RECEIPT_DIR "sync.json") -Encoding UTF8
}

$exitCode = 0
if ($env:STUB_SYNC_EXIT) { $exitCode = [int]$env:STUB_SYNC_EXIT }
exit $exitCode
'@

    Set-Content -Path (Join-Path $script:workDir "Convert-ScannedFIles.ps1") -Encoding UTF8 -Value @'
param(
    [string]$SourcePath = "",
    [string]$ResultPath = ""
)

if ($env:STUB_RECEIPT_DIR) {
    @{ SourcePath = $SourcePath; ResultPath = $ResultPath } |
        ConvertTo-Json | Set-Content -Path (Join-Path $env:STUB_RECEIPT_DIR "convert.json") -Encoding UTF8
}

$exitCode = 0
if ($env:STUB_CONVERT_EXIT) { $exitCode = [int]$env:STUB_CONVERT_EXIT }
exit $exitCode
'@

    Set-Content -Path (Join-Path $script:workDir "Submit-MetadataToRemote.ps1") -Encoding UTF8 -Value @'
param(
    [string]$GitDirectory = "",
    [string]$GitBranch = ""
)

if ($env:STUB_RECEIPT_DIR) {
    @{ GitDirectory = $GitDirectory; GitBranch = $GitBranch } |
        ConvertTo-Json | Set-Content -Path (Join-Path $env:STUB_RECEIPT_DIR "submit.json") -Encoding UTF8
}

$exitCode = 0
if ($env:STUB_SUBMIT_EXIT) { $exitCode = [int]$env:STUB_SUBMIT_EXIT }
exit $exitCode
'@

    $configContent = @{
        GitServerType = "Gitea"
        GitServerUrl  = "https://example.invalid"
        GitProjectId  = "test/repo"
        GitRepoUrl    = "STUB_GIT_URL"
    } | ConvertTo-Json
    Set-Content -Path (Join-Path $script:workDir "config.json") -Value $configContent -Encoding UTF8

    $script:validValidationJson = @{
        Success = $true
        Paths   = @{
            SourcePath   = "STUB_SOURCE_PATH"
            ResultPath   = "STUB_RESULT_PATH"
            MetadataPath = "STUB_METADATA_PATH"
        }
        IsGitProviderAvailable = $false
    } | ConvertTo-Json -Depth 10 -Compress

    function Invoke-Pipeline {
        param(
            [string]$ValidationJson = $script:validValidationJson,
            [int]$ValidationExit = 0,
            [int]$SyncExit = 0,
            [int]$ConvertExit = 0,
            [int]$SubmitExit = 0
        )

        Get-ChildItem -Path $script:receiptDir -File | Remove-Item -Force -ErrorAction SilentlyContinue

        Push-Location $script:workDir
        try {
            $env:STUB_RECEIPT_DIR = $script:receiptDir
            $env:STUB_VALIDATION_JSON = $ValidationJson
            $env:STUB_VALIDATION_EXIT = "$ValidationExit"
            $env:STUB_SYNC_EXIT = "$SyncExit"
            $env:STUB_CONVERT_EXIT = "$ConvertExit"
            $env:STUB_SUBMIT_EXIT = "$SubmitExit"

            $output = & pwsh -NoProfile -File "./Complete-ArchiveProcess.ps1" 2>&1

            [PSCustomObject]@{
                Output   = $output
                ExitCode = $LASTEXITCODE
            }
        } finally {
            Remove-Item Env:\STUB_RECEIPT_DIR, Env:\STUB_VALIDATION_JSON, Env:\STUB_VALIDATION_EXIT, `
                Env:\STUB_SYNC_EXIT, Env:\STUB_CONVERT_EXIT, Env:\STUB_SUBMIT_EXIT -ErrorAction SilentlyContinue
            Pop-Location
        }
    }

    function Get-Receipt {
        param([string]$Name)
        $path = Join-Path $script:receiptDir "$Name.json"
        if (Test-Path $path) {
            return Get-Content $path -Raw | ConvertFrom-Json
        }
        return $null
    }
}

Describe 'Complete-ArchiveProcess orchestration' {
    Context 'Happy path' {
        BeforeAll {
            $script:result = Invoke-Pipeline
        }

        It 'Exits 0' {
            $script:result.ExitCode | Should -Be 0
        }

        It 'Passes the validated source and result paths to Convert-ScannedFIles.ps1' {
            $receipt = Get-Receipt "convert"
            $receipt | Should -Not -BeNullOrEmpty
            $receipt.SourcePath | Should -Be "STUB_SOURCE_PATH"
            $receipt.ResultPath | Should -Be "STUB_RESULT_PATH"
        }

        It 'Passes the validated metadata path and repo URL to Sync-MetadataGitRepo.ps1' {
            $receipt = Get-Receipt "sync"
            $receipt | Should -Not -BeNullOrEmpty
            $receipt.GitDirectory | Should -Be "STUB_METADATA_PATH"
            $receipt.UpstreamUrl | Should -Be "STUB_GIT_URL"
            $receipt.BranchName | Should -Match "^processing-results-"
        }

        It 'Passes the same metadata path and branch to Submit-MetadataToRemote.ps1' {
            $syncReceipt = Get-Receipt "sync"
            $submitReceipt = Get-Receipt "submit"
            $submitReceipt | Should -Not -BeNullOrEmpty
            $submitReceipt.GitDirectory | Should -Be "STUB_METADATA_PATH"
            $submitReceipt.GitBranch | Should -Be $syncReceipt.BranchName
        }
    }

    Context 'Each stage abort on non-zero exit' {
        It 'Aborts without running later stages when validation fails' {
            $result = Invoke-Pipeline -ValidationExit 1
            $result.ExitCode | Should -Be 1
            Get-Receipt "sync" | Should -BeNullOrEmpty
        }

        It 'Aborts without running later stages when the git sync stage fails' {
            $result = Invoke-Pipeline -SyncExit 1
            $result.ExitCode | Should -Be 1
            Get-Receipt "convert" | Should -BeNullOrEmpty
        }

        It 'Aborts without running later stages when scan conversion fails' {
            $result = Invoke-Pipeline -ConvertExit 1
            $result.ExitCode | Should -Be 1
            Get-Receipt "submit" | Should -BeNullOrEmpty
        }

        It 'Aborts when the submit stage fails outright' {
            $result = Invoke-Pipeline -SubmitExit 1
            $result.ExitCode | Should -Be 1
        }
    }

    Context 'Nothing-to-publish handling (Step 2 contract)' {
        It 'Treats submit exit code 2 as success' {
            $result = Invoke-Pipeline -SubmitExit 2
            $result.ExitCode | Should -Be 0
        }
    }
}
