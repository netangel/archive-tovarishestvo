BeforeAll {
    Import-Module $PSScriptRoot/../libs/MainCategoryHelper.psm1 -Force

    $script:RulesPath = Join-Path $PSScriptRoot '../rules/main-categories.json'
    $script:RuleSet = Read-MainCategoryRules -RulesPath $script:RulesPath

    function New-TestMetadata {
        param ([string]$Path)

        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        $folder = [PSCustomObject]@{
            Directory    = "01-70"
            OriginalName = "01-70"
            Description  = $null
            Files        = [PSCustomObject]@{
                AAA = [PSCustomObject]@{
                    ResultFileName = "1371_ZveroboynayaShkhuna_LeernayaStoyka_1951.tif"
                    OriginalName   = "1371_ЗверобойнаяШхуна_ЛеернаяСтойка_1951.tif"
                    PngFile        = "1371_ZveroboynayaShkhuna_LeernayaStoyka_1951.png"
                    MultiPage      = $false
                    Tags           = @("Зверобойная Шхуна", "Леерная Стойка")
                    Year           = "1951"
                    Thumbnails     = [PSCustomObject]@{ "400" = "1371_ZveroboynayaShkhuna_LeernayaStoyka_1951.png" }
                }
                BBB = [PSCustomObject]@{
                    ResultFileName = "955.tif"
                    OriginalName   = "955.tif"
                    PngFile        = "955.png"
                    MultiPage      = $false
                    Tags           = "955"
                    Year           = $null
                    Thumbnails     = [PSCustomObject]@{}
                    MainCategory   = "Дори"
                }
            }
        }
        $json = $folder | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText((Join-Path (Resolve-Path $Path).ProviderPath "01-70.json"), "$json`n")

        # Служебные JSON в scripts/ не трогаются
        New-Item -ItemType Directory -Path (Join-Path $Path "scripts") -Force | Out-Null
        Set-Content -Path (Join-Path $Path "scripts/settings.json") -Value '{"a": 1}'
    }

    function Get-Proposal ([string]$Folder, [string]$Name, $Tags = @()) {
        $data = [PSCustomObject]@{ OriginalName = $Name; Tags = $Tags }
        $result = Get-MainCategoryProposal -RuleSet $script:RuleSet -FolderName $Folder -FileData $data
        if ($result) { $result.Category } else { $null }
    }
}

Describe "Read-MainCategoryRules" {
    It "Loads 11 categories, and every rule names one of them" {
        $script:RuleSet.Categories.Count | Should -Be 11
        $script:RuleSet.Rules | ForEach-Object { $script:RuleSet.Categories | Should -Contain $_.Category }
    }

    It "Fails on a rule with an unknown category" {
        $path = "TestDrive:/bad-rules.json"
        Set-Content -Path $path -Encoding utf8 -Value '{"Categories":[{"Name":"Шхуны"}],"Rules":[{"Category":"Корабли","Pattern":"x"}]}'
        { Read-MainCategoryRules -RulesPath $path } | Should -Throw "*Корабли*"
    }
}

Describe "Get-MainCategoryProposal" {
    It "Puts '<Name>' into '<Expected>'" -ForEach @(
        @{ Folder = "1351-1425"; Name = "1371_ЗверобойнаяШхуна_ЛеернаяСтойка_1951.tif"; Expected = "Шхуны" }
        @{ Folder = "2476-2550"; Name = "2534_ЗверобойнаяШхуна_КойкаСРундукомВКаютуКапитана_1954.tif"; Expected = "Шхуны" }
        @{ Folder = "ЗАПАД"; Name = "018817_ШхунаЗапад_КонмандныйМостик_1955.tif"; Expected = "Шхуны" }
        @{ Folder = "321-390"; Name = "330_БотДляМурмана_ОковкаГика_1943.tif"; Expected = "Боты и мотоботы" }
        @{ Folder = "Моторно-Парусный Бот"; Name = "12305_Подшипник_Диам50_Детали.tif"; Expected = "Боты и мотоботы" }
        @{ Folder = "121-200"; Name = "164_ПарусноМоторнаяЁла_ОковкаГика_1943.pdf"; Expected = "Ёлы" }
        @{ Folder = "751-825"; Name = "778_Дори_8метров_ГребнойВинтЛитой_1948.tif"; Expected = "Дори" }
        @{ Folder = "1051-1125"; Name = "1111_МРТ_Компас_ФундаментнаяПодушка_1950.pdf"; Expected = "Траулеры и катера" }
        @{ Folder = "Изотермический Плашкоут 1-75"; Name = "003_п_ИзотермическийПлашкоут_45т_Форштевень_1955.tif"; Expected = "Несамоходные суда" }
        @{ Folder = "ШР 151-200"; Name = "ШР_190_ШлюпкаРабочая_Планка2_1973.tif"; Expected = "Шлюпки и гребные лодки" }
        @{ Folder = "97 Деревянная Судовая Мебель"; Name = "05-52-08_УшкоДляПодвешиванияВерхнее_1939.tif"; Expected = "Судовая мебель" }
        @{ Folder = "3226-3300"; Name = "3242_СтапельныйЦех_ВертикальноеАрмированиеСтолбов_1961.tif"; Expected = "Верфь: цеха и здания" }
        @{ Folder = "551-620"; Name = "586_ШлюпочныйСарай_ЭскизВорот_1946.tif"; Expected = "Верфь: цеха и здания" }
        @{ Folder = "3151-3225"; Name = "3167_ТележкаПоточнойЛинииДори_ПолурамаВСборе_1960.tif"; Expected = "Верфь: оборудование и оснастка" }
        @{ Folder = "3226-3300"; Name = "3281_ШтампСтойкиНосовойУтки_Пуансон_1961.tif"; Expected = "Верфь: оборудование и оснастка" }
        @{ Folder = "1501-1575"; Name = "1550_КамбузнаяПлита_Конфорка_Диам100_1951.tif"; Expected = "Судовое оборудование" }
        @{ Folder = "551-620"; Name = "583_ЯкорьХолля_150кг_ОбщийВид_Детали_1944.tif"; Expected = "Судовое оборудование" }
    ) {
        Get-Proposal $Folder $Name | Should -Be $Expected
    }

    It "Does not read a boat into '<Name>'" -ForEach @(
        @{ Name = "051_КолодкаДляКомпаса.pdf"; NotExpected = "Шлюпки и гребные лодки" }
        @{ Name = "1137_СоединениеПроходное_Ду15_1950.pdf"; NotExpected = "Верфь: цеха и здания" }
        @{ Name = "3959_СветокопировальныйАппаратСКА1_1964.tif"; NotExpected = "Судовое оборудование" }
    ) {
        Get-Proposal "01-70" $Name | Should -Not -Be $NotExpected
    }

    It "Uses tags as well as the name" {
        Get-Proposal "01-70" "001.tif" @("Дори") | Should -Be "Дори"
    }

    It "Returns nothing when no rule matches" {
        Get-Proposal "01-70" "955.tif" | Should -BeNullOrEmpty
    }
}

