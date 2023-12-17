Import-Module ..\tools\ConvertText.psm1
Import-Module ..\tools\ConvertImage.psm1

$SettingsObject = Get-Content -Path ..\settings.json | ConvertFrom-Json

$inputDir = $SettingsObject.RootSiteFolder + "/input"
$OutputDir = $SettingsObject.RootSiteFolder + "/output"

function CreateOutputFileName {
    param (
        [string] $Dir,
        [System.Object] $File
    )
    return $Dir + "/" + (ConvertTo-Translit $File.BaseName) + ".tiff"
}

function Convert-DirectoryFiles {
    param (
        # Подпапка 
        [Parameter(ValueFromPipeline)] [System.Object] $SubDir
    )

    process {
        $TranslatedOutputDir = $OutputDir + "/" + (ConvertTo-Translit $SubDir.BaseName)

        if (-not (Test-Path -Path $TranslatedOutputDir)) {
            mkdir $TranslatedOutputDir
        }

        Get-ChildItem $SubDir | ForEach-Object -Process {
            $file = $_
            $OutputFileName = CreateOutputFileName -Dir $TranslatedOutputDir -File $file

            switch ($_.Extension) {
                ".pdf"  { Convert-PdfToTiff -InputPdfFile  $file -OutputTiffFileName $OutputFileName }
                ".tiff" { Optimize-Tiff     -InputTiffFile $file -OutputTiffFileName $OutputFileName } 
                Default { <# do nothing #> }
            }
        } 
    }
}

Get-ChildItem $inputDir | 
    Convert-DirectoryFiles


Remove-Module ConvertText
Remove-Module ConvertImage