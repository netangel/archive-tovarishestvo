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
        Directory       = $DirName
        OriginalName    = $null
        Description     = $null
        Files           = [PSCustomObject]@{}
    }
}

function Get-Thumbnails([string] $FileName)
{
    return @()
}

# Проверим, если папки существуют
if (-Not (Test-Path $SourcePath)) {
    throw "Папка с оригиналами ($SourcePath) не найдена!"
}

if (-Not (Test-Path $ResultPath)) {
    throw "Папка для результатов ($ResultPath) не найдена!"
}

# Обработка под-папок
foreach ($SourceDirName in Get-ChildItem $SourcePath -Name) {
    # папка результатов обработки
    $ResultDir = Get-DirectoryOrCreate $SourceDirName

    # Индекс для папки
    $ResultDirIndex = Read-DirectoryToJson $ResultDir

    if ($null -eq $ResultDirIndex.original_name) {
        $ResultDirIndex.OriginalName = $SourceDirName
    }

    $SourceDirFullPath = Get-FullPathString $SourcePath $SourceDirName
    $ResultDirFullPath = Get-FullPathString $ResultPath $ResultDir

    # обработаем отсканированные исходники в текущей папке
    Get-ChildItem $SourceDirFullPath | ForEach-Object -Process {
        # полный путь к скану
        $SourceFileFullPath = Get-FullPathString $SourceDirFullPath $_.Name
        
        $TranslitFileName = ConvertTo-Translit $_.BaseName; 

        # полный путь
        $OutputFileName = ( Get-FullPathString $ResultDirFullPath $TranslitFileName) + ".tiff"

        # контрольная сумма скана
        $MD5sum = (Get-FileHash $SourceFileFullPath MD5).Hash

        # если файла нет в индексе, то обработаем его
        if ($null -eq $ResultDirIndex.Files.$MD5sum) {
        
            # switch ($_.Extension) {
            #     ".pdf"  { Convert-PdfToTiff -InputPdfFile  $_ -OutputTiffFileName $OutputFileName }
            #     ".tiff" { Optimize-Tiff     -InputTiffFile $_ -OutputTiffFileName $OutputFileName } 
            #     Default { <# do nothing #> }
            # }

            $NewFileData = [PSCustomObject]@{
                ResultFileName  = $TranslitFileName + ".tiff"
                OriginalName    = $_.Name
                Tags            = Get-TagsFromName $_.BaseName
                Year            = Get-YearFromFilename $_.BaseName
                Description     = $null
                Thumbnails      = Get-Thumbnails $OutputFileName
            }

            $ResultDirIndex.Files | Add-Member -MemberType NoteProperty -Name $MD5sum -Value $NewFileData
        }
    }

    $JsonIndexFile = Get-FullPathString (Get-FullPathString $ResultPath $ResultDir) ($ResultDir + ".json")
    $ResultDirIndex | ConvertTo-Json -depth 10 | Set-Content -Path $JsonIndexFile
}
