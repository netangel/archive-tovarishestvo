$PSDefaultParameterValues['*:Encoding'] = 'utf8'

$startTime = Get-Date
Write-Output "Html processing started at "$startTime


$destinationSiteRootFolder = '\\pomor_schooner\drawings\public\archive'
$tagsRootFolderName = 'Tags'
$thumbnailsFolderName = 'Thumbnails'
$itemsInRow = 3
$maxDrawNameLength = 60

function TruncateName
{
    param ($Value)

    if ($Value.Length -gt $maxDrawNameLength) {
        return $Value.subString(0, $maxDrawNameLength) + "…"
    }

    return $Value
}

$mainPageHtmlFile = $destinationSiteRootFolder + "\main.html"

$mainPageHtemlHeader = @"
<!DOCTYPE html>
<html lang='ru'>
<head>
    <meta charset='utf-8'/>
    <title>Папка {0}</title>
</head>
<body>
<h1>Чертежи из архива Соломбальской судоверфи</h1>
<p>Проект "Цифровой архив Соломбальской судоверфи" реализуется Товариществом поморского судостроения совместно САФУ при поддержке Фонда президентских грантов.<br/>
Твердые копии материалов предоставлены для сканирования С.Н. Николаевым<br/>
Сканирование ведется при поддержки компании <a href='https://iq-tech.ru/'>IQTech</a>
</p>
<h2>По папкам</h2>
<div>
"@

Set-Content -Path $mainPageHtmlFile -Value $mainPageHtemlHeader -Force

