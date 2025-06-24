# Параметры командной строки
Param(
    # Папка с оригиналами
    [Parameter(Mandatory, HelpMessage = "Путь к папке с оригиналами чертежей")]
    [string] $SourcePath,

    # Папка с результатами конвертации
    [Parameter(Mandatory, HelpMessage = "Путь к папке с результатами конвертации")]
    [string] $ResultPath
)

if ($env:PARENT_VERBOSE -eq "true") {
    $VerbosePreference = "Continue"
}

Import-Module (Join-Path $PSScriptRoot "libs/ConvertText.psm1")  -Force
Import-Module (Join-Path $PSScriptRoot "libs/PathHelper.psm1")   -Force
Import-Module (Join-Path $PSScriptRoot "libs/ConvertImage.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "libs/JsonHelper.psm1")   -Force
Import-Module (Join-Path $PSScriptRoot "libs/ToolsHelper.psm1")  -Force
Import-Module (Join-Path $PSScriptRoot "libs/ScanFileHelper.psm1")  -Force

# Проверим, если пути указанные в параметрах запуска существуют
# Если нет, то выходим с ошибкой
# В противном случае вернем полные пути
$FullSourcePath = Test-RequiredPathsAndReturn $SourcePath $PSScriptRoot -ErrorMessage "Папка с оригиналами {0} не найдена"
$FullResultPath = Test-RequiredPathsAndReturn $ResultPath $PSScriptRoot -ErrorMessage "Папка результатов {0} не найдена"

# Проверим, если папка с метаданными существует
$FullMetadataPath = Test-RequiredPathsAndReturn $MetadataDir $FullResultPath -ErrorMessage "Папка метаданных {0} не найдена"

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

        Write-Verbose "Обработка папки: $($CurrentDirIndex.OriginalName)"

        # Обработаем файлы сканов в текущей папке
        Get-ChildItem (Join-Path $FullSourcePath $CurrentDirIndex.OriginalName) -File |
            Where-Object { $_.Extension -match '\.(tiff?|pdf)$' } |
            ForEach-Object -Process {
                # Контрольная сумма скана
                # Испoльзуем ее как ключ в списке файлов (индексе)
                $MD5sum = (Get-FileHash $_.FullName MD5).Hash
                $MaybeFileData = $CurrentDirIndex.Files.$MD5sum

                Write-Verbose "Обработка оригинала чертежа: $($_.FullName)"
                
                # Обработаем файл и вернем метаданные
                $FileData = Convert-FileAndCreateData $_ $MaybeFileData $FullCurrentDirPath

                # Проверим, если скан был много-страничный, обновим метаданные соответственно
                $UpdatedFiledData = Repair-MultiPngReference -FileData $FileData -FullCurrentDirPath $FullCurrentDirPath

                # Добавим метаданные в индекс
                $CurrentDirIndex.Files | Add-Member -MemberType NoteProperty -Name $MD5sum -Value $UpdatedFiledData -Force
            }
        
        # Сохраним индекс в JSON файл в папке с результатами
        $JsonIndexFile = Join-Path $FullMetadataPath ($CurrentDirIndex.Directory + ".json")
        $CurrentDirIndex | ConvertTo-Json -depth 10 | Set-Content -Path $JsonIndexFile -Force
    }

exit 0
