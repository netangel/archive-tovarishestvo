Param(
    # Archive metadata path
    [Parameter(Mandatory, HelpMessage = "Путь к папке с метаданными")]
    [string]$MetadataPath,
    # Zola content directory
    [Parameter(Mandatory, HelpMessage = "Путь к папке содержимого сайта")]
    [string]$ZolaContentPath
)

Import-Module (Join-Path $PSScriptRoot "libs/ZolaContentHelper.psm1") -Force

# Validate input paths
if (-not (Test-Path $MetadataPath) -or -not (Test-Path $MetadataPath -PathType Container)) {
    throw "Metadata path '$MetadataPath' does not exist"
}

# Проверим, если папка содержимого сайта существует, иначе создадим ее
if (-not (Test-Path $ZolaContentPath)) {
    New-Item -Path $ZolaContentPath -ItemType Directory | Out-Null
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
    Get-ChildItem -Path $MetadataPath -Filter "*.json" -Recurse
    | Where-Object { $_.Directory.Name -ne "scripts" } 
    | ForEach-Object {
        Write-Host "Processing $($_.FullName)"
        Format-JsonFileIntoContent -JsonPath $_.FullName -OutputPath $ZolaContentPath
    }
}
catch {
    Write-Error "Error processing files: $_"
    exit 1
}
