[CmdletBinding()]
param()

# Сохраним значения флага для вывода доп. информации
# Его можем использовать в других скриптах
if ($VerbosePreference -eq "Continue") {
    $env:PARENT_VERBOSE = "true"
}

# ============================================================================
# Environment and Configuration Validation
# ============================================================================
Write-Host "🔍 Validating environment and configuration..." -ForegroundColor Cyan

# Import required modules for the main process
Import-Module (Join-Path $PSScriptRoot "libs/ToolsHelper.psm1")  -Force
Import-Module (Join-Path $PSScriptRoot "libs/PathHelper.psm1")   -Force
Import-Module (Join-Path $PSScriptRoot "libs/GitHelper.psm1")    -Force
Import-Module (Join-Path $PSScriptRoot "libs/GitServerProvider.psm1") -Force

$pwshPath = Get-CrossPlatformPwsh

$validationOutputFile = New-TemporaryFile

try {
    # Run the validation script and capture all output
    $validationOutput = & $pwshPath -File "./Test-EnvironmentConfiguration.ps1" -OutputFile $validationOutputFile.FullName 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "❌ Environment validation failed" -ForegroundColor Red
        Write-Host ""
        # Display the captured error output
        $validationOutput | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        exit 1
    }

    # Parse the JSON output
    try {
        $validationResult = Get-Content $validationOutputFile.FullName -Raw | ConvertFrom-Json

        # Extract validated paths
        $validatedSourcePath = $validationResult.Paths.SourcePath
        $validatedResultPath = $validationResult.Paths.ResultPath
        $FullMetadataPath = $validationResult.Paths.MetadataPath

        Write-Host "✅ Environment validation passed" -ForegroundColor Green
        Write-Host ""

    } catch {
        Write-Host ""
        Write-Host "❌ Failed to parse validation output: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} finally {
    Remove-Item $validationOutputFile.FullName -Force -ErrorAction SilentlyContinue
}

# Reload configuration (in case it was updated by the validation script)
$config = Get-Content "config.json" | ConvertFrom-Json -AsHashtable

# Create Git service provider if git checks passed
$gitProvider = $null
if ($validationResult.IsGitProviderAvailable) {
    $gitServerType = $config['GitServerType']
    $gitServerUrl = $config['GitServerUrl']
    $gitProjectId = $config['GitProjectId']

    $accessToken = switch ($gitServerType) {
        "GitLab" { $env:GITLAB_TOKEN }
        "Gitea" { $env:GITEA_TOKEN }
        default { $null }
    }

    if ($accessToken) {
        $gitProvider = New-GitServerProvider -ProviderType $gitServerType `
                                             -ServerUrl $gitServerUrl `
                                             -ProjectId $gitProjectId `
                                             -AccessToken $accessToken
    }
}

$metadataGitUrl = $config['GitRepoUrl']

Write-Host "🚀 Начинаем процесс обработки отсканированных файлов" -ForegroundColor DarkYellow

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$branchName = "processing-results-$timestamp"

$gitCheckProcess = Start-Process -FilePath $pwshPath `
        -ArgumentList "-File", "./Sync-MetadataGitRepo.ps1", "-GitDirectory", $FullMetadataPath, "-UpstreamUrl", $metadataGitUrl, `
            "-BranchName", $branchName `
        -Wait -PassThru -NoNewWindow

# Проблема с репозиторием
if ($gitCheckProcess.ExitCode -ne 0) {
    Write-Warning "❌ В папке metadata нет корректно настроенного git репозитория"
    # TODO: создать репозиторий?
    exit 1
}

# Начинаем конвертацию файлов
$convertScansProcess = Start-Process -FilePath $pwshPath `
        -ArgumentList "-File", "./Convert-ScannedFIles.ps1", "-SourcePath", $validatedSourcePath, "-ResultPath", $validatedResultPath `
        -Wait -PassThru -NoNewWindow 

if ($convertScansProcess.ExitCode -ne 0) {
    Write-Warning "❌ Ошибка при обработке файлов архива"
    exit 1
}

$gitSubmitProcess = Start-Process -FilePath $pwshPath `
        -ArgumentList "-File", "./Submit-MetadataToRemote.ps1", "-GitDirectory", $FullMetadataPath, "-GitBranch", $branchName `
        -Wait -PassThru -NoNewWindow

if ($gitSubmitProcess.ExitCode -eq 2)
{
    Write-Host "ℹ️  Нечего публиковать: изменений не обнаружено" -ForegroundColor Yellow
    exit 0
}

if ($gitSubmitProcess.ExitCode -ne 0)
{
    Write-Warning "❌ Не получилось создать и отправить список изменений"
    exit 1
}

# Создание merge/pull запроса
if ($gitProvider) {
    New-GitServerMergeRequest -Provider $gitProvider `
                              -Branch $branchName `
                              -Title "Результаты обработки $timestamp" `
                              -TargetBranch "main"
} else {
    Write-Warning "⚠️  Git provider недоступен, пропускаем создание merge/pull запроса"
} 
