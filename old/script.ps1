Install-Module .\tools\convert_to_latin.psm1

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$startTime = Get-Date
Write-Output "Processing started at "$startTime

$settingsObject = Get-Content -Path .\settings.json | ConvertFrom-Json

$inputFolderName = $args[0]
$outputFolderName = $settingsObject.tempOutputFolder

$destinationSiteRootFolder = $settingsObject.rootSiteFolder + "\" + $settingsObject.archiveSiteFolder
$tagsRootFolderName = 'Tags'

$tool= 'C:\\Program Files\\gs\\gs9.55.0\\bin\\gswin64c.exe'
$magick = '.\imagemagick\magick.exe'
$thumbnailsFolderName = 'Thumbnails'
$thumbnailDimension = 400
$itemsInRow = 3

$capitalLetters = @(
    [char]'À'
    [char]'Á'
    [char]'Â'
    [char]'Ã'
    [char]'Ä'
    [char]'Å'
    [char]'¨'
    [char]'Æ'
    [char]'Ç'
    [char]'È'
    [char]'É'
    [char]'Ê'
    [char]'Ë'
    [char]'Ì'
    [char]'Í'
    [char]'Î'
    [char]'Ï'
    [char]'Ð'
    [char]'Ñ'
    [char]'Ò'
    [char]'Ó'
    [char]'Ô'
    [char]'Õ'
    [char]'Ö'
    [char]'×'
    [char]'Ø'
    [char]'Ù'
    [char]'Ú'
    [char]'Û'
    [char]'Ü'
    [char]'Ý'
    [char]'Þ'
    [char]'ß'
)

$digits = @(
    [char]'0'
    [char]'1'
    [char]'2'
    [char]'3'
    [char]'4'
    [char]'5'
    [char]'6'
    [char]'7'
    [char]'8'
    [char]'9'
)


$folderName = Get-ItemPropertyValue -Path $inputFolderName -Name Name
$translitFolderName = ConvertToTranslit -Value $folderName
Write-Output "Folder name: "$folderName


New-Item -ItemType Directory -Force -Path $outputFolderName

# process all pdfs
Write-Output "processing pdfs"
Get-ChildItem $inputFolderName\* -Include *.pdf | 
Foreach-Object {
    $fullPath = $_.FullName
    $output = $outputFolderName + "\" + $_.BaseName + ".tif"
    $param = "-sOutputFile=$output"
    & $tool -q -dNOPAUSE -sDEVICE=tiffgray $param -r300 $fullPath -c quit

    $resultedFile = Get-Item $output
    if ($resultedFile.Length -gt ($_.Length / 4)) {
        # original pdf has 300dpi
        & $magick convert $output -quality 100 -resize 50% $output
    }
}

# process all tiffs
Write-Output "processing tiffs"
Get-ChildItem $inputFolderName\* -Include *.tif | 
Foreach-Object {
    $fullPath = $_.FullName
    $output = $outputFolderName + "\" + $_.BaseName + ".tif"
    & $magick convert $fullPath -colorspace Gray -quality 100 -resize 50% $output
}

# process all files in output folder
Write-Output "processing result"
$outputThumbnaleFolder = $outputFolderName + "\" + $thumbnailsFolderName
New-Item -ItemType Directory -Force -Path $outputThumbnaleFolder

$siteFolder = $destinationSiteRootFolder + "\" + $translitFolderName
New-Item -ItemType Directory -Force -Path $siteFolder

$siteFolderDescriptionFile = $siteFolder + "\" + $translitFolderName + ".txt"
New-Item -Path $siteFolderDescriptionFile -Force
Add-Content -Path $siteFolderDescriptionFile -Value $folderName

New-Item -ItemType Directory -Force -Path $outputThumbnaleFolder

$fileIndex = 0

Get-ChildItem $outputFolderName\*.tif | 
Foreach-Object {

    # 1. Grenerate file name in translit
    $translatedFileName = ConvertToTranslit -Value $_.BaseName
    $translatedThumbnailName = $translatedFileName + ".png"
    Write-Host $translatedFileName

    # 2. Generate thumbnail
    $imageIdentifyResult = & $magick identify $_.FullName
    $splittedResult = $imageIdentifyResult.Split("{ }")
    $tiffIndex = [array]::IndexOf($splittedResult, "TIFF")
    $imageSize = $splittedResult[$tiffIndex + 1].Split("{x}")
    $scale = 100

    if ([double]$imageSize[0] -gt [double]$imageSize[1]) #width > height
    {
        $scale = 100 * $thumbnailDimension / $imageSize[0]
    }
    else
    {
        $scale = 100 * $thumbnailDimension / $imageSize[1]
    }
    $scaleParameter = [string]$scale + '%'
    Write-Host $imageSize"; scale: " $scaleParameter";output: "$translatedThumbnailName
    $output = $outputThumbnaleFolder + "\" + $translatedThumbnailName
    & $magick convert $_.FullName -quality 100 -resize $scaleParameter $output

    # also generate png for web
    $output = $outputFolderName + "\" + $translatedFileName + ".png"
    & $magick convert $_.FullName -quality 100 $output


    # 3. Parse for tags
    $tags = New-Object System.Collections.ArrayList
    $splittedByUndescore = $_.BaseName.Split("{_}")
    foreach ($t in $splittedByUndescore)
    {
        $tag = ""
        $ignoreTag = $false
        foreach ($c in $t.ToCharArray())
        {
            if ($digits.Contains($c))
            {
                $ignoreTag = $true
                break
            }

            if ($tag.Length -gt 0 -and $capitalLetters.Contains($c) -and $tag[-1] -ne ' ')
            {
                $tag += " "
            }
            $tag += $c
        }

        if ($ignoreTag)
        {
            Write-Host "Ignore tag: "$t
            continue
        }

        $tags.Add($tag)
    }
    # add last entity as a year tag
    if (-not $tags.Contains($splittedByUndescore[$splittedByUndescore.Length - 1]))
    {
        $tags.Add($splittedByUndescore[$splittedByUndescore.Length - 1])
    }
    Write-Host "Parsed tags: " $tags

    # add info about file to the tags lists
    $fileInfoForTag = $folderName + "|" + $translatedFileName + "|" + $_.BaseName
    foreach ($tag in $tags)
    {
        $translitTag = ConvertToTranslit -Value $tag
        $tagFileName = $destinationSiteRootFolder + "\" + $tagsRootFolderName + "\" + $translitTag + ".txt"
        $tagAlreadyExist = Test-Path -Path $tagFileName
        if (-not $tagAlreadyExist)
        {
            New-Item -Path $tagFileName -Force
            Add-Content -Path $tagFileName -Value $tag
        }
        Add-Content -Path $tagFileName -Value $fileInfoForTag
    }

    $fileInfoForFolder = $translatedFileName + "|" + $_.BaseName
    Add-Content -Path $siteFolderDescriptionFile -Value $fileInfoForFolder

    # 4. Rename
    $translatedFileName += $_.Extension
    Rename-Item -Path $_.FullName -NewName $translatedFileName
}

Copy-Item -Path $outputFolderName\* -Destination $siteFolder -Recurse


Remove-Item -Path $outputFolderName -Force -Recurse
$endTime = Get-Date
Write-Output "Processing finished at "$endTime
