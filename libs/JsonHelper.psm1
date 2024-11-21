#
#   Возвращает JSON объект, содержащий описание структуры текущей папки
#   Если json для папки еще не создан (= папка обрабатывается впервые), 
#   возвращаем пустую структуру данных 
#
function Read-DirectoryToJson([string] $DirName, [string] $ResultPath, [string] $SourceDirName) {
    $JsonIndexFile = Join-Path (Join-Path $ResultPath $DirName) ($DirName + ".json")
    
    if ((Test-Path $JsonIndexFile) -and (Test-Json -Path $JsonIndexFile)) {
        return Get-Content -Path $JsonIndexFile | ConvertFrom-Json
    }
    
    [PSCustomObject]@{
        Directory    = $DirName
        OriginalName = $SourceDirName
        Description  = $null
        Files        = [PSCustomObject]@{}
    }
}

function Get-SubDirectoryIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias("Name")]
        [string]$SourceDirName,
        
        [Parameter(Mandatory)]
        [string]$ResultPath
    )
    
    process {
        try {
            # Create result directory
            $ResultDir = Get-DirectoryOrCreate $ResultPath $SourceDirName
           
            # Путь к папка с миниатюрами, на всякий случай
            # Создадим, если не существует
            $null = Get-DirectoryOrCreate (Join-Path $ResultPath $ResultDir) ( Get-ThumbnailDir )  
            
            # Get JSON index and return object
            Read-DirectoryToJson $ResultDir $ResultPath $SourceDirName
        }
        catch {
            Write-Error "Failed to process directory $SourceDirName`: $_"
            throw
        }
    }
}

Export-ModuleMember -Function Read-DirectoryToJson, Get-SubDirectoryIndex
