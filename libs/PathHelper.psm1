$ThumbnailDir = "thumbnails"
$MetadataDir = "metadata"

function Get-DirectoryOrCreate([string] $BasePath, [string] $DirName)  {
    $TranslitName = ConvertTo-Translit $DirName

    if (-not (Test-Path (Join-Path $BasePath $TranslitName))) {
        New-Item -Path $BasePath -ItemType Directory -Name $TranslitName | Out-Null
    }

    return $TranslitName
}

function Test-IsFullPath([string] $Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }
    
    if ($Path -match '^TestDrive:') {
        return $true
    } elseif ($IsWindows) {
        return [System.IO.Path]::IsPathRooted($Path) -and $Path -match '^[A-Za-z]:\\'
    } else {
        return $Path.StartsWith('/')
    }
}

function Get-TagsFromName([string] $FileName)
{
    $Tags = ( $FileName -split "[_-]" ) -notmatch "^[\d\s.,]+$"

    for ($i = 0; $i -lt $Tags.Count; $i++) {
        while ($Tags[$i] -cmatch "[^\d\s.,]+?[\p{Lu}\d]+") {   
            $Tags[$i] = $Tags[$i] -creplace "(?<begin>.*?)(?<first>\w+?)(?<second>\p{Lu}\w*)", '${begin}${first} ${second}'
            $Tags[$i] = $Tags[$i] -creplace "(?<begin>.*?)(?<first>[^\d]+?)(?<second>[\d.,]+)", '${begin}${first} ${second}'
        }
        $Tags[$i] = $Tags[$i] -creplace "^(?<first>[\d.,]+)(?<second>\w+)$", '${first} ${second}'
    }

    $Tags
}

function Get-YearFromFilename([string] $FileName)
{
    if ($FileName -match ".*?(?<year>\d+?[-_]?\d+)$") {
        return $Matches.year.Replace('_', '-')
    }
    
    return $null
}

function Get-ThumbnailFileName 
{
    param (
        [string]$SourceFileName,
        [int]$Pixels
    )

    if (-not ($SourceFileName -match '\.(tif|png)$')) {
        return $null
    }

    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($SourceFileName)
    $ThumbnailName = "${BaseName}_${Pixels}.png"
    $Directory = Split-Path -Path $SourceFileName -Parent

    if ($Directory) {
        return Join-Path (Join-Path $Directory $ThumbnailDir) $ThumbnailName
    }

    return Join-Path $ThumbnailDir $ThumbnailName
}

function Get-ThumbnailDir () {
    return $ThumbnailDir
}

function Test-RequiredPathsAndReturn {
    param (
        [string]$SourcePath,
        [string]$ScriptRoot = $PSScriptRoot,
        [string]$ErrorMessage = "Папка {0} не найдена!"
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        throw "Путь к папке не указан"
    }
    
    $FullSourcePath = ( Test-IsFullPath $SourcePath ) ? $SourcePath : (Join-Path $ScriptRoot $SourcePath)

    if (-Not (Test-Path $FullSourcePath)) {
        throw $ErrorMessage -f $FullSourcePath 
    }
    
    return $FullSourcePath
}

Export-ModuleMember -Function Get-DirectoryOrCreate, Get-TagsFromName, Get-YearFromFilename,
                                Get-ThumbnailFileName, Get-ThumbnailDir, Test-RequiredPathsAndReturn

Export-ModuleMember -Variable MetadataDir
