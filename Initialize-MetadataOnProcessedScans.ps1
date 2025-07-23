param(
    [Parameter(Mandatory=$true)]
    [string]$DoneScannnedPath,
    
    [Parameter(Mandatory=$true)]
    [string]$ArchiveContentPath,
    
    [Parameter(Mandatory=$true)]
    [string]$MetadataPath
)

# Import required modules
Import-Module (Join-Path $PSScriptRoot "libs/ConvertText.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "libs/HashHelper.psm1") -Force  
Import-Module (Join-Path $PSScriptRoot "libs/JsonHelper.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "libs/PathHelper.psm1") -Force


# Ensure Blake3 is available
Ensure-Blake3Available | Out-Null

# Convert paths to full paths and validate
$FullDoneScannnedPath = Test-RequiredPathsAndReturn -SourcePath $DoneScannnedPath $PSScriptRoot -ErrorMessage "DoneScannnedPath не найдена: {0}"
$FullArchiveContentPath = Test-RequiredPathsAndReturn -SourcePath $ArchiveContentPath $PSScriptRoot -ErrorMessage "ArchiveContentPath не найдена: {0}"

# For metadata path, create if doesn't exist, otherwise validate
if (Test-IsFullPath $MetadataPath) {
    $FullMetadataPath = $MetadataPath
} else {
    $FullMetadataPath = Join-Path $PSScriptRoot $MetadataPath
}

# Create metadata directory if it doesn't exist
if (-not (Test-Path $FullMetadataPath)) {
    New-Item -ItemType Directory -Path $FullMetadataPath -Force | Out-Null
    Write-Host "Создана директория метаданных: $FullMetadataPath"
}

# Initialize counters for statistics
$Stats = @{
    ProcessedDirectories = 0
    SkippedDirectories = 0
    ProcessedFiles = 0
    SkippedFiles = 0
    MultiPageFiles = 0
    Warnings = 0
    Errors = 0
}

Write-Host "Начинается инициализация метаданных..."
Write-Host "Исходные отсканированные файлы: $FullDoneScannnedPath"
Write-Host "Обработанное содержимое архива: $FullArchiveContentPath"
Write-Host "Вывод метаданных: $FullMetadataPath"

# Get all subdirectories in DoneScannnedPath
$SourceDirectories = Get-ChildItem -Path $FullDoneScannnedPath -Directory

foreach ($SourceDir in $SourceDirectories) {
    Write-Host "`nОбработка директории: $($SourceDir.Name)"
    
    # 1.1. Check if transliterated counterpart directory exists
    $TransliteratedDirName = ConvertTo-Translit $SourceDir.Name
    $ProcessedArchiveSubDir = Join-Path $FullArchiveContentPath $TransliteratedDirName
    
    if (-not (Test-Path $ProcessedArchiveSubDir)) {
        Write-Warning "Не найден транслитерированный аналог для '$($SourceDir.Name)' (ожидается: '$TransliteratedDirName'). Пропускается."
        $Stats.Warnings++
        $Stats.SkippedDirectories++
        continue
    }
    
    Write-Host "  ✓ Найдена обработанная директория: $TransliteratedDirName" -ForegroundColor Green
    
    # 1.2. Create empty data structure similar to Read-ResultDirectoryMetadata
    $DirectoryMetadata = [PSCustomObject]@{
        Directory    = $TransliteratedDirName
        OriginalName = $SourceDir.Name  
        Description  = $null
        Files        = [PSCustomObject]@{}
    }
    
    # Get all scanned files in source directory (pdf and tif)
    $SourceFiles = Get-ChildItem -Path $SourceDir.FullName -File | Where-Object { $_.Extension -in @('.pdf', '.tif') }
    
    Write-Host "  Найдено $($SourceFiles.Count) отсканированных файлов для обработки"
    
    foreach ($SourceFile in $SourceFiles) {
        Write-Host "    Обработка файла: $($SourceFile.Name)"
        
        try {
            # 1.3. Get Blake3 hash of original file
            $OriginalFileHash = Get-Blake3Hash -FilePath $SourceFile.FullName
            Write-Verbose "    Blake3 hash: $OriginalFileHash"
            
            # 1.4. Check if transliterated files exist in processed directory
            $TranslitFileName = (ConvertTo-Translit $SourceFile.BaseName) + '.tif'
            $PngFileName = (ConvertTo-Translit $SourceFile.BaseName) + '.png'
            
            $TifFilePath = Join-Path $ProcessedArchiveSubDir $TranslitFileName
            $PngFilePath = Join-Path $ProcessedArchiveSubDir $PngFileName
            
            # Check if TIF file exists
            if (-not (Test-Path $TifFilePath)) {
                Write-Warning "    TIF файл не найден для '$($SourceFile.Name)' (ожидается: '$TranslitFileName'). Пропускается."
                $Stats.Warnings++
                $Stats.SkippedFiles++
                continue
            }
            
            # Initialize variables for multi-page detection
            $IsMultiPage = $false
            $PngFilePages = @()
            $ActualPngFile = $PngFileName
            
            # Check for single PNG file first
            if (Test-Path $PngFilePath) {
                # Single page case
                Write-Host "    ✓ Найдены обработанные файлы: $TranslitFileName, $PngFileName" -ForegroundColor Green
            } else {
                # Check for multi-page PNG files (filename-0.png, filename-1.png, etc.)
                $BaseNameForPng = (ConvertTo-Translit $SourceFile.BaseName)
                $MultiPagePngs = Get-ChildItem -Path $ProcessedArchiveSubDir -File | 
                    Where-Object { $_.Name -match "^$([regex]::Escape($BaseNameForPng))-\d+\.png$" } |
                    Sort-Object Name
                
                if ($MultiPagePngs.Count -gt 0) {
                    $IsMultiPage = $true
                    $ActualPngFile = $MultiPagePngs[0].Name  # Use first page as main PNG
                    $PngFilePages = $MultiPagePngs | Select-Object -ExpandProperty Name
                    $Stats.MultiPageFiles++
                    Write-Host "    ✓ Найдены обработанные файлы: $TranslitFileName, многостраничные PNG ($($MultiPagePngs.Count) страниц)" -ForegroundColor Green
                } else {
                    Write-Warning "    PNG файлы не найдены для '$($SourceFile.Name)' (ожидается: '$PngFileName' или '$BaseNameForPng-N.png'). Пропускается."
                    $Stats.Warnings++
                    $Stats.SkippedFiles++
                    continue
                }
            }
            
            # Create thumbnails data structure
            $ThumbnailsData = [PSCustomObject]@{
                400 = $TranslitFileName.Replace('.tif', '.png')  # Assuming thumbnail naming convention
            }
            
            # Create processed scan data structure
            $ProcessedScanData = [PSCustomObject]@{
                ResultFileName = $TranslitFileName
                OriginalName   = $SourceFile.Name
                PngFile        = $ActualPngFile
                MultiPage      = $IsMultiPage
                Tags           = Get-TagsFromName $SourceFile.BaseName
                Year           = Get-YearFromFilename $SourceFile.BaseName
                Thumbnails     = $ThumbnailsData
            }
            
            # Add PngFilePages array if it's a multi-page file
            if ($IsMultiPage) {
                $ProcessedScanData | Add-Member -NotePropertyName "PngFilePages" -NotePropertyValue $PngFilePages
            }
            
            # 1.5. Add processed scan data to directory metadata using original file hash as key
            $DirectoryMetadata.Files | Add-Member -NotePropertyName $OriginalFileHash -NotePropertyValue $ProcessedScanData
            $Stats.ProcessedFiles++
            
            Write-Host "    ✓ Добавлены метаданные для файла" -ForegroundColor Green
        }
        catch {
            Write-Error "    Ошибка обработки файла '$($SourceFile.Name)': $_"
            $Stats.Errors++
            $Stats.SkippedFiles++
            continue
        }
    }
    
    # 1.6. Save directory metadata as JSON file
    $JsonFileName = "$TransliteratedDirName.json"
    $JsonFilePath = Join-Path $FullMetadataPath $JsonFileName
    
    try {
        $DirectoryMetadata | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonFilePath -Encoding UTF8
        $Stats.ProcessedDirectories++
        Write-Host "  ✓ Метаданные сохранены в: $JsonFileName" -ForegroundColor Green
        Write-Host "  Всего обработано файлов: $(($DirectoryMetadata.Files | Get-Member -MemberType NoteProperty).Count)"
    }
    catch {
        Write-Error "  Не удалось сохранить файл метаданных '$JsonFileName': $_"
        $Stats.Errors++
    }
}

Write-Host "`nИнициализация метаданных завершена!" -ForegroundColor Green

# Display final statistics
Write-Host "`n" + "="*60
Write-Host "СТАТИСТИКА ВЫПОЛНЕНИЯ" -ForegroundColor Cyan
Write-Host "="*60

Write-Host "Директории:" -ForegroundColor Yellow
Write-Host "  • Обработано успешно: $($Stats.ProcessedDirectories)" -ForegroundColor Green
Write-Host "  • Пропущено: $($Stats.SkippedDirectories)" -ForegroundColor Red
Write-Host "  • Всего найдено: $($SourceDirectories.Count)"

Write-Host "`nФайлы:" -ForegroundColor Yellow  
Write-Host "  • Обработано успешно: $($Stats.ProcessedFiles)" -ForegroundColor Green
Write-Host "  • Пропущено: $($Stats.SkippedFiles)" -ForegroundColor Red
Write-Host "  • Многостраничные: $($Stats.MultiPageFiles)" -ForegroundColor Magenta

Write-Host "`nОшибки и предупреждения:" -ForegroundColor Yellow
Write-Host "  • Предупреждения: $($Stats.Warnings)" -ForegroundColor DarkYellow
Write-Host "  • Ошибки: $($Stats.Errors)" -ForegroundColor Red

$SuccessRate = if (($Stats.ProcessedFiles + $Stats.SkippedFiles) -gt 0) { 
    [math]::Round(($Stats.ProcessedFiles / ($Stats.ProcessedFiles + $Stats.SkippedFiles)) * 100, 1) 
} else { 0 }

Write-Host "`nИтого:" -ForegroundColor Yellow
Write-Host "  • Успешность обработки файлов: $SuccessRate%" -ForegroundColor $(if ($SuccessRate -ge 90) { "Green" } elseif ($SuccessRate -ge 70) { "Yellow" } else { "Red" })
Write-Host "="*60