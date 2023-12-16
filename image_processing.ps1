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

function Read-DirectoryToJson([string] $DirName) {
    $JsonIndexFile = Get-FullPathString (Get-FullPathString $ResultPath $DirName) ($DirName + ".json")
    
    if ((Test-Path $JsonIndexFile) -and (Test-Json -Path $JsonIndexFile)) {
        return Get-Content -Path $JsonIndexFile | ConvertFrom-Json
    }
    
    [PSCustomObject]@{
        directory       = $DirName
        original_name   = $null
        description     = $null
        files           = @()
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
foreach ($SourceDirName in Get-ChildItem $SourcePath | Select-Object -ExpandProperty "Name") {
    # папка результатов обработки
    $ResultDir = Get-DirectoryOrCreate $SourceDirName

    # Индекс для папки
    $ResultDirIndex = Read-DirectoryToJson $ResultDir

    if ($null -eq $ResultDirIndex.original_name) {
        $ResultDirIndex.original_name = $SourceDirName
    }

    $JsonIndexFile = Get-FullPathString (Get-FullPathString $ResultPath $ResultDir) ($ResultDir + ".json")
    $ResultDirIndex | ConvertTo-Json -depth 1 | Set-Content -Path $JsonIndexFile
}

