#
#   Основной раздел чертежа (MainCategory)
#
#   Раздел не определяется при обработке сканов: там поле остаётся пустым.
#   Его заполняет отдельный шаг (Set-MainCategory.ps1):
#     1. правила из rules/main-categories.json предлагают раздел по названию папки, имени файла и тегам;
#     2. предложения выгружаются в CSV и проверяются человеком;
#     3. проверенный CSV записывается в JSON метаданных.
#

# Читает список разделов и правила, проверяет, что каждое правило ссылается на известный раздел
function Read-MainCategoryRules {
    param (
        [Parameter(Mandatory)]
        [string]$RulesPath
    )

    $config = Get-Content -Path $RulesPath -Raw -Encoding utf8 | ConvertFrom-Json
    $names = @($config.Categories | ForEach-Object { $_.Name })

    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
               [System.Text.RegularExpressions.RegexOptions]::CultureInvariant

    $rules = @()
    $index = 0
    foreach ($rule in $config.Rules) {
        $index++
        if ($names -notcontains $rule.Category) {
            throw "Правило $index ссылается на неизвестный раздел: '$($rule.Category)'"
        }
        $rules += [PSCustomObject]@{
            Index    = $index
            Category = $rule.Category
            Pattern  = $rule.Pattern
            Regex    = [regex]::new($rule.Pattern, $options)
        }
    }

    return [PSCustomObject]@{
        Categories = $names
        Rules      = $rules
    }
}

# Текст, по которому ищется раздел: название папки, имя файла без расширения и теги
function Get-MainCategoryText {
    param (
        [string]$FolderName,
        [PSCustomObject]$FileData
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension([string]$FileData.OriginalName)
    $tags = @($FileData.Tags) -join ' | '
    return "$FolderName | $baseName | $tags"
}

# Первое сработавшее правило определяет раздел. Возвращает $null, если ни одно не сработало
function Get-MainCategoryProposal {
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$RuleSet,
        [string]$FolderName,
        [Parameter(Mandatory)]
        [PSCustomObject]$FileData
    )

    $text = Get-MainCategoryText -FolderName $FolderName -FileData $FileData
    foreach ($rule in $RuleSet.Rules) {
        $match = $rule.Regex.Match($text)
        if ($match.Success) {
            return [PSCustomObject]@{
                Category = $rule.Category
                Rule     = "$($rule.Index): $($match.Value)"
            }
        }
    }
    return $null
}

# JSON-файлы папок архива; служебные файлы в scripts/ пропускаются, как в ConvertTo-ZolaContent.ps1
function Get-MetadataJsonFiles {
    param (
        [Parameter(Mandatory)]
        [string]$MetadataPath
    )

    Get-ChildItem -Path $MetadataPath -Filter "*.json" -Recurse -File |
        Where-Object { $_.FullName -notmatch '[\\/]scripts[\\/]' } |
        Sort-Object FullName
}

# Чтение JSON папки. Возвращает $null для файлов без поля Files
function Read-FolderMetadata {
    param (
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File
    )

    $raw = [System.IO.File]::ReadAllText($File.FullName)
    $data = $raw | ConvertFrom-Json
    if ($null -eq $data -or $null -eq $data.PSObject.Properties['Files']) {
        return $null
    }
    return [PSCustomObject]@{
        Raw  = $raw
        Data = $data
    }
}

