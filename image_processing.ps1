# Параметры командной строки
Param(
    # Папка с оригиналами
    [Parameter(Mandatory, HelpMessage = "Путь к папке с оригиналами чертежей")]
    [string] $SourcePath,

    # Папка с результатами конвертации
    [Parameter(Mandatory, HelpMessage = "Путь к папке с результатами конвертации")]
    [string] $ResultPath
)

Import-Module (Join-Path $PSScriptRoot "libs/ConvertText.psm1")
Import-Module (Join-Path $PSScriptRoot "libs/PathHelper.psm1")
Import-Module (Join-Path $PSScriptRoot "libs/ConvertImage.psm1")
Import-Module (Join-Path $PSScriptRoot "libs/JsonHelper.psm1")

# Проверим, если пути указанные в параметрах запуска существуют
# Если нет, то выходим с ошибкой
# В противном случае вернем полные пути
($FullSourcePath, $FullResultPath) = Test-RequiredPathsAndReturn $SourcePath $ResultPath $PSScriptRoot

# Обработка корневой папки, для каждой папки внутри прочитаем индекс
# или создадим новый, если папка обрабатывается впервые
Get-ChildItem $FullSourcePath -Name | 
    Get-DirectoryPathAndIndex -ResultPath $ResultPath |
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
        # Обработаем файлы сканов в текущей папке
        Get-ChildItem (Join-Path $FullSourcePath $CurrentDirIndex.OriginalName) -Name | 
            ForEach-Object -Process {
                # Контрольная сумма скана
                # Испoльзуем ее как ключ в списке файлов (индексе)
                $MD5sum = (Get-FileHash $_.FullName MD5).Hash
                $MaybeFileData = $CurrentDirIndex.Files.$MD5sum

                # Обработаем файл и вернем метаданные
                $FileData = Convert-FileAndCreateData $_ $MaybeFileData $ResultPath

                # Добавим метаданные в индекс
                $CurrentDirIndex.Files | Add-Member -MemberType NoteProperty -Name $MD5sum -Value $FileData
            }
        
        # Сохраним индекс в JSON файл в папке с результатами
        $JsonIndexFile = Join-Path (Join-Path $ResultPath $CurrentDirIndex.Directory) ($CurrentDirIndex.Directory + ".json")
        $CurrentDirIndex | ConvertTo-Json -depth 10 | Set-Content -Path $JsonIndexFile -Force
    }
