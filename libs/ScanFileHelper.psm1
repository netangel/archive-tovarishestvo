function Convert-FileAndCreateData {
    param (
        [System.IO.File]$SourceFile,
        [PSCustomObject]$MaybeFileData,
        [string]$ResultDirFullPath
    )
    # Проверим, надо ли обрабатывать файл
    # Если информация о файле уже есть 
    # и оригинальное имя файла совпадает с текущим именем файла, 
    # то файл уже обработан
    if ($null -ne $MaybeFileData -and $MaybeFileData.OriginalName -ceq $SourceFile.Name) {
        return $MaybeFileData
    }

    # Имя скана латиницей
    $TranslitFileName = (ConvertTo-Translit $SourceFile.BaseName) + '.tif'
    # Имя файла png для web
    $WebPngFile = $TranslitFileName.Replace('.tif', '.png')
    # Полный путь к файлу для результата обработки
    $OutputFileName = Join-Path $ResultDirFullPath $TranslitFileName
    # Полный путь старому обработанному файлу, если у нас есть метаданные 
    $OldFilePath = ($null -ne $MaybeFileData) ? (Join-Path $ResultDirFullPath $MaybeFileData.OriginalName) : $null

    # Если файл уже обработан, то просто переименуем его
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

    # Обработаем файл
    if ( -not (Test-Path ($OutputFileName)) ) {
        switch ($_.Extension) {
            ".pdf" { Convert-PdfToTiff -InputPdfFile  $InputFile -OutputTiffFileName $OutputFileName }
            ".tif" { Optimize-Tiff     -InputTiffFile $InputFile -OutputTiffFileName $OutputFileName } 
            Default { <# do nothing #> }
        }
    } 

    # Вернем метаданные 
    return [PSCustomObject]@{
        ResultFileName = $TranslitFileName
        OriginalName   = $SourceFile.Name
        PngFile        = ($null -ne $MaybeFileData) ? $WebPngFile : (Convert-WebPngOrRename $OutputFileName)
        Tags           = Get-TagsFromName $SourceFile.BaseName
        Year           = Get-YearFromFilename $SourceFile.BaseName
        Thumbnails     = Get-Thumbnails $TranslitFileName
    }

    
}
function Get-Thumbnails([string]$FileName) {
    [PSCustomObject]@{
        400 = ( New-ThumbnailOrCopy $FileName 400 )
    }
}


Export-ModuleMember -Function Convert-FileAndCreateData