# GitLab Merge Request Creation Script
param(
    [Parameter(Mandatory=$true)]
    [string]$GitLabUrl, 
    
    [Parameter(Mandatory=$true)]
    [string]$ProjectId,
    
    [Parameter(Mandatory=$true)]
    [string]$AccessToken,
    
    [Parameter(Mandatory=$true)]
    [string]$SourceBranch,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetBranch,
    
    [Parameter(Mandatory=$true)]
    [string]$Title,
    
    [string]$Description = "",
    [string]$AssigneeId = "",
    [string]$ReviewerId = "",
    [bool]$RemoveSourceBranch = $true
)

if ($env:PARENT_VERBOSE -eq "true") {
    $VerbosePreference = "Continue"
}

# Construct the API URL
$apiUrl = "$GitLabUrl/api/v4/projects/$ProjectId/merge_requests"

# Prepare headers
$headers = @{
    "PRIVATE-TOKEN" = $AccessToken
    "Content-Type" = "application/json"
}

# Prepare the request body
$body = @{
    source_branch = $SourceBranch
    target_branch = $TargetBranch
    title = $Title
    description = $Description
    remove_source_branch = $RemoveSourceBranch
}

# Add optional parameters if provided
if ($AssigneeId) {
    $body.assignee_id = $AssigneeId
}
if ($ReviewerId) {
    $body.reviewer_ids = @($ReviewerId)
}

# Convert to JSON
$jsonBody = $body | ConvertTo-Json -Depth 3

try {
    Write-Host "Создаем merge запрос..." -ForegroundColor Yellow
    Write-Host "Исходная вета: $SourceBranch -> Целевая ветка: $TargetBranch" -ForegroundColor Cyan
    
    # Make the API call
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $jsonBody
    
    Write-Host "✅ Merge запрос создан успешно!" -ForegroundColor Green
    Write-Host "MR ID: $($response.iid)" -ForegroundColor White
    Write-Host "URL: $($response.web_url)" -ForegroundColor Blue
    
    return $response
}
catch {
    $errorDetails = $_.Exception.Response | ConvertFrom-Json -ErrorAction SilentlyContinue
    Write-Host "❌ Не получилось создать merge запрос:" -ForegroundColor Red
    Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    
    if ($errorDetails.message) {
        Write-Host "Error: $($errorDetails.message)" -ForegroundColor Red
    } else {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    throw
}
