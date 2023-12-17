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

Export-ModuleMember -Function Get-FullPathString