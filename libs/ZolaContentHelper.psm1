# Правила читаемых названий чертежей.
# Важно: сравнение регистра нужно почти везде, поэтому -cmatch и -creplace.
$script:YearPattern = '^(18|19|20)\d\d$'
$script:SeriesPattern = '^(ШР|КС|РЛ|ПОО)$'          # серия из букв: ШР_51_…
$script:SubNumberPattern = '^(\d{1,2}|\p{L})$'      # 1399_1_…, 001_п_…
# Слова с заглавной буквы, которые не переводим в нижний регистр: люди, марки, места
$script:ProperNamePattern = '^(Мурман|Эльз|Грей[гс]|Бонжан|Клингер|Катерпил|Васильев|Букау|Вольф|Тивон|Нейше|Архангельск|Матросов|Запад$|Моряна|Касатк|Викстрем|Супериор|Граймарин|Рустон|Коммунист)'
$script:CompoundPattern = '(\p{L}{3,}но)(\p{Lu})(\p{Ll}+(?:ый|ий|ая|яя|ое|ее|ые|ие|ого|его|ой|ей|ом|ем|ых|их|ую|юю|ым|им|ным|ыми|ими))(?!\p{Ll})'

# Шифр листа содержит цифру и не содержит обычного слова: 001а, ВН05-92-1, КМ-42б-005
function Test-DrawingCode([string]$Part) {
    return ($Part -cmatch '\d') -and ($Part -cnotmatch '\p{Ll}{3}')
}

# Разбирает имя файла на номер листа и смысловые части, отбрасывая год в конце
function Split-DrawingName([string]$Name) {
    $clean = $Name.Trim()
    $clean = $clean -replace '(\.(tiff?|pdf|png))+$', ''
    $clean = $clean -replace '^\((дубль|оригинал)\)', ''
    $clean = $clean -replace '_\(оригинал\)', '_'
    $clean = $clean -replace '\s*\((\d+|без нумерации)\)$', ''
    $clean = $clean -replace '_((?:18|19|20)\d\d)\(лист\s*(\d+)\)$', '_Лист $2_$1'

    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($part in $clean.Split('_')) {
        $trimmed = $part.Trim()
        if ($trimmed) { $parts.Add($trimmed) }
    }

    $number = [System.Collections.Generic.List[string]]::new()
    if ($parts.Count -gt 1 -and ((Test-DrawingCode $parts[0]) -or $parts[0] -cmatch $script:SeriesPattern)) {
        # В ШР_100_… и 02_4976-6_… после первой части идёт второй шифр
        $hasSecondCode = $parts[0] -cmatch $script:SeriesPattern -or $parts[0] -cmatch '^\d{2}$'
        $number.Add($parts[0])
        $parts.RemoveAt(0)
        while ($number.Count -lt 3 -and $parts.Count -gt 1 -and
            ($parts[0] -cmatch $script:SubNumberPattern -or ($hasSecondCode -and (Test-DrawingCode $parts[0])))) {
            $number.Add($parts[0])
            $parts.RemoveAt(0)
        }
    }

    # В некоторых именах год повторяется: _1951_1951
    while ($parts.Count -gt 1 -and $parts[$parts.Count - 1] -cmatch $script:YearPattern) {
        $parts.RemoveAt($parts.Count - 1)
    }

    return [PSCustomObject]@{
        Number = $number -join '-'
        Parts  = $parts.ToArray()
    }
}

function Split-DrawingNameWords([string]$Part) {
    $result = $Part -creplace $script:CompoundPattern, {
        $_.Groups[1].Value + '-' + $_.Groups[2].Value.ToLowerInvariant() + $_.Groups[3].Value
    }
    $result = $result -creplace '(\p{Ll})(\p{Lu})', '$1 $2'               # БотДля -> Бот Для
    $result = $result -creplace '(\p{Lu})(\p{Lu}\p{Ll})', '$1 $2'         # ВГрузовую -> В Грузовую
    $result = $result -creplace '(\p{Ll}{2})(\d)', '$1 $2'                # Диам18 -> Диам 18, но М12 не трогаем
    $result = $result -creplace '(\d)(\p{Lu}\p{Ll}|\p{Ll}{2})', '$1 $2'   # 17Комнат -> 17 Комнат
    $result = $result -creplace '(\d)(м|т|л\.с\.)(?!\p{L})', '$1 $2'      # 8,8м -> 8,8 м
    $result = $result -creplace '(\p{L})№', '$1 №'
    return ($result -replace '\s+', ' ').Trim()
}

function ConvertTo-LowerCommonWord([string]$Word) {
    $bare = $Word -replace '[,.;:]$', ''
    $isPreposition = $bare -cmatch '^[ВИСКОУ]$'
    $isCommonWord = ($bare -cmatch '^\p{Lu}\p{Ll}+$') -and ($bare -cnotmatch $script:ProperNamePattern)
    if ($isPreposition -or $isCommonWord) { return $Word.ToLowerInvariant() }
    return $Word
}

function ConvertTo-CapitalizedText([string]$Text) {
    if (-not $Text) { return $Text }
    return $Text.Substring(0, 1).ToUpperInvariant() + $Text.Substring(1)
}

