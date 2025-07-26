# HashHelper.psm1 - MD5 hash generation utilities


function Convert-StringToMD5 {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$StringToHash
    )

    $stingAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stingAsStream)
    
    try {
        $writer.Write($StringToHash)
        $writer.Flush()
        $stingAsStream.Position = 0
        
        $hash = (Get-FileHash -Algorithm MD5 -InputStream $stingAsStream).Hash
        return $hash
    }
    finally {
        $writer.Dispose()
        $stingAsStream.Dispose()
    }
}

function Get-DirectoryFileHash {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DirectoryName,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$FileName
    )
    
    # Use pipe symbol | as separator since it's not allowed in Windows/Unix filenames
    # Format: |DirectoryName|FileName|
    $combinedString = "|$DirectoryName|$FileName|"
    return Convert-StringToMD5 -StringToHash $combinedString
}

Export-ModuleMember -Function Convert-StringToMD5, Get-DirectoryFileHash 