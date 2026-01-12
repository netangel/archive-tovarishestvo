<#
.SYNOPSIS
    Validates environment and configuration for the archive processing system.

.DESCRIPTION
    This script checks all required paths, tools, git repository setup, and git service
    configuration to ensure the environment is correctly set up for archive processing.

    On success: Outputs JSON structure with validated paths
    On failure: Outputs errors and exits with code 1

.PARAMETER SourcePath
    Directory with scanned documents (PDF/TIFF files)

.PARAMETER ResultPath
    Directory for processed results

.PARAMETER MetadataPath
    Directory with metadata for archive (should end with 'metadata')

.PARAMETER SkipGitServiceCheck
    Skip git service API checks (useful for offline validation)

.EXAMPLE
    ./Test-EnvironmentConfiguration.ps1

.EXAMPLE
    ./Test-EnvironmentConfiguration.ps1 -SourcePath "C:\scans" -ResultPath "C:\results" -MetadataPath "C:\results\metadata"
#>

[CmdletBinding()]
param(
    [string]$SourcePath = "",
    [string]$ResultPath = "",
    [string]$MetadataPath = "",
    [switch]$SkipGitServiceCheck
)

# Import required modules
$scriptRoot = $PSScriptRoot
Import-Module (Join-Path $scriptRoot "libs/ToolsHelper.psm1") -Force
Import-Module (Join-Path $scriptRoot "libs/PathHelper.psm1") -Force
Import-Module (Join-Path $scriptRoot "libs/GitHelper.psm1") -Force
Import-Module (Join-Path $scriptRoot "libs/GitServerProvider.psm1") -Force

# Track validation errors
$validationErrors = @()

function Add-ValidationError {
    param([string]$Message)
    $script:validationErrors += $Message
}

# ============================================================================
# 1. Configuration Loading
# ============================================================================
$configPath = Join-Path $scriptRoot "config.json"
if (-not (Test-Path $configPath)) {
    Add-ValidationError "config.json not found at $configPath"
    Write-Error ($validationErrors -join "`n")
    exit 1
}

try {
    $config = Get-Content $configPath | ConvertFrom-Json -AsHashtable
} catch {
    Add-ValidationError "Failed to parse config.json: $($_.Exception.Message)"
    Write-Error ($validationErrors -join "`n")
    exit 1
}

# ============================================================================
# 2. Path Validation
# ============================================================================
$requiredPaths = [ordered]@{
    SourcePath = "Корневая директория с отсканированными чертежами"
    ResultPath = "Директория с чертежами для публикации"
    MetadataPath = "Директория с метаданными для архива чертежей"
}

$pathValidationResults = @{}
$configUpdated = $false

foreach ($key in $requiredPaths.Keys) {
    # Use parameter value if provided, otherwise use config value
    $pathValue = Get-Variable -Name $key -ValueOnly
    if ([string]::IsNullOrWhiteSpace($pathValue)) {
        $pathValue = $config[$key]
    }

    if ([string]::IsNullOrWhiteSpace($pathValue)) {
        Add-ValidationError "$key is not defined in config.json or parameters"
        $pathValidationResults[$key] = $null
        continue
    }

    try {
        $resolvedPath = Test-RequiredPathsAndReturn $pathValue $scriptRoot
        $pathValidationResults[$key] = $resolvedPath

        # Update config if parameter was provided
        if (-not [string]::IsNullOrWhiteSpace((Get-Variable -Name $key -ValueOnly)) -and $config[$key] -ne $resolvedPath) {
            $config[$key] = $resolvedPath
            $configUpdated = $true
        }
    } catch {
        Add-ValidationError "$key validation failed: $($_.Exception.Message)"
        $pathValidationResults[$key] = $null
    }
}

# Check if MetadataPath ends with 'metadata'
if ($pathValidationResults['MetadataPath']) {
    $metadataPathValue = $pathValidationResults['MetadataPath']
    $expectedSuffix = $MetadataDir  # This comes from PathHelper module

    if (-not ($metadataPathValue -match "[\\/]$expectedSuffix$")) {
        Add-ValidationError "MetadataPath should end with '$expectedSuffix', but it's '$metadataPathValue'"
    }
}

# Save config if updated
if ($configUpdated) {
    try {
        $config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8
    } catch {
        Add-ValidationError "Failed to update config.json: $($_.Exception.Message)"
    }
}

# ============================================================================
# 3. Required Tools Check
# ============================================================================
if (-not (Test-ImageMagick)) {
    Add-ValidationError "ImageMagick is not installed"
}

if (-not (Test-Ghostscript)) {
    Add-ValidationError "Ghostscript is not installed"
}

if (-not (Test-Git)) {
    Add-ValidationError "Git is not installed"
    $hasGit = $false
} else {
    $hasGit = $true
}

