# Base class defining the interface for git server providers
class GitServerProvider {
    [string]$ServerUrl
    [string]$ProjectId
    [string]$AccessToken

    GitServerProvider([string]$serverUrl, [string]$projectId, [string]$accessToken) {
        $this.ServerUrl = $serverUrl
        $this.ProjectId = $projectId
        $this.AccessToken = $accessToken
    }

    # Abstract methods that must be implemented by derived classes
    [object] TestOpenMergeRequests() {
        throw "Method 'TestOpenMergeRequests' must be implemented in derived class"
    }

    [object] SubmitMergeRequest([string]$sourceBranch, [string]$targetBranch, [string]$title, [string]$description, [bool]$removeSourceBranch) {
        throw "Method 'SubmitMergeRequest' must be implemented in derived class"
    }
}

# GitLab implementation
class GitLabProvider : GitServerProvider {
    GitLabProvider([string]$serverUrl, [string]$projectId, [string]$accessToken) : base($serverUrl, $projectId, $accessToken) {}

    [object] TestOpenMergeRequests() {
        # Construct the API URL for listing open merge requests
        $apiUrl = "$($this.ServerUrl)/api/v4/projects/$($this.ProjectId)/merge_requests?state=opened"

        # Prepare headers
        $headers = @{
            "PRIVATE-TOKEN" = $this.AccessToken
            "Content-Type"  = "application/json"
        }

        try {
            Write-Host "Проверяем наличие открытых merge запросов (GitLab)..." -ForegroundColor Yellow

            # Make the API call
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers

            if ($response.Count -gt 0) {
                Write-Host "⚠️  Обнаружено открытых merge запросов: $($response.Count)" -ForegroundColor Red
                Write-Host ""
                foreach ($mr in $response) {
                    Write-Host "  MR !$($mr.iid): $($mr.title)" -ForegroundColor Yellow
                    Write-Host "    Ветка: $($mr.source_branch) -> $($mr.target_branch)" -ForegroundColor Gray
                    Write-Host "    URL: $($mr.web_url)" -ForegroundColor Blue
                    Write-Host ""
                }
                return $true
            }
            else {
                Write-Host "✅ Открытых merge запросов не найдено" -ForegroundColor Green
                return $false
            }
        }
        catch {
            Write-Host "⚠️  Не удалось проверить открытые merge запросы:" -ForegroundColor Yellow
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    [object] SubmitMergeRequest([string]$sourceBranch, [string]$targetBranch, [string]$title, [string]$description, [bool]$removeSourceBranch) {
        # Construct the API URL
        $apiUrl = "$($this.ServerUrl)/api/v4/projects/$($this.ProjectId)/merge_requests"

        # Prepare headers
        $headers = @{
            "PRIVATE-TOKEN" = $this.AccessToken
            "Content-Type"  = "application/json"
        }

        # Prepare the request body
        $body = @{
            source_branch        = $sourceBranch
            target_branch        = $targetBranch
            title                = $title
            description          = $description
            remove_source_branch = $removeSourceBranch
        } | ConvertTo-Json -Depth 3

        try {
            Write-Host "Создаем merge запрос (GitLab)..." -ForegroundColor Yellow
            Write-Host "Исходная ветка: $sourceBranch -> Целевая ветка: $targetBranch" -ForegroundColor Cyan

            # Make the API call
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body

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
            }
            else {
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            }

            throw
        }
    }
}

# Gitea implementation
class GiteaProvider : GitServerProvider {
    GiteaProvider([string]$serverUrl, [string]$projectId, [string]$accessToken) : base($serverUrl, $projectId, $accessToken) {}

    [object] TestOpenMergeRequests() {
        # Gitea uses "pull requests" terminology, API: /repos/{owner}/{repo}/pulls
        # ProjectId should be in format "owner/repo"
        $apiUrl = "$($this.ServerUrl)/api/v1/repos/$($this.ProjectId)/pulls?state=open"

        # Prepare headers (Gitea uses different auth header)
        $headers = @{
            "Authorization" = "token $($this.AccessToken)"
            "Content-Type"  = "application/json"
        }

        try {
            Write-Host "Проверяем наличие открытых pull запросов (Gitea)..." -ForegroundColor Yellow

            # Make the API call
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers

            if ($response.Count -gt 0) {
                Write-Host "⚠️  Обнаружено открытых pull запросов: $($response.Count)" -ForegroundColor Red
                Write-Host ""
                foreach ($pr in $response) {
                    Write-Host "  PR #$($pr.number): $($pr.title)" -ForegroundColor Yellow
                    Write-Host "    Ветка: $($pr.head.ref) -> $($pr.base.ref)" -ForegroundColor Gray
                    Write-Host "    URL: $($pr.html_url)" -ForegroundColor Blue
                    Write-Host ""
                }
                return $true
            }
            else {
                Write-Host "✅ Открытых pull запросов не найдено" -ForegroundColor Green
                return $false
            }
        }
        catch {
            Write-Host "⚠️  Не удалось проверить открытые pull запросы:" -ForegroundColor Yellow
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    [object] SubmitMergeRequest([string]$sourceBranch, [string]$targetBranch, [string]$title, [string]$description, [bool]$removeSourceBranch) {
        # Gitea API: /repos/{owner}/{repo}/pulls
        $apiUrl = "$($this.ServerUrl)/api/v1/repos/$($this.ProjectId)/pulls"

        # Prepare headers
        $headers = @{
            "Authorization" = "token $($this.AccessToken)"
            "Content-Type"  = "application/json"
        }

        # Prepare the request body (Gitea uses different field names)
        $body = @{
            head  = $sourceBranch
            base  = $targetBranch
            title = $title
            body  = $description
        } | ConvertTo-Json -Depth 3

        try {
            Write-Host "Создаем pull запрос (Gitea)..." -ForegroundColor Yellow
            Write-Host "Исходная ветка: $sourceBranch -> Целевая ветка: $targetBranch" -ForegroundColor Cyan

            # Make the API call
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body

            Write-Host "✅ Pull запрос создан успешно!" -ForegroundColor Green
            Write-Host "PR Number: $($response.number)" -ForegroundColor White
            Write-Host "URL: $($response.html_url)" -ForegroundColor Blue

            return $response
        }
        catch {
            Write-Host "❌ Не получилось создать pull запрос:" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) {
                Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
            }
            throw
        }
    }
}

# Factory function to create the appropriate provider
function New-GitServerProvider {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("GitLab", "Gitea")]
        [string]$ProviderType,

        [Parameter(Mandatory = $true)]
        [string]$ServerUrl,

        [Parameter(Mandatory = $true)]
        [string]$ProjectId,

        [Parameter(Mandatory = $true)]
        [string]$AccessToken
    )

    switch ($ProviderType) {
        "GitLab" {
            return [GitLabProvider]::new($ServerUrl, $ProjectId, $AccessToken)
        }
        "Gitea" {
            return [GiteaProvider]::new($ServerUrl, $ProjectId, $AccessToken)
        }
    }
}

Export-ModuleMember -Function New-GitServerProvider
