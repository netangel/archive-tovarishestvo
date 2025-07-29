[CmdletBinding()]
param()

# Сохраним значения флага для вывода доп. информации
# Его можем использовать в других скриптах
if ($VerbosePreference -eq "Continue") {
    $env:PARENT_VERBOSE = "true"
}

# Загрузим настройки  
$config = Get-Content "config.json" | ConvertFrom-Json -AsHashtable

$requiredPaths = [ordered]@{
    SourcePath = "Корневая директория с отсканированными чертежами"
    ResultPath = "Директория с чертежами для публикации"
}

Import-Module (Join-Path $PSScriptRoot "libs/ToolsHelper.psm1")  -Force
Import-Module (Join-Path $PSScriptRoot "libs/PathHelper.psm1")   -Force
Import-Module (Join-Path $PSScriptRoot "libs/GitHelper.psm1")    -Force

$results = $requiredPaths.Keys | ForEach-Object {
    $key = $_
    $path = ([string]::IsNullOrWhiteSpace($config[$key])) ? ( Read-Host $requiredPaths[$key] ) : $config[$key]

    try {
        [PSCustomObject]@{
            Type = 'Checked'
            OriginalPath = $key
            Result = Test-RequiredPathsAndReturn $path $PSScriptRoot 
            Error = $null
        }
    }
    catch {
        [PSCustomObject]@{
            Type = 'Error'
            OriginalPath = $key
            Result = $null
            Error = $_.Exception.Message
        }
    }
} | Group-Object Type -AsHashTable

# Проверим путь к папке метаданных
$goodResultPath = $results['Checked'] | Where-Object { $_.OriginalPath -eq "ResultPath" }
$FullMetadataPath = $null
if ($goodResultPath) {
    $FullMetadataPath = Join-Path $goodResultPath.Result $MetadataDir
    if (-not (Test-Path $FullMetadataPath))
    {
        New-Item -Path $goodResultPath.Result -ItemType Directory -Name $MetadataDir | Out-Null
    }
}

# Если есть ошибки при проверки папок, покажем их и завершим работу
$errors = $results['Error']
if ($errors.Count -gt 0)
{
    Write-Host "`n❌ Папки не существуют: ($($errors.Count)):" -ForegroundColor Red  
    $errors | ForEach-Object { Write-Host "  $($_.OriginalPath): $($_.Error)" }
    
    exit 1
}

$results['Checked'] | ForEach-Object {
    Write-Host "📂 Путь $($_.OriginalPath) указан как: $($_.Result)" -ForegroundColor Green
    $config[$_.OriginalPath] = $_.Result
}

# Проверим, если установлены необходимые инструменты
if (-not (Test-RequiredTools)) {
    Write-Warning "❌ Необходимые инструменты не установлены. Скрипт завершает работу."
    exit 1
}

# Проверим состояние репозитория в папке метаданных
# Если репозитарий есть – обновим основную ветку и создадим новую, 
# для отcлеживания результатов обработки
$metadataGitUrl = $config['GitRepoUrl']
if ([string]::IsNullOrWhiteSpace($metadataGitUrl)) {
    $metadataGitUrl = Read-Host "Адрес git репозитория для хранения метаданных"
    $config['GitRepoUrl'] = $metadataGitUrl
}

Write-Host "🌍 Адрес репозитория git: $($metadataGitUrl)" -ForegroundColor Green

# Сохраним конфигурацию
$config | ConvertTo-Json | Out-File -FilePath "config.json" -Encoding UTF8

Write-Host "🚀 Начинаем процесс обработки отсканированных файлов" -ForegroundColor DarkYellow

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$branchName = "processing-results-$timestamp"

$pwshPath = Get-CrossPlatformPwsh

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

$convertScansProcess = Start-Process -FilePath $pwshPath `
        -ArgumentList "-File", "./Convert-ScannedFIles.ps1", "-SourcePath", $config['SourcePath'], "-ResultPath", $config['ResultPath'] `
        -Wait -PassThru -NoNewWindow 

if ($convertScansProcess.ExitCode -ne 0) {
    Write-Warning "❌ Ошибка при обработке файлов архива"
    exit 1
}

$gitSubmitProcess = Start-Process -FilePath $pwshPath `
        -ArgumentList "-File", "./Submit-MetadataToRemote.ps1", "-GitDirectory", $FullMetadataPath, "-GitBranch", $branchName `
        -Wait -PassThru -NoNewWindow

if ($gitSubmitProcess.ExitCode -ne 0)
{
    Write-Warning "❌ Не получилось создать и отправить список изменений"
    exit 1
}

$projectId = $config['GitlabProjectId']
if ([string]::IsNullOrWhiteSpace($projectId)) {
    $projectId = Read-Host "ProjectId для рапозитория на Gitlab"
    $config['GitRepoUrl'] = $projectId
}

New-GitLabMergeRequest -Branch $branchName -Title "Результаты обработки $timestamp" 
