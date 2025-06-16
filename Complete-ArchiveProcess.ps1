# Загрузим настройки  
$config = Get-Content "config.json" | ConvertFrom-Json -AsHashtable

$requiredPaths = [ordered]@{
    SourcePath = "Корневая директория с отсканированными чертежами"
    ResultPath = "Директория с чертежами для публикации"
    ZolaContentPath = "Директория для шаблонов генерации сайта"
}

Import-Module (Join-Path $PSScriptRoot "libs/PathHelper.psm1")   -Force

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
if ($goodResultPath) {
    try {
        Test-RequiredPathsAndReturn (Join-Path $goodResultPath.Result $MetadataDir)
    }
    catch {
        $results['Error'] += [PSCustomObject]@{
            OriginalPath = "metadata"
            Result = $null
            Error = $_.Exception.Message 
            Type = "Error"
        }
    }
}

# Если есть ошибки при проверки папок, покажем их и завершим работу
$errors = $results['Error']
if ($errors.Count -gt 0)
{
    Write-Host "`nПапки не существуют: ($($errors.Count)):" -ForegroundColor Red  
    $errors | ForEach-Object { Write-Host "  $($_.OriginalPath): $($_.Error)" }
    
    exit 1;
}

$results['Checked'] | ForEach-Object {
    Write-Host "📂 Путь $($_.OriginalPath) указан как: $($_.Result)" -ForegroundColor Green
    $config[$_.OriginalPath] = $_.Result
}


# Сохраним конфигурацию
$config | ConvertTo-Json | Out-File -FilePath "config.json" -Encoding UTF8