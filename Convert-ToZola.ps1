# Параметры
Param(
    # Archive metadata path
    [Parameter(Mandatory, HelpMessage = "Путь к папке с метаданными")]
    [string]$MetadataPath,
    # Zola content directory
    [Parameter(Mandatory, HelpMessage = "Путь к папке содержимого сайта")]
    [string]$ZolaContentPath
)

function New-RootIndexPage {
    param (
        [string]$OutputPath
    )

    $content = @"
+++
sort_by = "title"
template = "index.html"
+++
"@

    $content | Out-File -FilePath (Join-Path $OutputPath "_index.md") -Encoding utf8
}

function New-SectionPage {
    param (
        [string]$Directory,
        [string]$OriginalName,
        [string]$OutputPath
    )

    $sectionPath = Join-Path $OutputPath $Directory
    New-Item -ItemType Directory -Path $sectionPath -Force | Out-Null

    $content = @"
+++
title = "$OriginalName"
sort_by = "title"
template = "section.html"
page_template = "page.html"
in_search_index = true

[extra]
directory_name = "$Directory"
+++
"@

    $content | Out-File -FilePath (Join-Path $sectionPath "_index.md") -Encoding utf8
}

function New-ContentPage {
    param (
        [string]$Directory,
        [string]$FileId,
        [PSCustomObject]$FileData,
        [string]$OutputPath
    )

    $pagePath = Join-Path $OutputPath $Directory
    New-Item -ItemType Directory -Path $pagePath -Force | Out-Null

    $title = $FileData.OriginalName -replace '\.tif$', ''
    $tags = $FileData.Tags
    $year = $FileData.Year
    $tifFile = $FileData.ResultFileName
    $pngFile = $FileData.PngFile
    $thumbnail = if ($FileData.Thumbnails.PSObject.Properties['400']) { $FileData.Thumbnails.'400' } else { $null }

    # Create front matter
    $frontMatter = @"
+++
title = "$title"
draft = false
file_id = "$FileId"

[extra]
directory_name = "$Directory"

"@

    if ($year) {
        $frontMatter += @"
scan_year = "$year"

"@
    }

    if ($tifFile) {
        $frontMatter += @"
tif_file = "$tifFile"

"@
    }
    
    if ($pngFile) {
        $frontMatter += @"
png_file = "$pngFile"

"@
    }

    if ($thumbnail) {
        $frontMatter += @"
thumbnail = "$thumbnail"

"@
    }

    if ($tags -and $tags.Count -gt 0) {
        $tagsJson = $tags | ConvertTo-Json -Compress
        $frontMatter += @"

[taxonomies]
tags = $tagsJson

"@
    }

    $frontMatter += @"

+++
"@

    $frontMatter | Out-File -FilePath (Join-Path $pagePath "$FileId.md") -Encoding utf8
}

function Format-JsonFileIntoContent {
    param (
        [string]$JsonPath,
        [string]$OutputPath
    )

    $jsonContent = Get-Content $JsonPath -Raw -Encoding utf8 | ConvertFrom-Json
    $directory = $jsonContent.Directory
    $originalName = $jsonContent.OriginalName

    # Create section
    New-SectionPage -Directory $directory -OutputPath $OutputPath -OriginalName $originalName

    # Create pages for each file
    $jsonContent.Files.PSObject.Properties | ForEach-Object {
        $fileId = $_.Name
        $fileData = $_.Value
        New-ContentPage -Directory $directory -FileId $fileId -FileData $fileData -OutputPath $OutputPath
    }
}

# Main execution
try {
    # Ensure output directory exists and is empty
    if (Test-Path $ZolaContentPath) {
        Remove-Item -Path $ZolaContentPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $ZolaContentPath -Force | Out-Null

    # Create root _index.md
    New-RootIndexPage -OutputPath $ZolaContentPath

    # Process all JSON files
    Get-ChildItem -Path $MetadataPath -Filter "*.json" -Recurse | ForEach-Object {
        Write-Host "Processing $($_.FullName)"
        Format-JsonFileIntoContent -JsonPath $_.FullName -OutputPath $ZolaContentPath
    }
}
catch {
    Write-Error "Error processing files: $_"
    exit 1
}