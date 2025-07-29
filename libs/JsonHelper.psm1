#
#   Возвращает JSON объект, содержащий описание структуры текущей папки
#   Если json для папки еще не создан (= папка обрабатывается впервые), 
#   возвращаем пустую структуру данных 
#
function Read-ResultDirectoryMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $DirName,
        
        [Parameter(Mandatory)]
        [string] $ResultPath,
        
        [string] $SourceDirName
    )
    
    process {
        $JsonIndexFile = Join-Path (Join-Path $ResultPath $MetadataDir) ($DirName + ".json")
		
		Write-Verbose "Имя файла с метаданными для папки: $JsonIndexFile"
        
        if ((Test-Path $JsonIndexFile) -and (Test-Json -Path $JsonIndexFile)) {
            return Get-Content -Path $JsonIndexFile | ConvertFrom-Json
        }
        elseif ($null -eq $SourceDirName -or $SourceDirName -eq "") {
            return $null
        }
        
        [PSCustomObject]@{
            Directory    = $DirName
            OriginalName = $SourceDirName
            Description  = $null
            Files        = [PSCustomObject]@{}
        }
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
            Read-ResultDirectoryMetadata $ResultDir $ResultPath $SourceDirName
        }
        catch {
            Write-Error "Failed to process directory $SourceDirName`: $_"
            throw
        }
    }
}

Export-ModuleMember -Function Read-ResultDirectoryMetadata, Get-SubDirectoryIndex
