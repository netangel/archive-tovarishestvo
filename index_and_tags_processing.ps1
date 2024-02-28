
# Параметры
Param(
    # Папка с результатами конвертации
    [Parameter(Mandatory, HelpMessage = "Путь к папке с результатами конвертации")]
    [string]
    $ResultPath
)

if (-Not (Test-Path $ResultPath)) {
    throw "Папка для результатов ($ResultPath) не найдена!"
}

Import-Module ./tools/JsonHelper.psm1
Import-Module ./tools/PathHelper.psm1

$ResultPath = Get-FullPathString $PSScriptRoot $ResultPath

$ResultIndexJSON = [PSCustomObject]@{
    Directories = [System.Collections.ArrayList]@()
}

$ResultTagsJSON = [PSCustomObject]@{}

function Get-FileDataForTag([PSCustomObject]$FileData, [string]$Directory) {
    [PSCustomObject]@{
        OrigName  = $FileData.OriginalName
        Thumbnail = Get-FullPathString $Directory ( Get-FullPathString ( Get-ThumbnailDir ) $FileData.Thumbnails.400 )
        PngFile   = Get-FullPathString $Directory $FileData.PngFile
        TifFile   = Get-FullPathString $Directory $FileData.ResultFileName 
    }   
}

# Обработка под-папок
foreach ($ResultDirName in Get-ChildItem $ResultPath -Directory -Name) {
    $DirJSON = Read-DirectoryToJson $ResultDirName
    $FilesCount = $DirJSON.Files | Get-Member -MemberType NoteProperty | Measure-Object

    if ($FilesCount.Count -eq 0) {
        throw "Список файлов в папке пустой!"
    }

    $ResultIndexJSON.Directories.Add([PSCustomObject]@{
            OrigName   = $DirJSON.OriginalName 
            PathName   = $DirJSON.Directory
            FilesCount = $FilesCount.Count
        })
    
    $DirJSON.Files | Get-Member -MemberType NoteProperty | ForEach-Object {
        $FileId = $_.Name
        $FileData = $DirJSON.Files.$FileId

        $FileData.Tags | ForEach-Object {
            # Есть тега нет списке, добавим его как ключ
            if ($ResultTagsJSON.$_ -eq $null) {
                $ResultTagsJSON | Add-Member -MemberType NoteProperty -Name $_ -Value ( [System.Collections.ArrayList]@() )
            }
            $ResultTagsJSON.$_.Add( (Get-FileDataForTag $FileData $DirJSON.Directory) )
        }
    }
}

$JsonIndexFile = Get-FullPathString $ResultPath "index.json"
$ResultIndexJSON | ConvertTo-Json -depth 10 | Set-Content -Path $JsonIndexFile -Force
    
$JsonTagsFile = Get-FullPathString $ResultPath "tags.json"
$ResultTagsJSON | ConvertTo-Json -depth 10 | Set-Content -Path $JsonTagsFile -Force