Import-Module (Join-Path $PSScriptRoot "ToolsHelper.psm1") -Force

<#
.SYNOPSIS
Modern image processing using Poppler (pdftoppm) and libvips instead of Ghostscript and ImageMagick.

.DESCRIPTION
This module provides drop-in replacements for the ConvertImage.psm1 functions using:
- Poppler (pdftoppm/pdftocairo) for PDF to TIFF conversion (replaces Ghostscript)
- libvips for TIFF optimization, PNG conversion, and thumbnails (replaces ImageMagick)

Performance benefits:
- pdftoppm is ~2x faster than Ghostscript with better quality
- libvips is 4-8x faster than ImageMagick and uses 15x less memory

.NOTES
Cross-platform installation:
  macOS:
    brew install poppler
    brew install vips

  Windows:
    scoop install poppler
    # Download libvips from: https://github.com/libvips/libvips/releases
    # Extract and add to PATH, or use manual path resolution
#>

function Convert-PdfToTiff {
    Param(
        # Input file object
        [Parameter(ValueFromPipelineByPropertyName)]
        [System.Object] $InputPdfFile,

        # Output file name
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $OutputTiffFileName
    )

    process {
        $InputFileName = $InputPdfFile.FullName

        # Resolve PSDrive paths to real filesystem paths for external tools
        $resolvedInputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InputFileName)
        $resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputTiffFileName)

        # pdftoppm requires the output path WITHOUT extension, it adds it automatically
        $outputBaseName = $resolvedOutputPath -replace '\.tiff?$', ''

        # Get pdftoppm command
        $pdftoppm = Get-ToolCommand -Tool Poppler

        # pdftoppm options:
        # -tiff: output TIFF format
        # -gray: convert to grayscale
        # -r 300: 300 DPI resolution
        # -tiffcompression lzw: LZW compression for smaller files
        # -f 1 -l 1: only first page (for single page PDFs)
        & $pdftoppm -tiff -gray -r 300 -tiffcompression lzw $resolvedInputPath $outputBaseName

        # pdftoppm adds -1.tif suffix for single page, rename if needed
        $generatedFile = "$outputBaseName-1.tif"
        if (Test-Path $generatedFile) {
            Move-Item -Path $generatedFile -Destination $resolvedOutputPath -Force
        }

        $OutputTiffFile = Get-Item $OutputTiffFileName -ErrorAction SilentlyContinue

        if ($null -eq $OutputTiffFile) {
            throw "Не получилось сконвертировать pdf файл: " + $InputFileName
        }

        # Check if optimization is needed (same logic as original)
        if ($OutputTiffFile.Length -gt ($InputPdfFile.Length / 4)) {
            # original pdf has 300dpi
            Optimize-Tiff -InputTiffFile $OutputTiffFile -OutputTiffFileName $OutputTiffFileName
        }
    }
}

function Optimize-Tiff {
    Param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [System.Object] $InputTiffFile,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $OutputTiffFileName
    )

    # Resolve PSDrive paths to real filesystem paths for external tools
    $resolvedInputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InputTiffFile.FullName)
    $resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputTiffFileName)

    # Get vips command
    $vips = Get-ToolCommand -Tool Vips

    # Use vips resize with 0.5 scale factor (50% reduction)
    # --kernel lanczos3: high-quality resampling kernel
    # vips automatically detects input/output formats from file extensions
    & $vips resize $resolvedInputPath $resolvedOutputPath 0.5 --kernel lanczos3
}

function New-Thumbnail {
    param (
        [string]$InputFileName,
        [int]$Pixels
    )

    $ThumbnailFile = Get-ThumbnailFileName $InputFileName $Pixels

    # Resolve PSDrive paths to real filesystem paths for external tools
    $resolvedInputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InputFileName)
    $resolvedThumbnailPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ThumbnailFile)

    # Get vipsthumbnail command
    $vipsthumbnail = Get-ToolCommand -Tool VipsThumbnail

    # vipsthumbnail options:
    # --size=${Pixels}: resize to fit within NxN box, maintaining aspect ratio
    # -o output[Q=95]: output path with quality setting
    # vipsthumbnail automatically strips metadata
    & $vipsthumbnail $resolvedInputPath --size=$Pixels -o "${resolvedThumbnailPath}[Q=95]"

    if ($ThumbnailFile -match "^.*[\/\\](?<filename>.*?)$") {
        return $Matches.filename
    }

    return $ThumbnailFile
}

function Convert-WebPngOrRename {
    param (
        [string]$InputFileName
    )

    if (-not (Test-Path $InputFileName)) {
        throw "Исходный файл не найден $InputFileName"
    }

    $WebPngFile = $InputFileName.Replace('.tif', '.png')

    # Resolve PSDrive paths to real filesystem paths for external tools
    $resolvedInputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InputFileName)
    $resolvedWebPngPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WebPngFile)

    # Get vips command
    $vips = Get-ToolCommand -Tool Vips

    # Use vips copy for format conversion with quality settings
    # [Q=100]: PNG compression level 100 (highest quality, but PNG is lossless anyway)
    # Note: For PNG, Q parameter affects compression level, not quality (PNG is always lossless)
    & $vips copy $resolvedInputPath "${resolvedWebPngPath}[compression=9]"

    if ($WebPngFile -match "^.*[\/\\](?<filename>.*?)$") {
        return $Matches.filename
    }

    return $WebPngFile
}

# Helper function to get thumbnail filename (copied from original module logic)
function Get-ThumbnailFileName {
    param (
        [string]$InputFileName,
        [int]$Pixels
    )

    $directory = Split-Path -Path $InputFileName -Parent
    $filename = Split-Path -Path $InputFileName -Leaf
    $thumbnailDir = Join-Path $directory "thumbnails"

    if (-not (Test-Path $thumbnailDir)) {
        New-Item -Path $thumbnailDir -ItemType Directory -Force | Out-Null
    }

    $extension = [System.IO.Path]::GetExtension($filename)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filename)

    return Join-Path $thumbnailDir "${baseName}_${Pixels}${extension}"
}

Export-ModuleMember -Function Convert-PdfToTiff, Optimize-Tiff, New-Thumbnail, Convert-WebPngOrRename
