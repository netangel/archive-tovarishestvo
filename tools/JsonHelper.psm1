#
#   Возвращает JSON объект, содержащий описание структуры текущей папки
#   Если json для папки еще не создан (= папка обрабатывается впервые), 
#   возвращаем пустую структуру данных 
#
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

Export-ModuleMember -Function Read-DirectoryToJson