# process all folders except 'Tags'
Get-ChildItem -Path $destinationSiteRootFolder\* -Directory -Recurse -Exclude Tags,Thumbnails
Get-ChildItem -Path $destinationSiteRootFolder\* -Directory -Recurse -Exclude Tags,Thumbnails |
Foreach-Object {
    Write-Output "processing folder "$_.Name
    $directoryInfoFile = $_.FullName + "\" + $_.Name + ".txt"
    $siteFolderHtmlFile = $_.FullName + "\" + $_.Name + ".html"
    
    $lineNumber = 0
    $folderRussianName = $_.Name
    foreach ($line in Get-Content $directoryInfoFile) {
        if($lineNumber -eq 0) {
            $folderRussianName = $line
            $outputHtmlHead = [string]::Format(
@"
            <!DOCTYPE html>
            <html lang='ru'>
            <head>
                <meta charset='utf-8'/>
                <title>Папка {0}</title>
            </head>
            <body>
            <h1>Чертежи из папки {0}</h1>
            <table>
            <tr>
"@, $folderRussianName)
            Set-Content -Path $siteFolderHtmlFile -Value $outputHtmlHead -Force
        }
        else {
            $splittedInfo = $line.Split("{|}")
            if (($lineNumber - 1) -gt 0 -and ($lineNumber - 1) % $itemsInRow -eq 0)
            {
                Add-Content -Path $siteFolderHtmlFile -Value @"
</tr>
<tr>
"@
            }
            $truncatedName = TruncateName -Value $splittedInfo[1]
            $itemTd = [string]::Format(@"
		<td>
			<a href="{0}.png"><img src="Thumbnails\{0}.png" alt="{1}"/><br/>{1}</a><br/>
            <a href="{0}.tif">Скачать в формате tif</a>
		</td>
"@, $splittedInfo[0], $truncatedName)
            Add-Content -Path $siteFolderHtmlFile -Value $itemTd
        }

        $lineNumber++
    }

    Add-Content -Path $siteFolderHtmlFile -Value @"
</tr>
</table>
<br/>
<h3>Благодарности</h3>
<p>Проект "Цифровой архив Соломбальской судоверфи" реализуется Товариществом поморского судостроения совместно САФУ при поддержке Фонда президентских грантов.<br/>
Твердые копии материалов предоставлены для сканирования С.Н. Николаевым<br/>
Сканирование ведется при поддержки компании <a href='https://iq-tech.ru/'>IQTech</a>
</p>
<h3>Лицензия</h3>
<a rel='license' href='http://creativecommons.org/licenses/by-nc-sa/4.0/'><img alt='Лицензия Creative Commons' style='border-width:0' src='https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png' /></a><br />Это произведение доступно по <a rel='license' href='http://creativecommons.org/licenses/by-nc-sa/4.0/'>лицензии Creative Commons «Attribution-NonCommercial-ShareAlike» («Атрибуция-Некоммерчески-СохранениеУсловий») 4.0 Всемирная</a>.
<p>Эта лицензия означает, что вы можете свободно использовать чертежи, представленные на этом сайте, перерабатывать их, исправлять и развивать и создавать производные произведения на некоммерческой основе, с условием упоминания оригинального авторства и лицензирования производных работ на аналогичных лицензионных условиях.</p>
</body>
"@

    $folderLinkTemplate = [string]::Format(@"
    <a href="{0}\{0}.html">{1}</a> ({2})<br/>
"@, $_.Name, $folderRussianName, ($lineNumber - 1))
    Add-Content -Path $mainPageHtmlFile $folderLinkTemplate
}


Add-Content -Path $mainPageHtmlFile -Value @"
</div>
<div>
<h2>По категориям</h2>
"@

# process tags
Get-ChildItem -Path $destinationSiteRootFolder\$tagsRootFolderName\*.txt |
Foreach-Object {
    $tagHtmlFile = $_.FullName.Replace(".txt", ".html")
    $lineNumber = 0
    $folderRussianName = $_.Name
    foreach ($line in Get-Content $_.FullName) {
        if($lineNumber -eq 0) {
            $tagRussianName = $line
            $outputHtmlHead = [string]::Format(
@"
            <!DOCTYPE html>
            <html lang='ru'>
            <head>
                <meta charset='utf-8'/>
                <title>Категория '{0}'</title>
            </head>
            <body>
            <h1>Чертежи в категории '{0}'</h1>
            <table>
            <tr>
"@, $tagRussianName)
            Set-Content -Path $tagHtmlFile -Value $outputHtmlHead -Force
        }
        else {
            $splittedInfo = $line.Split("{|}")
            if (($lineNumber - 1) -gt 0 -and ($lineNumber - 1) % $itemsInRow -eq 0)
            {
                Add-Content -Path $tagHtmlFile -Value @"
</tr>
<tr>
"@
            }
            $truncatedName = TruncateName -Value $splittedInfo[2]
            $itemTd = [string]::Format(@"
		<td>
			<a href="..\{0}\{1}.png"><img src="..\{0}\Thumbnails\{1}.png" alt="{2}"/><br/>{2}</a><br/>
            <a href="..\{0}\{1}.tif">Скачать в формате tif</a>
		</td>
"@, $splittedInfo[0], $splittedInfo[1], $truncatedName)
            Add-Content -Path $tagHtmlFile -Value $itemTd
        }

        $lineNumber++
    }

    Add-Content -Path $tagHtmlFile -Value @"
</tr>
</table>
<br/>
<h3>Благодарности</h3>
<p>Проект "Цифровой архив Соломбальской судоверфи" реализуется Товариществом поморского судостроения совместно САФУ при поддержке Фонда президентских грантов.<br/>
Твердые копии материалов предоставлены для сканирования С.Н. Николаевым<br/>
Сканирование ведется при поддержки компании <a href='https://iq-tech.ru/'>IQTech</a>
</p>
<h3>Лицензия</h3>
<a rel='license' href='http://creativecommons.org/licenses/by-nc-sa/4.0/'><img alt='Лицензия Creative Commons' style='border-width:0' src='https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png' /></a><br />Это произведение доступно по <a rel='license' href='http://creativecommons.org/licenses/by-nc-sa/4.0/'>лицензии Creative Commons «Attribution-NonCommercial-ShareAlike» («Атрибуция-Некоммерчески-СохранениеУсловий») 4.0 Всемирная</a>.
<p>Эта лицензия означает, что вы можете свободно использовать чертежи, представленные на этом сайте, перерабатывать их, исправлять и развивать и создавать производные произведения на некоммерческой основе, с условием упоминания оригинального авторства и лицензирования производных работ на аналогичных лицензионных условиях.</p>
</body>
"@

    $tagLinkTemplate = [string]::Format(@"
    <a href="Tags\{0}.html">{1}</a> ({2})<br/>
"@, $_.BaseName, $tagRussianName, ($lineNumber - 1))
    Add-Content -Path $mainPageHtmlFile $tagLinkTemplate
}

Add-Content -Path $mainPageHtmlFile -Value "<br/><h3>Лицензия</h3><a rel='license' href='http://creativecommons.org/licenses/by-nc-sa/4.0/'><img alt='Лицензия Creative Commons' style='border-width:0' src='https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png' /></a><br />Это произведение доступно по <a rel='license' href='http://creativecommons.org/licenses/by-nc-sa/4.0/'>лицензии Creative Commons «Attribution-NonCommercial-ShareAlike» («Атрибуция-Некоммерчески-СохранениеУсловий») 4.0 Всемирная</a>.<p>Эта лицензия означает, что вы можете свободно использовать чертежи, представленные на этом сайте, перерабатывать их, исправлять и развивать и создавать производные произведения на некоммерческой основе, с условием упоминания оригинального авторства и лицензирования производных работ на аналогичных лицензионных условиях.</p></div>"

$endTime = Get-Date
Write-Output "Html processing finished at "$endTime