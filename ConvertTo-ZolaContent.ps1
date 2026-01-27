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
if (-not (Test-Path $MetadataPath) -or -not (Test-Path $MetadataPath -PathType Container))
{
    throw "Metadata path '$MetadataPath' does not exist"
}

# Проверим, если папка содержимого сайта существует, иначе создадим ее
if (-not (Test-Path $ZolaContentPath))
{
    New-Item -Path $ZolaContentPath -ItemType Directory | Out-Null
}

# Main execution
try
{
    # Ensure output directory exists
    if (-not (Test-Path $ZolaContentPath))
    {
        New-Item -ItemType Directory -Path $ZolaContentPath -Force | Out-Null
    }

    # Remove old metadata directories while preserving static pages
    # Strategy: Delete all directories except those in current metadata or known static pages
    # Known static directories to preserve (from template repository)
    $staticDirs = @('about', 'contact')

    # Remove directories that are not in current metadata and not static
    Get-ChildItem -Path $ZolaContentPath -Directory | ForEach-Object {
        $dirName = $_.Name
        if ($dirName -notin $staticDirs)
        {
            Write-Host "Removing old metadata directory: $dirName"
            Remove-Item -Path $_.FullName -Recurse -Force
        }
    }

    # Create or update root _index.md
    New-RootIndexPage -OutputPath $ZolaContentPath

    # Process all JSON files
    Get-ChildItem -Path $MetadataPath -Filter "*.json" -Recurse
    | Where-Object { $_.FullName -notmatch [regex]::Escape([IO.Path]::DirectorySeparatorChar + "scripts" + [IO.Path]::DirectorySeparatorChar) }
    | ForEach-Object {
        Write-Host "Processing $($_.FullName)"
        Format-JsonFileIntoContent -JsonPath $_.FullName -OutputPath $ZolaContentPath
    }
} catch
{
    Write-Error "Error processing files: $_"
    exit 1
}
