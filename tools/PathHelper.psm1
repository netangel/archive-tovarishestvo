$PathSeparator = $IsWindows ? "\" : "/" 

function Get-FullPathString([string] $FirstPart, [string] $SecondPart)
{
    if (-Not ($FirstPart -match "\w$PathSeparator$")) {
        $FirstPart += $PathSeparator
    }

    $FirstPart + $SecondPart
}

Export-ModuleMember -Function Get-FullPathString