function ConvertTo-DrawingTitle {
    <#
    .SYNOPSIS
    Делает читаемое название чертежа из имени файла.
    001_БотДляМурмана_ОбщееРасположение_1945.tif -> Бот Для Мурмана – Общее расположение
    Первая часть называет судно или изделие и сохраняет заглавные буквы,
    остальные части пишутся как обычные предложения.
    #>
    param ([string]$Name)

    $formatted = [System.Collections.Generic.List[string]]::new()
    foreach ($part in (Split-DrawingName $Name).Parts) {
        $words = @((Split-DrawingNameWords $part).Split(' '))
        if ($formatted.Count -gt 0 -and $words.Count -gt 1) {
            $words = @($words[0]) + @($words[1..($words.Count - 1)] | ForEach-Object { ConvertTo-LowerCommonWord $_ })
        }
        $formatted.Add((ConvertTo-CapitalizedText ($words -join ' ')))
    }

    $title = $formatted -join ' – '
    if ($title) { return $title }
    return $Name
}

function Get-DrawingNumber {
    param ([string]$Name)
    return (Split-DrawingName $Name).Number
}

# Ключ сортировки: числа сравниваются как числа, поэтому 2_… идёт раньше 10_…
function Get-DrawingSortKey {
    param ([string]$Name)
    $base = $Name -replace '(\.(tiff?|pdf|png))+$', ''
    return $base -creplace '\d+', { $_.Value.PadLeft(10, '0') }
}

function New-RootIndexPage {
    param (
        [string]$OutputPath
    )

    $content = @"
+++
sort_by = "title"
template = "index.html"
+++
"@

    $content | Out-File -FilePath (Join-Path $OutputPath "_index.md") -Encoding utf8
}

function New-SectionPage {
    param (
        [string]$Directory,
        [string]$OriginalName,
        [string]$OutputPath
    )

    $sectionPath = Join-Path $OutputPath $Directory
    New-Item -ItemType Directory -Path $sectionPath -Force | Out-Null

    $content = @"
+++
title = "$OriginalName"
sort_by = "weight"
template = "section.html"
page_template = "page.html"
in_search_index = true

[extra]
directory_name = "$Directory"
+++
"@

    $content | Out-File -FilePath (Join-Path $sectionPath "_index.md") -Encoding utf8
}

function New-ContentPage {
    param (
        [string]$Directory,
        [string]$FileId,
        [PSCustomObject]$FileData,
        [string]$OutputPath,
        # Место листа в папке. Сортировать по названию нельзя: в нём больше нет номера
        [int]$Weight = 0
    )

    $pagePath = Join-Path $OutputPath $Directory
    New-Item -ItemType Directory -Path $pagePath -Force | Out-Null

    $title = ConvertTo-DrawingTitle $FileData.OriginalName
    $sheetNumber = Get-DrawingNumber $FileData.OriginalName
    $weightLine = if ($Weight -gt 0) { "weight = $Weight`n" } else { "" }
    $tags = $FileData.Tags
    $year = $FileData.Year
    $tifFile = $FileData.ResultFileName
    $pngFile = $FileData.PngFile
    $thumbnail = if ($FileData.Thumbnails.PSObject.Properties['400']) { $FileData.Thumbnails.'400' } else { $null }

    # Create front matter
    $frontMatter = @"
+++
title = "$title"
draft = false
file_id = "$FileId"
$weightLine
[extra]
directory_name = "$Directory"

"@

    if ($sheetNumber) {
        $frontMatter += @"
sheet_no = "$sheetNumber"

"@
    }

    if ($year) {
        $frontMatter += @"
scan_year = "$year"

"@
    }

    if ($tifFile) {
        $frontMatter += @"
tif_file = "$tifFile"

"@
    }
    
    if ($pngFile) {
        $frontMatter += @"
png_file = "$pngFile"

"@
    }

    if ($thumbnail) {
        $frontMatter += @"
thumbnail = "$thumbnail"

"@
    }

    if ($tags) {
        # Ensure $tags is always treated as an array for consistent JSON output
        $tagsArray = @($tags)
        if ($tagsArray.Count -gt 0) {
            # Force array output even for single elements by using -AsArray parameter
            $tagsJson = $tagsArray | ConvertTo-Json -Compress -AsArray
            $frontMatter += @"

[taxonomies]
tags = $tagsJson

"@
        }
    }

    $frontMatter += @"

+++
"@

    $frontMatter | Out-File -FilePath (Join-Path $pagePath "$FileId.md") -Encoding utf8
}

function Format-JsonFileIntoContent {
    param (
        [string]$JsonPath,
        [string]$OutputPath
    )

    $jsonContent = Get-Content $JsonPath -Raw -Encoding utf8 | ConvertFrom-Json
    $directory = $jsonContent.Directory
    $originalName = $jsonContent.OriginalName

    # Create section
    New-SectionPage -Directory $directory -OutputPath $OutputPath -OriginalName $originalName

    # Create pages for each file, numbered in sheet order
    $sortedFiles = [System.Collections.Generic.SortedDictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($file in $jsonContent.Files.PSObject.Properties) {
        $sortedFiles["$(Get-DrawingSortKey $file.Value.OriginalName)`0$($file.Name)"] = $file
    }

    $weight = 0
    foreach ($file in $sortedFiles.Values) {
        $weight++
        New-ContentPage -Directory $directory -FileId $file.Name -FileData $file.Value -OutputPath $OutputPath -Weight $weight
    }
}

Export-ModuleMember -Function New-RootIndexPage, New-SectionPage, New-ContentPage, Format-JsonFileIntoContent,
    ConvertTo-DrawingTitle, Get-DrawingNumber, Get-DrawingSortKey