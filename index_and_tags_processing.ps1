
# Параметры
Param(
    # Папка с результатами конвертации
    [Parameter(Mandatory, HelpMessage = "Путь к папке с результатами конвертации")]
    [string]
    $ResultPath
)

Import-Module (Join-Path $PSScriptRoot "libs/JsonHelper.psm1")
Import-Module (Join-Path $PSScriptRoot "libs/PathHelper.psm1")

# Дополним путь к папке с результатами, если он не абсолютный
if (-not [System.IO.Path]::IsPathRooted($ResultPath)) {
    $ResultPath = Join-Path $PSScriptRoot $ResultPath
}

# Проверим, если папка с результатами существует
if (-not (Test-Path $ResultPath)) {
    throw "Папка для результатов ($ResultPath) не найдена!"
}

$ResultIndexJSON = [PSCustomObject]@{
    Directories = [System.Collections.ArrayList]@()
}

$ResultTagsJSON = [PSCustomObject]@{}

function Get-FileDataForTag([PSCustomObject]$FileData, [string]$Directory) {
    [PSCustomObject]@{
        OrigName  = $FileData.OriginalName
        Thumbnail = Join-Path $Directory ( Join-Path ( Get-ThumbnailDir ) $FileData.Thumbnails.400 )
        PngFile   = Join-Path $Directory $FileData.PngFile
        TifFile   = Join-Path $Directory $FileData.ResultFileName 
    }   
}

# Обработка подпапок
Get-ChildItem $ResultPath -Name | 
    Read-DirectoryToJson -ResultPath $ResultPath |
    ForEach-Object -Process {
        $CurrentDirIndex = $_

        # Общее число сканов в папке
        $FilesCount = $CurrentDirIndex.Files 
            | Get-Member -MemberType NoteProperty 
            | Select-Object -ExpandProperty Count

        if ($FilesCount -eq 0) {
            Write-Error "Список файлов в папке пустой!"
        }

        $ResultIndexJSON.Directories.Add([PSCustomObject]@{
            OrigName   = $CurrentDirIndex.OriginalName 
            PathName   = $CurrentDirIndex.Directory
            FilesCount = $FilesCount
        })
       
        $CurrentDirIndex.Files | Get-Member -MemberType NoteProperty | 
        ForEach-Object -Process {
            $FileId = $_.Name
            $FileData = $CurrentDirIndex.Files.$FileId
    
            $FileData.Tags | ForEach-Object {
                # Есть тега нет списке, добавим его как ключ
                if ($ResultTagsJSON.$_ -eq $null) {
                    $ResultTagsJSON | Add-Member -MemberType NoteProperty -Name $_ -Value ( [System.Collections.ArrayList]@() )
                }
                $ResultTagsJSON.$_.Add( (Get-FileDataForTag $FileData $CurrentDirIndex.Directory) )
            }
        } 
    }

# Сохраним индексы в JSON файлы
$JsonIndexFile = Join-Path $ResultPath "index.json"
$ResultIndexJSON | ConvertTo-Json -depth 10 | Set-Content -Path $JsonIndexFile -Force
    
$JsonTagsFile = Join-Path $ResultPath "tags.json"
$ResultTagsJSON | ConvertTo-Json -depth 10 | Set-Content -Path $JsonTagsFile -Force