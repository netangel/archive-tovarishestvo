Import-Module (Join-Path $PSScriptRoot "ToolsHelper.psm1") -Force

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

        $gs = Get-ToolCommand -Tool GhostScript
        & $gs -dNOPAUSE -sDEVICE=tiffgray ("-sOutputFile=" + $resolvedOutputPath) -q -r300 $resolvedInputPath -c quit

        $OutputTiffFile = Get-Item $OutputTiffFileName -ErrorAction SilentlyContinue

        if ($null -eq $OutputTiffFile) {
            throw "Не получилось сконвертировать pdf файл: " + $InputFileName
        }


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

    $magick = Get-ToolCommand -Tool ImageMagick
    & $magick $resolvedInputPath -colorspace Gray -quality 100 -resize 50% $resolvedOutputPath
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

    $magick = Get-ToolCommand -Tool ImageMagick
    & $magick $resolvedInputPath -thumbnail "${Pixels}x${Pixels}" -strip -quality 95 $resolvedThumbnailPath

    if ($ThumbnailFile -match "^.*[\/\\](?<filename>.*?)$") {
        return $Matches.filename
    }

    return $ThumbnailFile
}

function  Convert-WebPngOrRename {
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

    $magick = Get-ToolCommand -Tool ImageMagick
    & $magick $resolvedInputPath -quality 100 $resolvedWebPngPath

    if ($WebPngFile -match "^.*[\/\\](?<filename>.*?)$") {
        return $Matches.filename
    }

    return $WebPngFile
}

Export-ModuleMember -Function Convert-PdfToTiff, Optimize-Tiff, New-Thumbnail, Convert-WebPngOrRename
