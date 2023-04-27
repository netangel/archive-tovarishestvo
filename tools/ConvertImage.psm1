$GhostScriptTool= '..\..\tools\ghostscript\bin\gswin64c.exe'
$ImageMagicTool = '..\..\tools\imagemagic\magick.exe'

Write-Output $GhostScriptTool

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
        & $GhostScriptTool -dNOPAUSE -sDEVICE=tiffgray ("-sOutputFile=" + $OutputTiffFileName) -q -r300 $InputFileName -c quit

        $OutputTiffFile = Get-Item $OutputTiffFileName

        if ($null -eq $OutputTiffFile) {
            throw "Не получилось сконвертировать pdf файл: " + $InputFileName
        }

        
        if ($OutputTiffFile.Length -gt ($InputPdfFile.Length / 4)) {
            # original pdf has 300dpi
            Optimize-Tiff($OutputTiffFile, $OutputTiffFileName)
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

    & $ImageMagicTool convert $InputTiffFile.FullName -colorspace Gray -quality 100 -resize 50% $OutputTiffFileName
}

Export-ModuleMember -Function Convert-PdfToTiff
Export-ModuleMember -Function Optimize-Tiff 
