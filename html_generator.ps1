$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$startTime = Get-Date
Write-Output "Html processing started at "$startTime

$settingsObject = Get-Content -Path .\settings.json | ConvertFrom-Json
$destinationSiteRootFolder = $settingsObject.rootSiteFolder
$archiveRootFolder = $destinationSiteRootFolder + "/" + $settingsObject.archiveSiteFolder
$tagsRootFolderName = 'Tags'
$thumbnailsFolderName = 'Thumbnails'
$itemsInRow = 3
$maxDrawNameLength = 60
$indexPageHtmlTemplate = Get-Content -Path .\index_page_template.html -Raw
$folderPageHtmlTemplate = Get-Content -Path .\folder_page_template.html -Raw
$tagPageHtmlTemplate = Get-Content -Path .\tag_page_template.html -Raw

function TruncateName
{
    param ($Value)

    if ($Value.Length -gt $maxDrawNameLength) {
        return $Value.subString(0, $maxDrawNameLength) + "Е"
    }

    return $Value
}

$indexPageHtmlFile = $destinationSiteRootFolder + "\index.html"
$indexPageFoldersPart = ""
$indexPageTagsPart = ""
$totalFilesCount = 0

# process all folders except 'Tags'

Write-Output "processing folder "$archiveRootFolder

Get-ChildItem -Path $archiveRootFolder/* -Directory -Recurse -Exclude Tags,Thumbnails |
Foreach-Object {
    Write-Output "processing folder "$_.Name
    $directoryInfoFile = $_.FullName + "\" + $_.Name + ".txt"
    $siteFolderHtmlFile = $archiveRootFolder + "\" + $_.Name + ".html"
    
    $folderPageContent = ""
    $lineNumber = 0
    $folderRussianName = $_.Name
    foreach ($line in Get-Content $directoryInfoFile) {
        if($lineNumber -eq 0) {
            $folderRussianName = $line
        }
        else {
            $splittedInfo = $line.Split("{|}")
            $truncatedName = TruncateName -Value $splittedInfo[1]
            $folderPageContent += [string]::Format(@"
		<div style="display: flex; max-width: 550px; align-items: flex-end;">
            <div style="text-align: center; width: 100%;">
			<a href="{2}\{0}.png"><img src="{2}\Thumbnails\{0}.png" alt="{1}"/><br/>{1}</a><br/>
            <a href="{2}\{0}.tif">—качать в формате tif</a>
            </div>
		</div>
"@, $splittedInfo[0], $truncatedName, $_.Name)
            $totalFilesCount++
        }

        $lineNumber++
    }

    $folderPage = [string]::Format($folderPageHtmlTemplate, $folderRussianName, $folderPageContent)
    Set-Content -Path $siteFolderHtmlFile -Value $folderPage -Force

    $indexPageFoldersPart += [string]::Format(@"
    <a href="{3}\{0}.html">{1}</a> ({2})<br/>
"@, $_.Name, $folderRussianName, ($lineNumber - 1), $settingsObject.archiveSiteFolder)
}


# process tags
Get-ChildItem -Path $archiveRootFolder/$tagsRootFolderName/*.txt | Sort Name |
Foreach-Object {
    $tagHtmlFile = $_.FullName.Replace(".txt", ".html")
    $lineNumber = 0
    $tagRussianName = $_.Name
    $tagPageContent = ""

    foreach ($line in Get-Content $_.FullName) {
        if($lineNumber -eq 0) {
            $tagRussianName = $line
        }
        else {
            $splittedInfo = $line.Split("{|}")
            $truncatedName = TruncateName -Value $splittedInfo[2]
            $tagPageContent += [string]::Format(@"
		<div style="display: flex; max-width: 550px; align-items: flex-end;">
            <div style="text-align: center; width: 100%;">
			<a href="..\{0}\{1}.png"><img src="..\{0}\Thumbnails\{1}.png" alt="{2}"/><br/>{2}</a><br/>
            <a href="..\{0}\{1}.tif">—качать в формате tif</a>
            </div>
		</div>
"@, $splittedInfo[0], $splittedInfo[1], $truncatedName)
        }

        $lineNumber++
    }

    $tagPage = [string]::Format($tagPageHtmlTemplate, $tagRussianName, $tagPageContent)
    Set-Content -Path $tagHtmlFile -Value $tagPage -Force

    $indexPageTagsPart += [string]::Format(@"
    <a href="{3}\Tags\{0}.html">{1}</a> ({2})<br/>
"@, $_.BaseName, $tagRussianName, ($lineNumber - 1), $settingsObject.archiveSiteFolder)
}

$indexPage = [string]::Format($indexPageHtmlTemplate, $totalFilesCount, $indexPageFoldersPart, $indexPageTagsPart)
Set-Content -Path $indexPageHtmlFile -Value $indexPage -Force

$endTime = Get-Date
Write-Output "Html processing finished at "$endTime