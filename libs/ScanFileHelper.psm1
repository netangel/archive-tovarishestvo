Import-Module (Join-Path $PSScriptRoot "ToolsHelper.psm1") -Force

function Convert-FileAndCreateData {
    param (
        [System.IO.FileInfo]$SourceFile,
        [PSCustomObject]$MaybeFileData,
        [string]$ResultDirFullPath
    )
    # Проверим, надо ли обрабатывать файл
    # Если информация о файле уже есть 
    # и оригинальное имя файла совпадает с текущим именем файла, 
    # то файл уже обработан
    if ($null -ne $MaybeFileData -and $MaybeFileData.OriginalName -ceq $SourceFile.Name) {
        Write-Verbose "Обработанный чертеж с таким именем уже есть в метаданных, пропускаем"
        return $MaybeFileData
    }

    # Имя скана латиницей
    $TranslitFileName = (ConvertTo-Translit $SourceFile.BaseName) + '.tif'
    # Имя файла png для web
    $WebPngFile = $TranslitFileName.Replace('.tif', '.png')
    # Полный путь к файлу для результата обработки
    $OutputFileName = Join-Path $ResultDirFullPath $TranslitFileName
    # Полный путь старому обработанному файлу, если у нас есть метаданные 
    $OldFilePath = ($null -ne $MaybeFileData) ? (Join-Path $ResultDirFullPath $MaybeFileData.ResultFileName) : $null

    # Ситуация: исходный файл переименован, но метаданные о нем существуют
    # и в папке результатов файлы под старым именем
    # Нам требуется преименовать главный файл чертежа в папке обработанных
    # переименуем также файл в формате png
    # и удалим старый файл, старый png и старые превью
    if ($null -ne $OldFilePath -and (Test-Path $OldFilePath )) {
        # Переименуем и удалим старый файл
        Copy-Item -Path $OldFilePath -Destination (Join-Path $ResultDirFullPath $TranslitFileName) 
        Remove-Item $OldFilePath

        # Переименуем и удалим старый png
        $OldPngPath = (Join-Path $ResultDirFullPath $MaybeFileData.PngFile)
        Copy-Item -Path $OldPngPath -Destination (Join-Path $ResultDirFullPath $WebPngFile)
        Remove-Item $OldPngPath

        # Удалим старые превью
        @( 400 ) | ForEach-Object -Process {
            $ThumbnailFile = Get-ThumbnailFileName $OldFilePath $_
            if (Test-Path $ThumbnailFile) {
                Remove-Item $ThumbnailFile
            }
        }
    }

    # Обработаем исходный файл чертежа
    if ( -not (Test-Path ($OutputFileName)) ) {
        switch ($SourceFile.Extension) {
            ".pdf" { Convert-PdfToTiff -InputPdfFile  $SourceFile -OutputTiffFileName $OutputFileName }
            ".tif" { Optimize-Tiff     -InputTiffFile $SourceFile -OutputTiffFileName $OutputFileName } 
            Default { Write-Warning "Неподдерживаемый формат файла: $($SourceFile.Extension)" }
        }
    }

    $pngFile = ($null -ne $MaybeFileData) ? $WebPngFile : (Convert-WebPngOrRename -InputFileName $OutputFileName)

    Write-Verbose "Результат обработки чертежа, файл tif: $($OutputFileName)"
    Write-Verbose "Результат обработки чертежа, файл png: $($pngFile)"

    # Вернем метаданные 
    return [PSCustomObject]@{
        ResultFileName = $TranslitFileName
        OriginalName   = $SourceFile.Name
        PngFile        = $pngFile
        MultiPage      = $false
        Tags           = Get-TagsFromName $SourceFile.BaseName
        Year           = Get-YearFromFilename $SourceFile.BaseName
        Thumbnails     = Get-Thumbnails $OutputFileName
    }

    
}
function Get-Thumbnails([string]$FileName) {
    [PSCustomObject]@{
        400 = ( New-Thumbnail -InputFileName $FileName -Pixels 400 )
    }
}

function Repair-MultiPngReference {
    param (
        [string]$FullCurrentDirPath,
        [PSCustomObject]$FileData 
    )

    $TifFilePath = Join-Path $FullCurrentDirPath $FileData.ResultFileName
    $PagesInTif = Get-TiffPageCount $TifFilePath
   
    # Если в стуктуре метаданных нет соотв. полей, добавим их
    if ($FileData.PSObject.Properties.Match('MultiPage').Count -eq 0) {
        $FileData | Add-Member -NotePropertyName "MultiPage" -NotePropertyValue $false
    }
    
    if ($FileData.PSObject.Properties.Match('PngFilePages').Count -eq 0) {
        $FileData | Add-Member -NotePropertyName "PngFilePages" -NotePropertyValue @() 
    }

    if ($PagesInTif -gt 1) {
        Write-Verbose "Многостраничный чертеж, обновляем метаданные"
        $ExistedFileName = [System.IO.Path]::GetFileNameWithoutExtension($FileData.ResultFileName)
        $FileData.MultiPage = $true
        $FileData.PngFile = "$($ExistedFileName)-0.png"

        $FileData.PngFilePages = (
            1..($PagesInTif-1) | ForEach-Object { "{0}-{1}.png" -f $ExistedFileName, $_ }
        )

        # Исправим ссылку на превью
        $ExistedPreviewName = [System.IO.Path]::GetFileNameWithoutExtension((Get-ThumbnailFileName -SourceFileName $FileData.ResultFileName -Pixels 400))
        $FileData.Thumbnails.400 = "$($ExistedPreviewName)-0.png"
    }

    return $FileData
}


function Get-TiffPageCount {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    try {
        # Get ImageMagick command
        $magick = Get-ToolCommand -Tool ImageMagick
        
        $TifFileData = & $magick identify -format "%n\n" $FilePath
        
        return [int]($TifFileData | Select-Object -First 1)
    }
    catch {
        Write-Error "Failed to get page count: $_"
        throw
    }
}

Export-ModuleMember -Function Convert-FileAndCreateData, Repair-MultiPngReference 