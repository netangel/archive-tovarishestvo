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
        directory       = $DirName
        original_name   = $null
        description     = $null
        files           = @{}
    }
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
        $ResultDirIndex.original_name = $SourceDirName
    }

    # обработаем отсканированные исходники в текущей папке
    $SourceDirFullPath = Get-FullPathString $SourcePath $SourceDirName
    $ResultDirFullPath = Get-FullPathString $ResultPath $ResultDir
    Get-ChildItem $SourceDirFullPath | ForEach-Object -Process {
        # полный путь к скану
        $SourceFileFullPath = Get-FullPathString $SourceDirFullPath $_.Name

        # полный путь
        $OutputFileName = Get-FullPathString $ResultDirFullPath ( ConvertTo-Translit $_.Name )

        # контрольная сумма скана
        $MD5sum = Get-FileHash $SourceFileFullPath

        # если файла нет в индексе, то обработаем его
        if ($null -eq $ResultDirIndex.files[$MD5sum.Hash]) {
            switch ($_.Extension) {
                ".pdf"  { Convert-PdfToTiff -InputPdfFile  $_ -OutputTiffFileName $OutputFileName }
                ".tiff" { Optimize-Tiff     -InputTiffFile $_ -OutputTiffFileName $OutputFileName } 
                Default { <# do nothing #> }
            }
        }

    }

    $JsonIndexFile = Get-FullPathString (Get-FullPathString $ResultPath $ResultDir) ($ResultDir + ".json")
    $ResultDirIndex | ConvertTo-Json -depth 1 | Set-Content -Path $JsonIndexFile
}

