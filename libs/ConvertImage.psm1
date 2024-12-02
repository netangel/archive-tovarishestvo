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
        $gs = Get-ToolCommand -Tool GhostScript
        & $gs -dNOPAUSE -sDEVICE=tiffgray ("-sOutputFile=" + $OutputTiffFileName) -q -r300 $InputFileName -c quit

        $OutputTiffFile = Get-Item $OutputTiffFileName -ErrorAction SilentlyContinue

        if ($null -eq $OutputTiffFile) {
            throw "Не получилось сконвертировать pdf файл: " + $InputFileName
        }

        
        if ($OutputTiffFile.Length -gt ($InputPdfFile.Length / 4)) {
            # original pdf has 300dpi
            Optimize-Tiff $OutputTiffFile, $OutputTiffFileName
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

    $magick = Get-ToolCommand -Tool ImageMagick
    & $magick $InputTiffFile.FullName -colorspace Gray -quality 100 -resize 50% $OutputTiffFileName
}

function New-Thumbnail {
    param (
        [string]$InputFileName,
        [int]$Pixels
    )

    $ThumbnailFile = Get-ThumbnailFileName $InputFileName $Pixels

    $magick = Get-ToolCommand -Tool ImageMagick
    & $magick $InputFileName -thumbnail "${Pixels}x${Pixels}" -strip -quality 95 $ThumbnailFile
    
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
   
    $magick = Get-ToolCommand -Tool ImageMagick 
    & $magick $InputFileName -quality 100 $WebPngFile
    
    if ($WebPngFile -match "^.*[\/\\](?<filename>.*?)$") {
        return $Matches.filename
    }

    return $WebPngFile
}

Export-ModuleMember -Function Convert-PdfToTiff, Optimize-Tiff, New-Thumbnail, Convert-WebPngOrRename
