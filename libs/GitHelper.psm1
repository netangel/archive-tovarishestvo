# Private functions 
# Git command invocation
function Invoke-GitCommand {
    param(
        [string[]]$Arguments
    )
    
    # Create temporary files for capturing streams
    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    
    try {
        $processArgs = @{
            FilePath               = "git"
            ArgumentList           = $Arguments
            RedirectStandardOutput = $stdoutFile
            RedirectStandardError  = $stderrFile
            Wait                   = $true
            PassThru               = $true
            NoNewWindow            = $true
        }
        
        $process = Start-Process @processArgs
        
        # Read the captured output
        $stdout = if ((Test-Path $stdoutFile) -and (Get-Item $stdoutFile).Length -gt 0) { 
            (Get-Content $stdoutFile -Raw).Trim() 
        }
        else { "" }
        
        $stderr = if ((Test-Path $stderrFile) -and (Get-Item $stderrFile).Length -gt 0) { 
            (Get-Content $stderrFile -Raw).Trim() 
        }
        else { "" }
        
        return @{
            ExitCode = $process.ExitCode
            StdOut   = $stdout
            StdErr   = $stderr
            Success  = $process.ExitCode -eq 0
        }
    }
    finally {
        # Clean up temp files
        if (Test-Path $stdoutFile) { Remove-Item $stdoutFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path $stderrFile) { Remove-Item $stderrFile -Force -ErrorAction SilentlyContinue }
    }
}

# Base git operation function
function Invoke-GitOperation {
    param(
        [string[]]$Arguments,
        [string]$OperationName,
        [scriptblock]$PreOperation = {},
        [scriptblock]$PostOperation = {},
        [scriptblock]$ValidationLogic = { $true }
    )
    
    # Execute pre-operation logic
    & $PreOperation
    
    # Execute the git command
    $result = Invoke-GitCommand -Arguments $Arguments
    Write-GitLog -Operation $OperationName -Result $result
    
    # Validate result
    $isValid = & $ValidationLogic $result
    
    if (-not $result.Success -or -not $isValid) {
        exit 1
    }
    
    # Execute post-operation logic
    & $PostOperation $result
    
    return $result
}

# Function to log git command results
function Write-GitLog {
    param(
        [string]$Operation,
        [hashtable]$Result
    )
    
    if ($Result.StdOut) {
        Write-Host "Команда: git $Operation, STDOUT: $($Result.StdOut)"
    }
    elseif ($Result.StdErr) {
        Write-Host "Команда: git $Operation, STDERR: $($Result.StdErr)"
    }
}

function Test-GitConnection {
    param([string]$UpstreamUrl)

    Invoke-GitOperation -Arguments @("remote", "get-url", "origin") -OperationName "remote get-url origin" `
        -PostOperation { Write-Host "Репозиторий в папке связан с внешним URL: $UpstreamUrl" } `
        -ValidationLogic {
        param($result)
        $remoteUrl = $result.StdOut
        # Normalize URLs for comparison (remove .git suffix and trailing slashes)
        $normalizedRemote = $remoteUrl.TrimEnd('/').TrimEnd('.git')
        $normalizedUpstream = $UpstreamUrl.TrimEnd('/').TrimEnd('.git')
    
        return $normalizedRemote -eq $normalizedUpstream
    } | Out-Null    

    $head = "HEAD"
    Invoke-GitOperation -Arguments @("ls-remote", "origin", $head) -OperationName "ls-remote origin HEAD" `
        -PreOperation { Write-Host "Проверяем подключение к удаленному репозиторию" } `
        -PostOperation { Write-Host "Подключение установленно успешно" } `
        -ValidationLogic { 
        param($result)
        return $result.StdOut -match $head
    } | Out-Null
}

function Switch-ToMainBranch {
    $result = Invoke-GitOperation -Arguments @("branch", "--show-current") -OperationName "branch"
    $currentBranch = $result.StdOut.Trim()
    
    if ($currentBranch -ne "main") {
        Invoke-GitOperation -Arguments @("switch", "main") -OperationName "switch main" `
            -PreOperation { Write-Host "Переключаемся на основную ветку (текущая ветка: $currentBranch)..." } | Out-Null
    }
}

