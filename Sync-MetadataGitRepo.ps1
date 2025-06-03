param(
    [Parameter(Mandatory=$true)]
    [string]$GitDirectory,
    
    [Parameter(Mandatory=$true)]
    [string]$UpstreamUrl
)

# Function to write error and exit with failure
function Exit-WithError {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

try {
    # 1. Change to the specified directory
    if (-not (Test-Path $GitDirectory)) {
        Exit-WithError "Directory does not exist: $GitDirectory"
    }
    
    Set-Location $GitDirectory
    Write-Host "Changed to directory: $GitDirectory"
    
    # 2. Check if there's a git repository with given upstream
    if (-not (Test-Path ".git")) {
        Exit-WithError "Not a git repository: $GitDirectory"
    }
    
    # Get the remote origin URL
    $remoteUrl = git remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Failed to get remote origin URL"
    }
    
    # Normalize URLs for comparison (remove .git suffix and trailing slashes)
    $normalizedRemote = $remoteUrl.TrimEnd('/').TrimEnd('.git')
    $normalizedUpstream = $UpstreamUrl.TrimEnd('/').TrimEnd('.git')
    
    if ($normalizedRemote -ne $normalizedUpstream) {
        Exit-WithError "Remote origin URL ($remoteUrl) does not match expected upstream ($UpstreamUrl)"
    }
    
    Write-Host "Git repository verified with correct upstream: $remoteUrl"
    
    # 3. Check current user connection to git repository
    Write-Host "Testing connection to repository..."
    git ls-remote origin HEAD 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Cannot connect to git repository. Check credentials and network access."
    }
    
    Write-Host "Connection to repository verified"
    
    # 4. Switch to main branch and pull latest changes
    Write-Host "Switching to main branch..."
    git checkout main 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Failed to checkout main branch"
    }
    
    Write-Host "Pulling latest changes..."
    git pull origin main 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Failed to pull latest changes from main"
    }
    
    Write-Host "Successfully updated main branch"
    
    # 5. Create and switch to new branch with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $branchName = "processing-results-$timestamp"
    
    Write-Host "Creating new branch: $branchName"
    git checkout -b $branchName 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Failed to create new branch: $branchName"
    }
    
    Write-Host "Successfully created and switched to branch: $branchName"
    Write-Host "Git setup completed successfully"
    
    # Return success
    exit 0
    
} catch {
    Exit-WithError "Unexpected error: $($_.Exception.Message)"
}