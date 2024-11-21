# Параметры командной строки
Param(
    # Папка с оригиналами
    [Parameter(Mandatory, HelpMessage = "Путь к папке с оригиналами чертежей")]
    [string] $SourcePath,

    # Папка с результатами конвертации
    [Parameter(Mandatory, HelpMessage = "Путь к папке с результатами конвертации")]
    [string] $ResultPath
)

Import-Module ./libs/ConvertText.psm1
Import-Module ./libs/PathHelper.psm1
Import-Module ./libs/ConvertImage.psm1
Import-Module ./libs/JsonHelper.psm1

# Проверим, если пути указанные в параметрах запуска существуют
# Если нет, то выходим с ошибкой
# В противном случае вернем полные пути
($FullSourcePath, $FullResultPath) = Test-RequiredPathsAndReturn $SourcePath $ResultPath

function Convert-ScanOrRename {
    param (
        [System.Object]$InputFile,
        [string]$OutputFileName,
        [string]$OldFileName
    )

    # Cкан уже обработан, просто переименуем файл
    if (($null -ne $OldFileName) -and (Test-Path $OldFileName)) {
        Copy-Item -Path $OldFileName -Destination $OutputFileName
        Remove-Item $OldFileName
        return 
    }

    if ( -not (Test-Path ($OutputFileName)) ) {
        switch ($_.Extension) {
            ".pdf" { Convert-PdfToTiff -InputPdfFile  $InputFile -OutputTiffFileName $OutputFileName }
            ".tif" { Optimize-Tiff     -InputTiffFile $InputFile -OutputTiffFileName $OutputFileName } 
            Default { <# do nothing #> }
        }
    }
}


function Get-Thumbnails([string]$FileName, [string]$OldFileName) {
    [PSCustomObject]@{
        400 = ( New-ThumbnailOrCopy $FileName 400 $OldFileName )
    }
}


# Обработка корневой папки, для каждой папки внутри прочитаем индекс
# или создадим новый, если папка обрабатывается впервые
Get-ChildItem $FullSourcePath -Name | 
    Get-DirectoryPathAndIndex -ResultPath $ResultPath |
    ForEach-Object {

    }


# Обработка подпапок
foreach ($SourceDirName in Get-ChildItem $FullSourcePath -Name) {
    # Полный путь к папке с результатами обработки
    # Создаем папку, если еще не существует
    $ResultDir = Get-DirectoryOrCreate $ResultPath $SourceDirName

    # Структура файлов и метаданные для чертежей в папке в виде JSON
    $ResultDirIndex = Read-DirectoryToJson $ResultDir

    # Сохраним оригинальное имя папки в метаданных
    if ($null -eq $ResultDirIndex.OriginalName) {
        $ResultDirIndex.OriginalName = $SourceDirName
    }

    $SourceDirFullPath = Get-FullPathString $SourcePath $SourceDirName
    $ResultDirFullPath = Get-FullPathString $ResultPath $ResultDir

    # Путь к папка с миниатюрами, на всякий случай
    # Создадим, если не существует
    $null = Get-DirectoryOrCreate $ResultDirFullPath ( Get-ThumbnailDir ) 

    # Обработаем отсканированные исходники в текущей папке
    Get-ChildItem $SourceDirFullPath | ForEach-Object -Process {
        # Имя файла скана латиницей
        $TranslitFileName = (ConvertTo-Translit $_.BaseName) + '.tif'; 

        # Полный путь файла для результата обработки
        $OutputFileName = Get-FullPathString $ResultDirFullPath $TranslitFileName

        # Контрольная сумма скана
        # Испльзуем ее как ключ в списке файлов (индексе)
        $MD5sum = (Get-FileHash $_.FullName MD5).Hash

        # если файла нет в индексе, то обработаем его
        if ($null -eq $ResultDirIndex.Files.$MD5sum) {
       
            Convert-ScanOrRename $_ $OutputFileName

            # Проверим, если есть уже сконвертированные файлы
            $NewFileData = [PSCustomObject]@{
                ResultFileName = $TranslitFileName
                PngFile        = Convert-WebPngOrRename $OutputFileName
                OriginalName   = $_.Name
                Tags           = Get-TagsFromName $_.BaseName
                Year           = Get-YearFromFilename $_.BaseName
                Description    = $null
                Thumbnails     = Get-Thumbnails $OutputFileName
            }

            $ResultDirIndex.Files | Add-Member -MemberType NoteProperty -Name $MD5sum -Value $NewFileData
        }
        else {
            # Файл уже существует
            $ExistedFileData = $ResultDirIndex.Files.$MD5sum

            if ($ExistedFileData.OriginalName -cne $_.Name) {

                $OldFileName = Get-FullPathString $ResultDirFullPath $ExistedFileData.ResultFileName

                # Изменилось имя файла?
                # * Новое имя => транслитерация + скопировать старые обработанные файлы 
                # * Новые теги
                # * Обновить данные в структуре
                Convert-ScanOrRename $_ $OutputFileName $OldFileName 
                $WebPngFile = Convert-WebPngOrRename $OutputFileName (Get-FullPathString $ResultDirFullPath $ExistedFileData.PngFile)

                $UpdatedFileData = [PSCustomObject]@{
                    ResultFileName = $TranslitFileName
                    PngFile        = $WebPngFile
                    OriginalName   = $_.Name
                    Tags           = Get-TagsFromName $_.BaseName
                    Year           = Get-YearFromFilename $_.BaseName
                    Description    = $null
                    Thumbnails     = Get-Thumbnails $OutputFileName $OldFileName
                }

                $ResultDirIndex.Files | Add-Member -MemberType NoteProperty -Name $MD5sum -Value $UpdatedFileData -Force
            }
        }
    }

    $JsonIndexFile = Get-FullPathString (Get-FullPathString $ResultPath $ResultDir) ($ResultDir + ".json")
    $ResultDirIndex | ConvertTo-Json -depth 10 | Set-Content -Path $JsonIndexFile -Force
}