function Update-MainBranch {
    Invoke-GitOperation -Arguments @("pull", "origin", "main") -OperationName "pull origin" `
        -PreOperation { Write-Host "Получаем последние изменения..." } `
        -PostOperation { Write-Host "Удачно обновили основную ветку" } | Out-Null
}

function New-ProcessingBranch {
    param([string]$BranchName)
    
    Invoke-GitOperation -Arguments @("switch", "-c", $BranchName) -OperationName "switch -c" `
        -PreOperation { Write-Host "Создадим новую ветку для новой версии метаданных: $BranchName" } `
        -PostOperation { 
        param($result)
        Write-Host "Ветка $BranchName создана успешно"
    } | Out-Null
    
    return $BranchName
}

function Add-AllNewFiles {
    Invoke-GitOperation -Arguments @("add", "*") -OperationName "add *" `
        -PostOperation { Write-Host "Добавляем новые файлы..." } | Out-Null 
}

function Push-GitCommit {
	param([string]$BranchName)
	
    Invoke-GitOperation -Arguments @("commit", "-am", "`"Обновление метаданных при автоматической обработке`"") -OperationName "commit -am" `
        -PreOperation { Write-Host "Создадим git commit..." } `
        -PostOperation { Write-Host "Git commit готов..." } | Out-Null 

    Invoke-GitOperation -Arguments @("push", "--set-upstream", "origin", $BranchName) -OperationName "push --set-upstream origin $BranchName" `
        -PostOperation { Write-Host "Отправили данные на сервер..." } | Out-Null 
}

function New-GitLabMergeRequest {
    param(
        [string]$Branch,
        [string]$Title,
        [string]$Description = ""
    )
    
    # Set your default values here
    $config = @{
        GitLabUrl    = "https://gitlab.com"
        ProjectId    = "69777976"
        AccessToken  = $env:GITLAB_TOKEN  # Store token in environment variable
        TargetBranch = "main"
    }
    
    $params = @{
        GitLabUrl    = $config.GitLabUrl
        ProjectId    = $config.ProjectId
        AccessToken  = $config.AccessToken
        SourceBranch = $Branch
        TargetBranch = $config.TargetBranch
        Title        = $Title
        Description  = $Description
    }

    Submit-MergeRequest @params | Out-Null
}

function Test-OpenMergeRequests {
    param(
        [string]$GitLabUrl = "https://gitlab.com",
        [string]$ProjectId,
        [string]$AccessToken
    )

    # Construct the API URL for listing open merge requests
    $apiUrl = "$GitLabUrl/api/v4/projects/$ProjectId/merge_requests?state=opened"

    # Prepare headers
    $headers = @{
        "PRIVATE-TOKEN" = $AccessToken
        "Content-Type"  = "application/json"
    }

    try {
        Write-Host "Проверяем наличие открытых merge запросов..." -ForegroundColor Yellow

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
        # Don't block processing if we can't check - just warn
        return $false
    }
}

function Submit-MergeRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitLabUrl,

        [Parameter(Mandatory = $true)]
        [string]$ProjectId,

        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$SourceBranch,

        [Parameter(Mandatory = $true)]
        [string]$TargetBranch,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [string]$Description = "",
        [string]$AssigneeId = "",
        [string]$ReviewerId = "",
        [bool]$RemoveSourceBranch = $true
    )

    # Construct the API URL
    $apiUrl = "$GitLabUrl/api/v4/projects/$ProjectId/merge_requests"

    # Prepare headers
    $headers = @{
        "PRIVATE-TOKEN" = $AccessToken
        "Content-Type"  = "application/json"
    }

    # Prepare the request body
    $body = @{
        source_branch        = $SourceBranch
        target_branch        = $TargetBranch
        title                = $Title
        description          = $Description
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
        Write-Host "Исходная ветка: $SourceBranch -> Целевая ветка: $TargetBranch" -ForegroundColor Cyan

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
        }
        else {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }

        throw
    }

}

Export-ModuleMember -Function Test-GitConnection, Switch-ToMainBranch, Update-MainBranch, New-ProcessingBranch,
                                Add-AllNewFiles, Push-GitCommit, New-GitLabMergeRequest, Test-OpenMergeRequests 