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

<# 
This script initializes the metadata JSON file based on
files which have been already processed (historical data)

The input parameters are:
    * "DoneScannnedPath" directory path (relative or full) with scanned prints originals, either pdf or tif,
        file names can be in Russian (un-formatted and un-processed)
    * "ArchiveContentPath" directory path with result of previous version of script, with next configuration:
        - transliterated sub-folder names
        - transliterated scanned file names
        - two formats of scanned files: tif (orininal pdf is converted into tif) and png (ligther version for browser preview)
        - Thumbnails sub-directory with smaller (400px wide) variant of the scanned files,
            thumbnail has the same name as the processed scan
    * "MetadataPath" output directory where to store JSON metadata files structure

The script does:

1. read sub-directories in DoneScannnedPath, and for each:
    1.1. Check if transliterated counterpart directory exists in ArchiveContentPath (transliteration function to be used is ConvertTo-Translit)
            - yes: print Info with transliterated name, store full path for transliterated in ProcessedArchiveSubDir variable
            - no: print warning and skip to the next sub-directory
    1.2. Create an empty data structure similar as in Read-ResultDirectoryMetadata function
    1.3. Read each scanned original hash code using Get-Blake3Hash 
    1.4. similar to Convert-FileAndCreateData function:
        - transliterate original name, check if transliterated filename exists in ProcessedArchiveSubDir, both for tif and png variants
            - yes: print Info with transliterated filename
            - no: skip to the next original scan
        - create and return data structure which describes the processed scan, in the form:
            [PSCustomObject]@{
                ResultFileName = $TranslitFileName
                OriginalName   = $SourceFile.Name
                PngFile        = $pngFile
                MultiPage      = $false
                Tags           = Get-TagsFromName $SourceFile.BaseName
                Year           = Get-YearFromFilename $SourceFile.BaseName
                Thumbnails     = Get-Thumbnails $OutputFileName
            }
            - for tags, year generation function use the original scan file name
    1.5. add checked processed scan data structure in the directory data structure under the key = original file hash
    1.6. save directory metadata under <transliterated name>.json at MetadataPath 
#>

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
    Write-Host "Created metadata directory: $FullMetadataPath"
}

Write-Host "Starting metadata initialization..."
Write-Host "Source scanned files: $FullDoneScannnedPath"
Write-Host "Processed archive content: $FullArchiveContentPath"
Write-Host "Metadata output: $FullMetadataPath"

# Get all subdirectories in DoneScannnedPath
$SourceDirectories = Get-ChildItem -Path $FullDoneScannnedPath -Directory

foreach ($SourceDir in $SourceDirectories) {
    Write-Host "`nProcessing directory: $($SourceDir.Name)"
    
    # 1.1. Check if transliterated counterpart directory exists
    $TransliteratedDirName = ConvertTo-Translit $SourceDir.Name
    $ProcessedArchiveSubDir = Join-Path $FullArchiveContentPath $TransliteratedDirName
    
    if (-not (Test-Path $ProcessedArchiveSubDir)) {
        Write-Warning "No transliterated counterpart found for '$($SourceDir.Name)' (expected: '$TransliteratedDirName'). Skipping."
        continue
    }
    
    Write-Host "  ✓ Found processed directory: $TransliteratedDirName" -ForegroundColor Green
    
    # 1.2. Create empty data structure similar to Read-ResultDirectoryMetadata
    $DirectoryMetadata = [PSCustomObject]@{
        Directory    = $TransliteratedDirName
        OriginalName = $SourceDir.Name  
        Description  = $null
        Files        = [PSCustomObject]@{}
    }
    
    # Get all scanned files in source directory (pdf and tif)
    $SourceFiles = Get-ChildItem -Path $SourceDir.FullName -File | Where-Object { $_.Extension -in @('.pdf', '.tif') }
    
    Write-Host "  Found $($SourceFiles.Count) scanned files to process"
    
    foreach ($SourceFile in $SourceFiles) {
        Write-Host "    Processing file: $($SourceFile.Name)"
        
        try {
            # 1.3. Get Blake3 hash of original file
            $OriginalFileHash = Get-Blake3Hash -FilePath $SourceFile.FullName
            Write-Verbose "    Blake3 hash: $OriginalFileHash"
            
            # 1.4. Check if transliterated files exist in processed directory
            $TranslitFileName = (ConvertTo-Translit $SourceFile.BaseName) + '.tif'
            $PngFileName = (ConvertTo-Translit $SourceFile.BaseName) + '.png'
            
            $TifFilePath = Join-Path $ProcessedArchiveSubDir $TranslitFileName
            $PngFilePath = Join-Path $ProcessedArchiveSubDir $PngFileName
            
            if (-not (Test-Path $TifFilePath) -or -not (Test-Path $PngFilePath)) {
                Write-Warning "    Processed files not found for '$($SourceFile.Name)' (expected: '$TranslitFileName' and '$PngFileName'). Skipping."
                continue
            }
            
            Write-Host "    ✓ Found processed files: $TranslitFileName, $PngFileName" -ForegroundColor Green
            
            # Create thumbnails data structure
            $ThumbnailsData = [PSCustomObject]@{
                400 = $TranslitFileName.Replace('.tif', '.png')  # Assuming thumbnail naming convention
            }
            
            # Create processed scan data structure
            $ProcessedScanData = [PSCustomObject]@{
                ResultFileName = $TranslitFileName
                OriginalName   = $SourceFile.Name
                PngFile        = $PngFileName
                MultiPage      = $false
                Tags           = Get-TagsFromName $SourceFile.BaseName
                Year           = Get-YearFromFilename $SourceFile.BaseName
                Thumbnails     = $ThumbnailsData
            }
            
            # 1.5. Add processed scan data to directory metadata using original file hash as key
            $DirectoryMetadata.Files | Add-Member -NotePropertyName $OriginalFileHash -NotePropertyValue $ProcessedScanData
            
            Write-Host "    ✓ Added metadata for file" -ForegroundColor Green
        }
        catch {
            Write-Error "    Error processing file '$($SourceFile.Name)': $_"
            continue
        }
    }
    
    # 1.6. Save directory metadata as JSON file
    $JsonFileName = "$TransliteratedDirName.json"
    $JsonFilePath = Join-Path $FullMetadataPath $JsonFileName
    
    try {
        $DirectoryMetadata | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonFilePath -Encoding UTF8
        Write-Host "  ✓ Saved metadata to: $JsonFileName" -ForegroundColor Green
        Write-Host "  Total files processed: $(($DirectoryMetadata.Files | Get-Member -MemberType NoteProperty).Count)"
    }
    catch {
        Write-Error "  Failed to save metadata file '$JsonFileName': $_"
    }
}

Write-Host "`nMetadata initialization completed!" -ForegroundColor Green