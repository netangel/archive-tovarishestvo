$PathSeparator = $IsWindows ? "\" : "/"
$ThumbnailDir = "Thumbnails"

function Get-FullPathString([string] $FirstPart, [string] $SecondPart)
{
    if (-not ($FirstPart -match "\w$PathSeparator$")) {
        $FirstPart += $PathSeparator
    }

    $FirstPart + $SecondPart
}

function Get-DirectoryOrCreate([string] $DirName)  {
    $TranslitName = ConvertTo-Translit $DirName

    if (-not (Test-Path (Get-FullPathString $ResultPath $TranslitName))) {
        New-Item -Path $ResultPath -ItemType Directory -Name $TranslitName | Out-Null
    }

    return $TranslitName
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

function Get-ThumbnailFileName {
    param (
        [string]$SourceFileName,
        [int]$Pixels
    )
   
    if ($SourceFileName -match "^(?<path>.*)[\/\\](?<filename>.*?).tiff$") {
        return $Matches.path + $PathSeparator + $ThumbnailDir + $PathSeparator + $Matches.filename + '_' + $Pixels + '.png'
    }

    if ($SourceFileName -match "^(?<filename>.*?).tiff$") {
        return $ThumbnailDir + $PathSeparator + $Matches.filename + '_' + $Pixels + '.png'
    }

    return $null
}

Export-ModuleMember -Function Get-FullPathString, Get-DirectoryOrCreate, Get-TagsFromName, Get-YearFromFilename,
                                Get-ThumbnailFileName