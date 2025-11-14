# Test script for verifying open merge request check functionality
# This script tests the Test-OpenMergeRequests function

param(
    [switch]$Verbose
)

if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Import the GitHelper module
Import-Module (Join-Path $PSScriptRoot "libs/GitHelper.psm1") -Force

# Load configuration
$config = Get-Content "config.json" | ConvertFrom-Json -AsHashtable

# Get GitLab credentials
$projectId = $config['GitlabProjectId']
$gitlabToken = $env:GITLAB_TOKEN

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Тест проверки открытых Merge Requests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate prerequisites
if ([string]::IsNullOrWhiteSpace($projectId)) {
    Write-Host "❌ GitlabProjectId не найден в config.json" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($gitlabToken)) {
    Write-Host "❌ GITLAB_TOKEN не найден в переменных окружения" -ForegroundColor Red
    Write-Host "   Установите переменную окружения: `$env:GITLAB_TOKEN = 'your-token'" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Конфигурация:" -ForegroundColor Green
Write-Host "   Project ID: $projectId" -ForegroundColor Gray
Write-Host "   Token: $('*' * 10)$($gitlabToken.Substring([Math]::Max(0, $gitlabToken.Length - 4)))" -ForegroundColor Gray
Write-Host ""

# Test the function
try {
    Write-Host "Запускаем проверку..." -ForegroundColor Yellow
    Write-Host ""

    $hasOpenMRs = Test-OpenMergeRequests -ProjectId $projectId -AccessToken $gitlabToken

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Результат теста:" -ForegroundColor Cyan

    if ($hasOpenMRs) {
        Write-Host "⚠️  Функция корректно обнаружила открытые MR" -ForegroundColor Yellow
        Write-Host "   Обработка была бы прервана" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Открытых MR не найдено" -ForegroundColor Green
        Write-Host "   Обработка может продолжиться" -ForegroundColor Green
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "✅ Тест завершен успешно!" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "❌ Ошибка при выполнении теста:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}