# ============================================================================
# 4. Git Repository Configuration
# ============================================================================
$gitRepoUrl = $config['GitRepoUrl']
if ([string]::IsNullOrWhiteSpace($gitRepoUrl)) {
    Add-ValidationError "GitRepoUrl is not defined in config.json"
}

# Check if git repo exists in MetadataPath
if ($pathValidationResults['MetadataPath'] -and $hasGit) {
    $metadataPath = $pathValidationResults['MetadataPath']
    $gitDir = Join-Path $metadataPath ".git"

    if (Test-Path $gitDir) {
        # Check remote origin
        try {
            Push-Location $metadataPath
            $gitResult = & git remote get-url origin 2>&1
            if ($LASTEXITCODE -eq 0) {
                $remoteUrl = $gitResult.Trim()

                # Normalize URLs for comparison
                $normalizedRemote = $remoteUrl.TrimEnd('/').TrimEnd('.git')
                $normalizedExpected = $gitRepoUrl.TrimEnd('/').TrimEnd('.git')

                if ($normalizedRemote -ne $normalizedExpected) {
                    Add-ValidationError "Git remote origin mismatch. Expected: $gitRepoUrl, Got: $remoteUrl"
                }
            } else {
                Add-ValidationError "Failed to get git remote origin"
            }
            Pop-Location
        } catch {
            Add-ValidationError "Error checking git remote: $($_.Exception.Message)"
            Pop-Location
        }
    } else {
        Add-ValidationError "Git repository not initialized in MetadataPath"
    }
}

# ============================================================================
# 5. Git Service Configuration
# ============================================================================
$gitServerType = $config['GitServerType']
if ([string]::IsNullOrWhiteSpace($gitServerType)) {
    Add-ValidationError "GitServerType is not defined in config.json"
} elseif ($gitServerType -notin @("GitLab", "Gitea")) {
    Add-ValidationError "GitServerType has invalid value: $gitServerType (should be 'GitLab' or 'Gitea')"
}

$gitServerUrl = $config['GitServerUrl']
if ([string]::IsNullOrWhiteSpace($gitServerUrl)) {
    Add-ValidationError "GitServerUrl is not defined in config.json"
}

$gitProjectId = $config['GitProjectId']
if ([string]::IsNullOrWhiteSpace($gitProjectId)) {
    Add-ValidationError "GitProjectId is not defined in config.json"
}

# ============================================================================
# 6. Git Service Access Token
# ============================================================================
$expectedTokenVar = switch ($gitServerType) {
    "GitLab" { "GITLAB_TOKEN" }
    "Gitea" { "GITEA_TOKEN" }
    default { $null }
}

$tokenValue = $null
if ($expectedTokenVar) {
    $tokenValue = [System.Environment]::GetEnvironmentVariable($expectedTokenVar)

    if ([string]::IsNullOrWhiteSpace($tokenValue)) {
        Add-ValidationError "Environment variable $expectedTokenVar is not set"
    }
}

# ============================================================================
# 7. Git Service API Connectivity (Optional)
# ============================================================================
$canTestApi = (-not [string]::IsNullOrWhiteSpace($gitServerType)) -and
              (-not [string]::IsNullOrWhiteSpace($gitServerUrl)) -and
              (-not [string]::IsNullOrWhiteSpace($gitProjectId)) -and
              (-not [string]::IsNullOrWhiteSpace($tokenValue))

if (-not $SkipGitServiceCheck -and $canTestApi) {
    try {
        # Create git service provider
        $provider = New-GitServerProvider -ProviderType $gitServerType `
                                         -ServerUrl $gitServerUrl `
                                         -ProjectId $gitProjectId `
                                         -AccessToken $tokenValue

        # Test by checking for open merge/pull requests
        try {
            $null = $provider.TestOpenMergeRequests()
        } catch {
            Add-ValidationError "Failed to query $gitServerType API: $($_.Exception.Message)"
        }

    } catch {
        Add-ValidationError "Failed to create git service provider: $($_.Exception.Message)"
    }
}

# ============================================================================
# Final Result
# ============================================================================
if ($validationErrors.Count -gt 0) {
    # Output errors to STDERR
    Write-Error ($validationErrors -join "`n")
    exit 1
}

# Success - output JSON structure
$validationOutput = @{
    Success = $true
    Paths = @{
        SourcePath = $pathValidationResults['SourcePath']
        ResultPath = $pathValidationResults['ResultPath']
        MetadataPath = $pathValidationResults['MetadataPath']
    }
    IsGitProviderAvailable = $canTestApi
}

# Output JSON to stdout
Write-Output ($validationOutput | ConvertTo-Json -Depth 10)
exit 0
