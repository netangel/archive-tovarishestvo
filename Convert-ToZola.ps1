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

if (-not (Test-Path $ZolaContentPath) -or -not (Test-Path $ZolaContentPath -PathType Container)) {
    throw "Zola content path '$ZolaContentPath' does not exist"
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