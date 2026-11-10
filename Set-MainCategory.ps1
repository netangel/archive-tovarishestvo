#Requires -Version 7.0
<#
.SYNOPSIS
    Заполняет основной раздел (MainCategory) чертежей в метаданных архива.

.DESCRIPTION
    Отдельный шаг, не входит в обработку сканов. Работает в два прохода.

    1. Отчёт (по умолчанию). Для каждого чертежа с пустым MainCategory правила из
       rules/main-categories.json предлагают раздел. Результат записывается в CSV (UTF-8 с BOM,
       открывается в Excel). Колонка Source: rule — предложено правилом, none — правило не нашлось.
       JSON не изменяется.

    2. Запись (-ApplyCsv). Значения из колонки Proposed проверенного CSV записываются в JSON.
       Уже заполненные разделы не меняются, если не указан -Force. Пустая Proposed оставляет
       раздел пустым. Неизвестное название раздела останавливает запись целиком.
       Во все записи, где поля нет, добавляется "MainCategory": null.

.EXAMPLE
    ./Set-MainCategory.ps1 -MetadataPath ../metadata -ReportPath ./main-category.csv

.EXAMPLE
    ./Set-MainCategory.ps1 -MetadataPath ../metadata -ApplyCsv ./main-category.csv
#>
[CmdletBinding(DefaultParameterSetName = 'Report')]
param (
    [Parameter(Mandatory)]
    [string]$MetadataPath,

    [string]$RulesPath = (Join-Path $PSScriptRoot 'rules/main-categories.json'),

    [Parameter(Mandatory, ParameterSetName = 'Report')]
    [string]$ReportPath,

    # Включить в отчёт и чертежи с уже заполненным разделом (Source = json)
    [Parameter(ParameterSetName = 'Report')]
    [switch]$IncludeAssigned,

    [Parameter(Mandatory, ParameterSetName = 'Apply')]
    [string]$ApplyCsv,

    [Parameter(ParameterSetName = 'Apply')]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'libs/MainCategoryHelper.psm1') -Force

if (-not (Test-Path $MetadataPath)) {
    throw "Папка метаданных не найдена: $MetadataPath"
}

$ruleSet = Read-MainCategoryRules -RulesPath $RulesPath

if ($PSCmdlet.ParameterSetName -eq 'Report') {
    $rows = @(Get-MainCategoryReport -MetadataPath $MetadataPath -RuleSet $ruleSet -IncludeAssigned:$IncludeAssigned)
    $rows | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding utf8BOM

    Write-Host "Отчёт: $ReportPath, строк: $($rows.Count)"
    $rows | Group-Object Proposed | Sort-Object Count -Descending | ForEach-Object {
        $name = if ($_.Name) { $_.Name } else { '(не определён)' }
        Write-Host ("{0,6}  {1}" -f $_.Count, $name)
    }
}
else {
    $rows = @(Import-Csv -Path $ApplyCsv -Encoding utf8)
    $stats = Set-MainCategoryFromRows -MetadataPath $MetadataPath -Rows $rows -Categories $ruleSet.Categories -Force:$Force
    Write-Host "Записано: $($stats.Set), перезаписано: $($stats.Overwritten), оставлено как было: $($stats.Kept), изменено файлов: $($stats.FilesChanged)"
}
