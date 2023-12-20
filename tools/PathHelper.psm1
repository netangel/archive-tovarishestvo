$PathSeparator = $IsWindows ? "\" : "/" 

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
        $Tags[$i] = $Tags[$i] -creplace "(?<first>[\w]+?)(?<second>\p{Lu}[\w]+)", '${first} ${second}'
        $Tags[$i] = $Tags[$i] -creplace "(?<first>[\w]+?)(?<second>[\d.,]+)", '${first} ${second}'
    }

    $Tags
}

function Get-YearFromFilename([string] $FileName)
{

}

Export-ModuleMember -Function Get-FullPathString, Get-DirectoryOrCreate, Get-TagsFromName