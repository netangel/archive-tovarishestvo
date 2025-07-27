$ThumbnailDir = "thumbnails"
$MetadataDir = "metadata"

function Get-DirectoryOrCreate([string] $BasePath, [string] $DirName)  {
    $TranslitName = ConvertTo-Translit $DirName

    if (-not (Test-Path (Join-Path $BasePath $TranslitName))) {
        New-Item -Path $BasePath -ItemType Directory -Name $TranslitName | Out-Null
    }

    return $TranslitName
}

function Get-IsWindowsPlatform {
    return $IsWindows
}

function Test-IsFullPath([string] $Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }
    
    if ($Path -match '^TestDrive:') {
        return $true
    } elseif (Get-IsWindowsPlatform) {
        # Support both regular drive paths and UNC network paths
        return (
            ($Path -match '^[A-Za-z]:\\') -or      # Regular drive path (C:\, D:\, etc.)
            ($Path -match '^\\\\[^\\]+\\[^\\]+')   # UNC path (\\server\share)
        )
    } else {
        return $Path.StartsWith('/')
    }
}

function Get-TagsFromName([string] $FileName)
{
    # Fast path for empty/null input
    if ([string]::IsNullOrWhiteSpace($FileName)) {
        return @()
    }
    
    # Precompiled regex patterns for better performance
    $numberPatternRegex = [regex]"(?<word>[\p{L}]+)(?<symbol>[№#])(?<number>\d+)"
    $camelCaseRegex1 = [regex]"(?<begin>.*?)(?<first>\w+?)(?<second>\p{Lu}\w*)"
    $camelCaseRegex2 = [regex]"(?<begin>.*?)(?<first>[^\d\s№#]+?)(?<second>[\d.,]+)"
    $leadingNumberRegex = [regex]"^(?<first>[\d.,]+)(?<second>\w+)$"
    $digitOnlyRegex = [regex]"^[\d\s.,]+$"
    $camelCaseCheckRegex = [regex]"[\p{L}]+[\p{Lu}\d]+"
    
    # Single preprocessing step
    $preprocessed = $numberPatternRegex.Replace($FileName, '${word}|NUMBERTAG|${symbol}${number}')
    
    # Split on delimiters but NOT on our special marker
    $splitResult = $preprocessed -split "[_\-()[\]{}]"
    
    # Use ArrayList for better performance than array concatenation
    $Tags = [System.Collections.ArrayList]::new()
    
    foreach ($tag in $splitResult) {
        $trimmed = $tag.Trim()
        
        # Skip empty or digit-only strings
        if ($trimmed -eq "" -or $digitOnlyRegex.IsMatch($trimmed)) {
            continue
        }
        
        # Handle special number patterns first
        if ($trimmed -match "^(.+)\|NUMBERTAG\|(.+)$") {
            # Handle numbered tags
            $word = $Matches[1]
            $numberPart = $Matches[2]
            $processedWord = ProcessWordSeparation -Word $word -CamelCaseRegex1 $camelCaseRegex1 -CamelCaseRegex2 $camelCaseRegex2 -CamelCaseCheckRegex $camelCaseCheckRegex
            $processed = "$processedWord $numberPart"
            
            # Apply final transformations
            $processed = $leadingNumberRegex.Replace($processed, '${first} ${second}')
            $processed = $processed -replace "\s+", " "
            $processed = $processed.Trim()
            
            if ($processed -ne "") {
                $Tags.Add($processed) | Out-Null
            }
        } else {
            # Handle regular tags - need to split on remaining # and № symbols
            $subTags = $trimmed -split "[#№]"
            
            foreach ($subTag in $subTags) {
                $subTrimmed = $subTag.Trim()
                if ($subTrimmed -ne "" -and !$digitOnlyRegex.IsMatch($subTrimmed)) {
                    $processed = ProcessWordSeparation -Word $subTrimmed -CamelCaseRegex1 $camelCaseRegex1 -CamelCaseRegex2 $camelCaseRegex2 -CamelCaseCheckRegex $camelCaseCheckRegex
                    
                    # Apply final transformations
                    $processed = $leadingNumberRegex.Replace($processed, '${first} ${second}')
                    $processed = $processed -replace "\s+", " "
                    $processed = $processed.Trim()
                    
                    if ($processed -ne "") {
                        $Tags.Add($processed) | Out-Null
                    }
                }
            }
        }
    }
    
    return $Tags.ToArray()
}

# Helper function to avoid code duplication
function ProcessWordSeparation {
    param(
        [string]$Word,
        [regex]$CamelCaseRegex1,
        [regex]$CamelCaseRegex2,
        [regex]$CamelCaseCheckRegex
    )
    
    $processed = $Word
    $previousValue = ""
    $iterationCount = 0
    $maxIterations = 10
    
    # Optimized loop with precompiled regex
    while ($CamelCaseCheckRegex.IsMatch($processed) -and $processed -ne $previousValue -and $iterationCount -lt $maxIterations) {
        $previousValue = $processed
        $processed = $CamelCaseRegex1.Replace($processed, '${begin}${first} ${second}')
        $processed = $CamelCaseRegex2.Replace($processed, '${begin}${first} ${second}')
        $iterationCount++
    }
    
    if ($iterationCount -eq $maxIterations) {
        Write-Warning "Get-TagsFromName: Maximum iterations reached for tag '$processed'. Processing may be incomplete."
    }
    
    return $processed
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
                                Get-ThumbnailFileName, Get-ThumbnailDir, Test-RequiredPathsAndReturn, Get-IsWindowsPlatform, Test-IsFullPath

Export-ModuleMember -Variable MetadataDir
