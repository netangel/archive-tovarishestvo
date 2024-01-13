# Параметры
Param(
    # Папка с оригиналами
    [Parameter(Mandatory, HelpMessage = "Путь к папке с оригиналами чертежей")]
    [string]
    $SourcePath,

    # Папка с результатами конвертации
    [Parameter(Mandatory, HelpMessage = "Путь к папке с результатами конвертации")]
    [string]
    $ResultPath
)

Import-Module ./tools/ConvertText.psm1
Import-Module ./tools/PathHelper.psm1
Import-Module ./tools/ConvertImage.psm1

function Read-DirectoryToJson([string] $DirName) {
    $JsonIndexFile = Get-FullPathString (Get-FullPathString $ResultPath $DirName) ($DirName + ".json")
    
    if ((Test-Path $JsonIndexFile) -and (Test-Json -Path $JsonIndexFile)) {
        return Get-Content -Path $JsonIndexFile | ConvertFrom-Json
    }
    
    [PSCustomObject]@{
        Directory    = $DirName
        OriginalName = $null
        Description  = $null
        Files        = [PSCustomObject]@{}
    }
}

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

# Проверим, если папки существуют
if (-Not (Test-Path $SourcePath)) {
    throw "Папка с оригиналами ($SourcePath) не найдена!"
}

if (-Not (Test-Path $ResultPath)) {
    throw "Папка для результатов ($ResultPath) не найдена!"
}

$SourcePath = Get-FullPathString $PSScriptRoot $SourcePath
$ResultPath = Get-FullPathString $PSScriptRoot $ResultPath

# Обработка под-папок
foreach ($SourceDirName in Get-ChildItem $SourcePath -Name) {
    # папка результатов обработки
    $ResultDir = Get-DirectoryOrCreate $ResultPath $SourceDirName

    # Индекс для папки
    $ResultDirIndex = Read-DirectoryToJson $ResultDir

    if ($null -eq $ResultDirIndex.original_name) {
        $ResultDirIndex.OriginalName = $SourceDirName
    }

    $SourceDirFullPath = Get-FullPathString $SourcePath $SourceDirName
    $ResultDirFullPath = Get-FullPathString $ResultPath $ResultDir

    # Папка для миниатюр, на всякий случай
    Get-DirectoryOrCreate $ResultDirFullPath ( Get-ThumbnailDir )

    # обработаем отсканированные исходники в текущей папке
    Get-ChildItem $SourceDirFullPath | ForEach-Object -Process {
        # Имя файла скана латиницей
        $TranslitFileName = (ConvertTo-Translit $_.BaseName) + '.tif'; 

        # полный путь файла для результата обработки
        $OutputFileName = Get-FullPathString $ResultDirFullPath $TranslitFileName

        # контрольная сумма скана
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
