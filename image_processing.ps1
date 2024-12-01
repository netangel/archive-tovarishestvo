# Параметры командной строки
Param(
    # Папка с оригиналами
    [Parameter(Mandatory, HelpMessage = "Путь к папке с оригиналами чертежей")]
    [string] $SourcePath,

    # Папка с результатами конвертации
    [Parameter(Mandatory, HelpMessage = "Путь к папке с результатами конвертации")]
    [string] $ResultPath
)

Import-Module (Join-Path $PSScriptRoot "libs/ConvertText.psm1")  -Force
Import-Module (Join-Path $PSScriptRoot "libs/PathHelper.psm1")   -Force
Import-Module (Join-Path $PSScriptRoot "libs/ConvertImage.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "libs/JsonHelper.psm1")   -Force

# Проверим, если пути указанные в параметрах запуска существуют
# Если нет, то выходим с ошибкой
# В противном случае вернем полные пути
($FullSourcePath, $FullResultPath) = Test-RequiredPathsAndReturn $SourcePath $ResultPath $PSScriptRoot

# Проверим, если папка с метаданными существует
if (-not (Test-Path (Join-Path $FullResultPath $MetadataDir)))
{
    New-Item -Path $ResultPath -ItemType Directory -Name $MetadataDir | Out-Null
}

# Обработка корневой папки, для каждой папки внутри прочитаем индекс
# или создадим новый, если папка обрабатывается впервые
Get-ChildItem $FullSourcePath -Name  | 
    Get-SubDirectoryIndex -ResultPath $FullResultPath |
    ForEach-Object -Process {
        <#
            $CurrentDirIndex - это объект, который содержит метаданные папки
            в виде JSON, например:
            {
                "Directory": <Имя папки в транслитерации>,
                "OriginalName": <Оригинальное имя папки>,
                "Description": <Описание папки (не используется)>,
                "Files": { 
                    "<hash-code>": {
                        "ResultFileName": <имя скана в транслитерации>.tif,
                        "PngFile": <то же, но в другом формате>.png,
                        "OriginalName": <оригинал скана чертежа>.pdf,
                        "Tags": [
                            "tag-1",
                            "tag-2"
                        ],
                        "Year": "2020",
                        "Description": <дополнительное описание чертежа (не используется)>,
                        "Thumbnails": {
                            "400": "thumbnail-400.png"
                        }
                    }
                }
        #>  
        $CurrentDirIndex = $_
        $FullCurrentDirPath = Join-Path $FullResultPath $CurrentDirIndex.Directory
        # Обработаем файлы сканов в текущей папке
        Get-ChildItem (Join-Path $FullSourcePath $CurrentDirIndex.OriginalName) -File | 
            ForEach-Object -Process {
                # Контрольная сумма скана
                # Испoльзуем ее как ключ в списке файлов (индексе)
                $MD5sum = (Get-FileHash $_.FullName MD5).Hash
                $MaybeFileData = $CurrentDirIndex.Files.$MD5sum

                # Обработаем файл и вернем метаданные
                $FileData = Convert-FileAndCreateData $_ $MaybeFileData $FullCurrentDirPath

                # Добавим метаданные в индекс
                $CurrentDirIndex.Files | Add-Member -MemberType NoteProperty -Name $MD5sum -Value $FileData -Force
            }
        
        # Сохраним индекс в JSON файл в папке с результатами
        $JsonIndexFile = Join-Path (Join-Path $FullResultPath $MetadataDir) ($CurrentDirIndex.Directory + ".json")
        $CurrentDirIndex | ConvertTo-Json -depth 10 | Set-Content -Path $JsonIndexFile -Force
    }