# Запись JSON так же, как при обработке (ConvertTo-Json -Depth 10),
# с сохранением переводов строк исходного файла, чтобы в diff попадали только изменения
function Write-FolderMetadata {
    param (
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,
        [Parameter(Mandatory)]
        [PSCustomObject]$Data,
        [Parameter(Mandatory)]
        [string]$OriginalRaw
    )

    $json = $Data | ConvertTo-Json -Depth 10
    $newLine = if ($OriginalRaw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $json = ($json -replace "`r`n", "`n") -replace "`n", $newLine
    if ($OriginalRaw.EndsWith("`n")) { $json += $newLine }

    if ($json -cne $OriginalRaw) {
        [System.IO.File]::WriteAllText($File.FullName, $json, [System.Text.UTF8Encoding]::new($false))
        return $true
    }
    return $false
}

# Строки отчёта: по одной на чертёж с пустым разделом (или на все чертежи с -IncludeAssigned)
function Get-MainCategoryReport {
    param (
        [Parameter(Mandatory)]
        [string]$MetadataPath,
        [Parameter(Mandatory)]
        [PSCustomObject]$RuleSet,
        [switch]$IncludeAssigned
    )

    foreach ($file in Get-MetadataJsonFiles -MetadataPath $MetadataPath) {
        $folder = Read-FolderMetadata -File $file
        if ($null -eq $folder) { continue }

        foreach ($entry in $folder.Data.Files.PSObject.Properties) {
            $fileData = $entry.Value
            $current = if ($fileData.PSObject.Properties['MainCategory']) { $fileData.MainCategory } else { $null }
            $hasCurrent = -not [string]::IsNullOrWhiteSpace($current)
            if ($hasCurrent -and -not $IncludeAssigned) { continue }

            $proposal = Get-MainCategoryProposal -RuleSet $RuleSet -FolderName $folder.Data.OriginalName -FileData $fileData

            [PSCustomObject]@{
                Directory    = $folder.Data.Directory
                FileId       = $entry.Name
                Folder       = $folder.Data.OriginalName
                OriginalName = $fileData.OriginalName
                Tags         = @($fileData.Tags) -join ' | '
                Current      = $current
                Proposed     = if ($hasCurrent) { $current } elseif ($proposal) { $proposal.Category } else { '' }
                Source       = if ($hasCurrent) { 'json' } elseif ($proposal) { 'rule' } else { 'none' }
                Rule         = if ($proposal) { $proposal.Rule } else { '' }
            }
        }
    }
}

# Записывает Proposed из строк отчёта в JSON.
# Заполняет только пустые значения (с -Force перезаписывает), добавляет пустое поле туда, где его нет
function Set-MainCategoryFromRows {
    param (
        [Parameter(Mandatory)]
        [string]$MetadataPath,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Rows,
        [Parameter(Mandatory)]
        [string[]]$Categories,
        [switch]$Force
    )

    # Проверяем все строки до записи: неизвестный раздел останавливает весь запуск
    $byKey = @{}
    $invalid = @()
    foreach ($row in $Rows) {
        $value = ([string]$row.Proposed).Trim()
        if ($value -and $Categories -cnotcontains $value) {
            $invalid += "$($row.Directory)/$($row.FileId): '$value'"
        }
        $byKey["$($row.Directory)|$($row.FileId)"] = $value
    }
    if ($invalid.Count -gt 0) {
        throw "Неизвестные разделы в CSV:`n$($invalid -join "`n")"
    }

    $stats = [PSCustomObject]@{ Set = 0; Kept = 0; Overwritten = 0; FilesChanged = 0 }

    foreach ($file in Get-MetadataJsonFiles -MetadataPath $MetadataPath) {
        $folder = Read-FolderMetadata -File $file
        if ($null -eq $folder) { continue }

        foreach ($entry in $folder.Data.Files.PSObject.Properties) {
            $fileData = $entry.Value
            if ($null -eq $fileData.PSObject.Properties['MainCategory']) {
                $fileData | Add-Member -NotePropertyName 'MainCategory' -NotePropertyValue $null
            }

            $key = "$($folder.Data.Directory)|$($entry.Name)"
            if (-not $byKey.ContainsKey($key) -or -not $byKey[$key]) { continue }
            $value = $byKey[$key]

            if ([string]::IsNullOrWhiteSpace($fileData.MainCategory)) {
                $fileData.MainCategory = $value
                $stats.Set++
            }
            elseif ($fileData.MainCategory -cne $value -and $Force) {
                $fileData.MainCategory = $value
                $stats.Overwritten++
            }
            else {
                $stats.Kept++
            }
        }

        if (Write-FolderMetadata -File $file -Data $folder.Data -OriginalRaw $folder.Raw) {
            $stats.FilesChanged++
        }
    }

    return $stats
}

Export-ModuleMember -Function Read-MainCategoryRules, Get-MainCategoryProposal, Get-MainCategoryReport, Set-MainCategoryFromRows
