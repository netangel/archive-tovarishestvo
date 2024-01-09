$GhostScriptTool= '..\..\tools\ghostscript\bin\gswin64c.exe'
$ImageMagickTool = '..\..\tools\imagemagic\magick.exe'

function Get-PDFConvereter {
    if (Test-Path $GhostScriptTool) {
        return $GhostScriptTool
    }
    elseif (Get-Command "gsc" -ErrorAction SilentlyContinue) {
        Write-Error "No tool gswin64.exe"
        return "gsc"
    }
    else {
        throw "Не могу найти конвертор PDF -> TIFF"
    }
}

function Get-ImageMagickTool {
    if (Test-Path $ImageMagickTool) {
        return $ImageMagickTool
    }
    elseif (Get-Command "magick" -ErrorAction SilentlyContinue) {
        Write-Error "No tools magic.exe" 
        return "magick"
    }
    else {
        throw "Не могу найти конвертор картинок"
    }

}

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
        $cmd = Get-PDFConvereter
        & $cmd -dNOPAUSE -sDEVICE=tiffgray ("-sOutputFile=" + $OutputTiffFileName) -q -r300 $InputFileName -c quit

        $OutputTiffFile = Get-Item $OutputTiffFileName -ErrorAction SilentlyContinue

        if ($null -eq $OutputTiffFile) {
            throw "Не получилось сконвертировать pdf файл: " + $InputFileName
        }

        
        if ($OutputTiffFile.Length -gt ($InputPdfFile.Length / 4)) {
            # original pdf has 300dpi
            Optimize-Tiff $OutputTiffFile, $OutputTiffFileName
        }

        # return Get-Item $OutputTiffFileName
    }
}

function Optimize-Tiff {
    Param (
        [Parameter(ValueFromPipelineByPropertyName)] 
        [System.Object] $InputTiffFile,
        
        [Parameter(ValueFromPipelineByPropertyName)] 
        [string] $OutputTiffFileName
    )

    $cmd = Get-ImageMagickTool 
    & $cmd convert $InputTiffFile.FullName -colorspace Gray -quality 100 -resize 50% $OutputTiffFileName
}

function New-ThumbnailOrCopy {
    param (
        [string]$InputFileName,
        [int]$Pixels,
        [string]$OldFileName
    )

    $ThumbnailFile = Get-ThumbnailFileName $InputFileName $Pixels

    $cmd = Get-ImageMagickTool
    & $cmd $InputFileName -resize "${Pixels}x${Pixels}" $ThumbnailFile
    
    if ($ThumbnailFile -match "^.*[\/\\](?<filename>.*?)$") {
        return $Matches.filename
    }

    return $ThumbnailFile
}

function  Convert-WebPngOrRename {
    param (
        [string]$InputFileName,
        [string]$OldFileName
    )

    if (($null -ne $OldFileName) -and (Test-Path $OldFileName)) {
        $WebPngFile = $InputFileName.Replace('.tif', '.png')
        Copy-Item -Path $OldFileName -Destination $WebPngFile
        Remove-Item $OldFileName

        return $WebPngFile
    }

    if (-not (Test-Path $InputFileName)) {
        throw "Исходный файл не найден"
    }

    $WebPngFile = $InputFileName.Replace('.tif', '.png')
   
    $cmd = Get-ImageMagickTool 
    & $cmd convert $InputFileName -quality 100 $WebPngFile
    
    if ($WebPngFile -match "^.*[\/\\](?<filename>.*?)$") {
        return $Matches.filename
    }

    return $WebPngFile
}

Export-ModuleMember -Function Convert-PdfToTiff, Optimize-Tiff, New-Thumbnail, Convert-WebPnOrRename