Describe "Get-MainCategoryReport" {
    BeforeEach {
        $path = "TestDrive:/meta-report"
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        New-TestMetadata -Path $path
    }

    It "Lists only drawings with an empty category" {
        $rows = @(Get-MainCategoryReport -MetadataPath $path -RuleSet $script:RuleSet)
        $rows.Count | Should -Be 1
        $rows[0].FileId | Should -Be "AAA"
        $rows[0].Proposed | Should -Be "Шхуны"
        $rows[0].Source | Should -Be "rule"
    }

    It "Lists assigned drawings with -IncludeAssigned, keeping their value" {
        $rows = @(Get-MainCategoryReport -MetadataPath $path -RuleSet $script:RuleSet -IncludeAssigned)
        $rows.Count | Should -Be 2
        ($rows | Where-Object FileId -eq "BBB").Proposed | Should -Be "Дори"
        ($rows | Where-Object FileId -eq "BBB").Source | Should -Be "json"
    }
}

Describe "Set-MainCategoryFromRows" {
    BeforeEach {
        $path = "TestDrive:/meta-apply"
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        New-TestMetadata -Path $path
        $jsonPath = Join-Path $path "01-70.json"
        $before = [System.IO.File]::ReadAllText((Resolve-Path $jsonPath).ProviderPath)
    }

    It "Fills empty values and keeps assigned ones" {
        $rows = @(
            [PSCustomObject]@{ Directory = "01-70"; FileId = "AAA"; Proposed = "Шхуны" }
            [PSCustomObject]@{ Directory = "01-70"; FileId = "BBB"; Proposed = "Шхуны" }
        )
        $stats = Set-MainCategoryFromRows -MetadataPath $path -Rows $rows -Categories $script:RuleSet.Categories

        $data = Get-Content $jsonPath -Raw | ConvertFrom-Json
        $data.Files.AAA.MainCategory | Should -Be "Шхуны"
        $data.Files.BBB.MainCategory | Should -Be "Дори"
        $stats.Set | Should -Be 1
        $stats.Kept | Should -Be 1
    }

    It "Overwrites assigned values with -Force" {
        $rows = @([PSCustomObject]@{ Directory = "01-70"; FileId = "BBB"; Proposed = "Шхуны" })
        $stats = Set-MainCategoryFromRows -MetadataPath $path -Rows $rows -Categories $script:RuleSet.Categories -Force

        (Get-Content $jsonPath -Raw | ConvertFrom-Json).Files.BBB.MainCategory | Should -Be "Шхуны"
        $stats.Overwritten | Should -Be 1
    }

    It "Rejects an unknown category and writes nothing" {
        $rows = @([PSCustomObject]@{ Directory = "01-70"; FileId = "AAA"; Proposed = "Корабли" })
        { Set-MainCategoryFromRows -MetadataPath $path -Rows $rows -Categories $script:RuleSet.Categories } | Should -Throw "*Корабли*"
        [System.IO.File]::ReadAllText((Resolve-Path $jsonPath).ProviderPath) | Should -BeExactly $before
    }

    It "Adds an empty field where it is missing and changes nothing else" {
        $rows = @([PSCustomObject]@{ Directory = "01-70"; FileId = "AAA"; Proposed = "" })
        Set-MainCategoryFromRows -MetadataPath $path -Rows $rows -Categories $script:RuleSet.Categories | Out-Null

        $after = [System.IO.File]::ReadAllText((Resolve-Path $jsonPath).ProviderPath)
        $data = $after | ConvertFrom-Json
        $data.Files.AAA.PSObject.Properties.Name | Should -Contain "MainCategory"
        $data.Files.AAA.MainCategory | Should -BeNullOrEmpty

        # Without the new field the file is the same as before
        $data.Files.AAA.PSObject.Properties.Remove("MainCategory")
        "$($data | ConvertTo-Json -Depth 10)`n" | Should -BeExactly $before
        $after | Should -Match "\n$"
    }

    It "Does not touch JSON files under scripts/" {
        Set-MainCategoryFromRows -MetadataPath $path -Rows @() -Categories $script:RuleSet.Categories | Out-Null
        (Get-Content (Join-Path $path "scripts/settings.json") -Raw).Trim() | Should -Be '{"a": 1}'
    }
}
