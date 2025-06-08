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
    if (-not (Test-Path $GitDirectory)) {
        Exit-WithError "Папка отсутствует: $GitDirectory"
    }
    
    Set-Location $GitDirectory
    Write-Host "Переход в директорию: $GitDirectory"
    
    if (-not (Test-Path ".git")) {
        Exit-WithError "В текущей папке нет инициализированного git-репозитория: $GitDirectory"
    }
    
    $remoteUrl = git remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Git-репозиторий не связан ни с каким внешним репозиторием"
    }
    
    # Normalize URLs for comparison (remove .git suffix and trailing slashes)
    $normalizedRemote = $remoteUrl.TrimEnd('/').TrimEnd('.git')
    $normalizedUpstream = $UpstreamUrl.TrimEnd('/').TrimEnd('.git')
    
    if ($normalizedRemote -ne $normalizedUpstream) {
        Exit-WithError "URL внешнего репозитория ($remoteUrl) не соответвует ожидаемому ($UpstreamUrl)"
    }
    
    Write-Host "Репозиторий в папке связан с внешним URL: $remoteUrl"
    
    # 3. Check current user connection to git repository
    Write-Host "Проверяем подключение к внешнему репозиторию..."
    git ls-remote origin HEAD 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Нет возможности получить данные с внешнего репозитория, отсутсвует доступ или соединение"
    }
    
    # 4. Switch to main branch and pull latest changes
    # Check current branch
    $currentBranch = git branch --show-current 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Не смогли получить информацию о текущей ветке"
    }
    
    if ($currentBranch -ne "main") {
        Write-Host "Переключаемся с ветки $currentBranch на main.."
        git switch main 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Exit-WithError "Не получилось переключиться на main"
        }
    } else {
        Write-Host "Уже на ветке main"
    }

    Write-Host "Получаем последние изменения с сервера..."
    git pull origin main 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Ошибка в получении последних данных для ветки main"
    }
    
    Write-Host "Данные с сервера получены успешно"
    
    # 5. Create and switch to new branch with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $branchName = "processing-results-$timestamp"
    
    Write-Host "Создадим новую ветку для новой версии метаданных: $branchName"
    git checkout -b $branchName 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Ошибка создания новой ветки: $branchName"
    }
    
    Write-Host "Мы теперь в новой ветке $branchName и готовы работать дальше!"
    
    # Return success
    exit 0
    
} catch {
    Exit-WithError "Unexpected error: $($_.Exception.Message)"
}