# Private functions
# Git command invocation
function Invoke-GitCommand
{
    param(
        [string[]]$Arguments
    )

    # Create temporary files for capturing streams
    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try
    {
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
        $stdout = if ((Test-Path $stdoutFile) -and (Get-Item $stdoutFile).Length -gt 0)
        {
            (Get-Content $stdoutFile -Raw).Trim()
        } else
        { ""
        }

        $stderr = if ((Test-Path $stderrFile) -and (Get-Item $stderrFile).Length -gt 0)
        {
            (Get-Content $stderrFile -Raw).Trim()
        } else
        { ""
        }

        return @{
            ExitCode = $process.ExitCode
            StdOut   = $stdout
            StdErr   = $stderr
            Success  = $process.ExitCode -eq 0
        }
    } finally
    {
        # Clean up temp files
        if (Test-Path $stdoutFile)
        { Remove-Item $stdoutFile -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $stderrFile)
        { Remove-Item $stderrFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# Base git operation function
function Invoke-GitOperation
{
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

    if (-not $result.Success -or -not $isValid)
    {
        exit 1
    }

    # Execute post-operation logic
    & $PostOperation $result

    return $result
}

# Function to log git command results
function Write-GitLog
{
    param(
        [string]$Operation,
        [hashtable]$Result
    )

    if ($Result.StdOut)
    {
        Write-Host "Команда: git $Operation, STDOUT: $($Result.StdOut)"
    } elseif ($Result.StdErr)
    {
        Write-Host "Команда: git $Operation, STDERR: $($Result.StdErr)"
    }
}

function Test-GitConnection
{
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

function Switch-ToMainBranch
{
    $result = Invoke-GitOperation -Arguments @("branch", "--show-current") -OperationName "branch"
    $currentBranch = $result.StdOut.Trim()

    if ($currentBranch -ne "main")
    {
        Invoke-GitOperation -Arguments @("switch", "main") -OperationName "switch main" `
            -PreOperation { Write-Host "Переключаемся на основную ветку (текущая ветка: $currentBranch)..." } | Out-Null
    }
}

function Update-MainBranch
{
    Invoke-GitOperation -Arguments @("pull", "origin", "main") -OperationName "pull origin" `
        -PreOperation { Write-Host "Получаем последние изменения..." } `
        -PostOperation { Write-Host "Удачно обновили основную ветку" } | Out-Null
}

function New-ProcessingBranch
{
    param([string]$BranchName)

    Invoke-GitOperation -Arguments @("switch", "-c", $BranchName) -OperationName "switch -c" `
        -PreOperation { Write-Host "Создадим новую ветку для новой версии метаданных: $BranchName" } `
        -PostOperation {
        param($result)
        Write-Host "Ветка $BranchName создана успешно"
    } | Out-Null

    return $BranchName
}

function Add-AllNewFiles
{
    Invoke-GitOperation -Arguments @("add", "*") -OperationName "add *" `
        -PostOperation { Write-Host "Добавляем новые файлы..." } | Out-Null
}

function Push-GitCommit
{
    param([string]$BranchName)

    Invoke-GitOperation -Arguments @("commit", "-am", "`"Обновление метаданных при автоматической обработке`"") -OperationName "commit -am" `
        -PreOperation { Write-Host "Создадим git commit..." } `
        -PostOperation { Write-Host "Git commit готов..." } | Out-Null

    Invoke-GitOperation -Arguments @("push", "--set-upstream", "origin", $BranchName) -OperationName "push --set-upstream origin $BranchName" `
        -PostOperation { Write-Host "Отправили данные на сервер..." } | Out-Null
}

# Import the provider module
Import-Module "$PSScriptRoot/GitServerProvider.psm1" -Force

# Function to create merge request using the provider pattern
function New-GitServerMergeRequest
{
    param(
        [Parameter(Mandatory = $true)]
        [object]$Provider,

        [Parameter(Mandatory = $true)]
        [string]$Branch,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [string]$Description = "",

        [string]$TargetBranch = "main",

        [bool]$RemoveSourceBranch = $true
    )

    $Provider.SubmitMergeRequest($Branch, $TargetBranch, $Title, $Description, $RemoveSourceBranch) | Out-Null
}

# Function to test for open merge/pull requests
function Test-OpenMergeRequests
{
    param(
        [Parameter(Mandatory = $true)]
        [object]$Provider
    )

    return $Provider.TestOpenMergeRequests()
}

# Legacy function for backward compatibility (now uses GitLab provider by default)
function New-GitLabMergeRequest
{
    param(
        [string]$Branch,
        [string]$Title,
        [string]$Description = ""
    )

    # Set your default values here
    $config = @{
        GitLabUrl    = "https://gitlab.com"
        ProjectId    = "69777976"
        AccessToken  = $env:GITLAB_TOKEN
        TargetBranch = "main"
    }

    $provider = New-GitServerProvider -ProviderType "GitLab" `
        -ServerUrl $config.GitLabUrl `
        -ProjectId $config.ProjectId `
        -AccessToken $config.AccessToken

    New-GitServerMergeRequest -Provider $provider `
        -Branch $Branch `
        -Title $Title `
        -Description $Description `
        -TargetBranch $config.TargetBranch
}

Export-ModuleMember -Function Test-GitConnection, Switch-ToMainBranch, Update-MainBranch, New-ProcessingBranch,
Add-AllNewFiles, Push-GitCommit, New-GitLabMergeRequest, Test-OpenMergeRequests,
New-GitServerMergeRequest
