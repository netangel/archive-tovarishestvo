BeforeAll {
    # Import script
    Import-Module $PSScriptRoot/../libs/ZolaContentHelper.psm1 -Force
}

Describe "Convert-ToZola Tests" {
    BeforeEach {
        # Setup test paths
        $testMetadataPath = "TestDrive:\metadata"
        $testZolaPath = "TestDrive:\zola"

        New-Item -Path $testMetadataPath -ItemType Directory -Force
        New-Item -Path $testZolaPath -ItemType Directory -Force
    }

    Describe "New-RootIndexPage" {
        It "Creates root index file with correct content" {
            # Act
            New-RootIndexPage -OutputPath $testZolaPath

            # Assert
            $indexPath = Join-Path $testZolaPath "_index.md"
            Test-Path $indexPath | Should -BeTrue

            $content = Get-Content $indexPath -Raw
            $content | Should -Match "sort_by = `"title`""
            $content | Should -Match "template = `"index.html`""
        }
    }

    Describe "New-SectionPage" {
        It "Creates section directory and index with metadata" {
            # Arrange
            $directory = "test-section"
            $originalName = "Test Section"

            # Act
            New-SectionPage -Directory $directory -OriginalName $originalName -OutputPath $testZolaPath

            # Assert
            $sectionPath = Join-Path $testZolaPath $directory
            Test-Path $sectionPath | Should -BeTrue
            Test-Path (Join-Path $sectionPath "_index.md") | Should -BeTrue

            $content = Get-Content (Join-Path $sectionPath "_index.md") -Raw
            $content | Should -Match "title = `"$originalName`""
            $content | Should -Match "directory_name = `"$directory`""
        }
    }

    Describe "ConvertTo-DrawingTitle" {
        It "Formats '<Name>' as '<Title>'" -ForEach @(
            @{ Name = "001_БотДляМурмана_ОбщееРасположение_1945.tif"; Title = "Бот Для Мурмана – Общее расположение" }
            @{ Name = "1185_Дори_Длина8,8м_ПодъемноеУстройство_Детали_1950.pdf"; Title = "Дори – Длина 8,8 м – Подъемное устройство – Детали" }
            @{ Name = "132_п_ИзотермическийПлашкоут_45т_РулевоеУстройство_1956.tif"; Title = "Изотермический Плашкоут – 45 т – Рулевое устройство" }
            @{ Name = "ШР_100_ШлюпкаРабочая_4,0метра_РеёкДляЧехла_1965.pdf"; Title = "Шлюпка Рабочая – 4,0 метра – Реёк для чехла" }
            @{ Name = "02_4976-6_Сетеотводитель_ОбщийВид_1960.tif"; Title = "Сетеотводитель – Общий вид" }
            @{ Name = "51998_МоторноПарусныйБотВасильева_ФильтрДляТоплива_1944.tif"; Title = "Моторно-парусный Бот Васильева – Фильтр для топлива" }
            @{ Name = "238_КатерСудоверфь№1_МасштабБонжана_1943.tif"; Title = "Катер Судоверфь №1 – Масштаб Бонжана" }
            @{ Name = "2311_ПереоборудованиеЛебедкиВГрузовую_РедукторЧервячный_1953.tif"; Title = "Переоборудование Лебедки В Грузовую – Редуктор червячный" }
            @{ Name = "854_Бот_Двигатель3-Д-6_ТрубопроводМасляный_1948.tif"; Title = "Бот – Двигатель 3-Д-6 – Трубопровод масляный" }
            @{ Name = "1404_Шхуна_КормоваяСтенка_1951_1951.tif"; Title = "Шхуна – Кормовая стенка" }
            @{ Name = "2145_Шхуна_ПредохранительныйКлапан_1953.tif.tif"; Title = "Шхуна – Предохранительный клапан" }
            @{ Name = "551_Шлюпка_Руль_1946(лист2).tif"; Title = "Шлюпка – Руль – Лист 2" }
            @{ Name = "(дубль)708а_Бот_ГребнаяАрматура.tif"; Title = "Бот – Гребная арматура" }
            @{ Name = "99_СудаГидробазы_ЦинковаяЗащита_1963 (2).tif"; Title = "Суда Гидробазы – Цинковая защита" }
            @{ Name = "ОписьЧертежейПоМотовельботу.tif"; Title = "Опись Чертежей По Мотовельботу" }
            @{ Name = "955.tif"; Title = "955" }
        ) {
            ConvertTo-DrawingTitle $Name | Should -BeExactly $Title
        }
    }

    Describe "Get-DrawingNumber" {
        It "Reads '<Number>' from '<Name>'" -ForEach @(
            @{ Name = "001_БотДляМурмана_1945.tif"; Number = "001" }
            @{ Name = "001а_Бот_ДляМурмана_1943.tif"; Number = "001а" }
            @{ Name = "132_п_Плашкоут_1956.tif"; Number = "132-п" }
            @{ Name = "1399_1_Шхуна_1951.tif"; Number = "1399-1" }
            @{ Name = "ШР_51_Шлюпка_1963.tif"; Number = "ШР-51" }
            @{ Name = "ВН05-92-1_Ушко_1941.tif"; Number = "ВН05-92-1" }
            @{ Name = "02_4976-6_Шхуна_1950.tif"; Number = "02-4976-6" }
            @{ Name = "ОписьЧертежей.tif"; Number = "" }
        ) {
            Get-DrawingNumber $Name | Should -BeExactly $Number
        }
    }

    Describe "Format-JsonFileIntoContent ordering" {
        It "Numbers pages in sheet order, not alphabetically by title" {
            $metadataFile = Join-Path $testMetadataPath "order.json"
            @{
                Directory    = "order"
                OriginalName = "Порядок"
                # Listed in the wrong order on purpose: real metadata is in text order (10 before 2)
                Files        = [ordered]@{
                    "ten"   = @{ OriginalName = "10_Анкер_1950.tif"; Tags = @(); Thumbnails = @{} }
                    "twoA"  = @{ OriginalName = "2а_Болт_1950.tif"; Tags = @(); Thumbnails = @{} }
                    "two"   = @{ OriginalName = "2_Якорь_1950.tif"; Tags = @(); Thumbnails = @{} }
                }
            } | ConvertTo-Json -Depth 5 | Out-File $metadataFile -Encoding utf8

            Format-JsonFileIntoContent -JsonPath $metadataFile -OutputPath $testZolaPath

            Get-Content (Join-Path $testZolaPath "order/two.md") -Raw | Should -Match 'weight = 1\b'
            Get-Content (Join-Path $testZolaPath "order/twoA.md") -Raw | Should -Match 'weight = 2\b'
            Get-Content (Join-Path $testZolaPath "order/ten.md") -Raw | Should -Match 'weight = 3\b'
            Get-Content (Join-Path $testZolaPath "order/_index.md") -Raw | Should -Match 'sort_by = "weight"'
        }
    }

    Describe "Parameter Validation" {
        It "Throws when metadata path doesn't exist" {
            # Act & Assert
            { ./Convert-ToZola.ps1 -MetadataPath "TestDrive:/NonExistent" -ZolaContentPath $testZolaPath } |
                Should -Throw
        }
    }

    Describe "ConvertTo-ZolaContent Selective Deletion" {
        It "Preserves static pages but removes metadata-based directories" {
            # Arrange - Create metadata with one JSON file
            $metadataPath = "TestDrive:\metadata"
            $zolaContentPath = "TestDrive:\zola-content"
            New-Item -Path $metadataPath -ItemType Directory -Force
            New-Item -Path $zolaContentPath -ItemType Directory -Force

            # Create a static "about" directory (like in template)
            $aboutPath = Join-Path $zolaContentPath "about"
            New-Item -Path $aboutPath -ItemType Directory -Force
            "Static content" | Out-File (Join-Path $aboutPath "index.md")

            # Create a directory that should be deleted (from previous metadata run)
            $oldMetadataDir = Join-Path $zolaContentPath "old-fond-123"
            New-Item -Path $oldMetadataDir -ItemType Directory -Force
            "Old content" | Out-File (Join-Path $oldMetadataDir "old-file.md")

            # Create JSON metadata file for a different directory
            $jsonData = @{
                Directory = "fond-456"
                OriginalName = "Test Fond 456"
                Files = @{
                    "hash123" = @{
                        OriginalName = "test.tif"
                        ResultFileName = "test.tif"
                        PngFile = "test.png"
                        Tags = @()
                        Thumbnails = @{}
                    }
                }
            }
            $jsonData | ConvertTo-Json -Depth 10 | Out-File (Join-Path $metadataPath "fond-456.json") -Encoding utf8

            # Act - Run the conversion script
            & "$PSScriptRoot/../ConvertTo-ZolaContent.ps1" -MetadataPath $metadataPath -ZolaContentPath $zolaContentPath

            # Assert
            # Static "about" directory should still exist
            Test-Path $aboutPath | Should -BeTrue
            Test-Path (Join-Path $aboutPath "index.md") | Should -BeTrue

            # Old metadata directory should be deleted (not in current metadata)
            Test-Path $oldMetadataDir | Should -BeFalse

            # New metadata directory should exist
            $newMetadataDir = Join-Path $zolaContentPath "fond-456"
            Test-Path $newMetadataDir | Should -BeTrue
            Test-Path (Join-Path $newMetadataDir "_index.md") | Should -BeTrue
        }

        It "Removes multiple old metadata directories but preserves multiple static pages" {
            # Arrange
            $metadataPath = "TestDrive:\metadata2"
            $zolaContentPath = "TestDrive:\zola-content2"
            New-Item -Path $metadataPath -ItemType Directory -Force
            New-Item -Path $zolaContentPath -ItemType Directory -Force

            # Create multiple static directories (from template)
            $aboutPath = Join-Path $zolaContentPath "about"
            $contactPath = Join-Path $zolaContentPath "contact"
            New-Item -Path $aboutPath -ItemType Directory -Force
            New-Item -Path $contactPath -ItemType Directory -Force
            "About page" | Out-File (Join-Path $aboutPath "index.md")
            "Contact page" | Out-File (Join-Path $contactPath "index.md")

            # Create old metadata directories (from previous run)
            $oldDir1 = Join-Path $zolaContentPath "old-collection-1"
            $oldDir2 = Join-Path $zolaContentPath "old-collection-2"
            New-Item -Path $oldDir1 -ItemType Directory -Force
            New-Item -Path $oldDir2 -ItemType Directory -Force
            "Old content 1" | Out-File (Join-Path $oldDir1 "file.md")
            "Old content 2" | Out-File (Join-Path $oldDir2 "file.md")

            # Create only one new JSON metadata file
            $jsonData = @{
                Directory = "new-collection"
                OriginalName = "New Collection"
                Files = @{
                    "hash456" = @{
                        OriginalName = "document.tif"
                        ResultFileName = "document.tif"
                        PngFile = "document.png"
                        Tags = @("test")
                        Thumbnails = @{}
                    }
                }
            }
            $jsonData | ConvertTo-Json -Depth 10 | Out-File (Join-Path $metadataPath "new-collection.json") -Encoding utf8

            # Act
            & "$PSScriptRoot/../ConvertTo-ZolaContent.ps1" -MetadataPath $metadataPath -ZolaContentPath $zolaContentPath

            # Assert
            # Static pages should be preserved
            Test-Path $aboutPath | Should -BeTrue
            Test-Path (Join-Path $aboutPath "index.md") | Should -BeTrue
            Test-Path $contactPath | Should -BeTrue
            Test-Path (Join-Path $contactPath "index.md") | Should -BeTrue

            # Old metadata directories should be deleted
            Test-Path $oldDir1 | Should -BeFalse
            Test-Path $oldDir2 | Should -BeFalse

            # New metadata directory should exist
            $newDir = Join-Path $zolaContentPath "new-collection"
            Test-Path $newDir | Should -BeTrue
        }
    }

    # Convert-ToZola.Tests.ps1

    Describe "New-ContentPage" {
        BeforeEach {
            $testOutputPath = "TestDrive:\content"
            New-Item -Path $testOutputPath -ItemType Directory -Force
        }

        It "Creates basic page with minimal metadata" {
            # Arrange
            $directory = "test-dir"
            $fileId = "test-123"
            $fileData = [PSCustomObject]@{
                OriginalName = "test.tif"
                Tags         = @()
                Thumbnails   = @()
            }

            # Act
            New-ContentPage -Directory $directory `
                -FileId $fileId `
                -FileData $fileData `
                -OutputPath $testOutputPath

            # Assert
            $pagePath = Join-Path $testOutputPath $directory
            $filePath = Join-Path $pagePath "$fileId.md"

            Test-Path $filePath | Should -BeTrue
            $content = Get-Content $filePath -Raw
            $content | Should -Match 'title = "test"'
            $content | Should -Match 'file_id = "test-123"'
            $content | Should -Match 'directory_name = "test-dir"'
        }

        It "Writes the clean title and sheet number, keeping the year separately" {
            $fileData = [PSCustomObject]@{
                OriginalName = "001_БотДляМурмана_ОбщееРасположение_1945.tif"
                Tags         = @()
                Year         = "1945"
                Thumbnails   = @()
            }

            New-ContentPage -Directory "drawing" -FileId "drawing-1" -FileData $fileData -OutputPath $testOutputPath -Weight 7

            $content = Get-Content (Join-Path $testOutputPath "drawing/drawing-1.md") -Raw -Encoding utf8
            $content | Should -Match 'title = "Бот Для Мурмана – Общее расположение"'
            $content | Should -Match 'sheet_no = "001"'
            $content | Should -Match 'scan_year = "1945"'
            $content | Should -Match 'weight = 7\b'
            # Zola needs weight before [extra], otherwise it is not a page field
            $content.IndexOf('weight =') | Should -BeLessThan $content.IndexOf('[extra]')
        }

        It "Omits sheet_no and weight when there is none" {
            $fileData = [PSCustomObject]@{
                OriginalName = "ОписьЧертежей.tif"
                Tags         = @()
                Thumbnails   = @()
            }

            New-ContentPage -Directory "plain" -FileId "plain-1" -FileData $fileData -OutputPath $testOutputPath

            $content = Get-Content (Join-Path $testOutputPath "plain/plain-1.md") -Raw -Encoding utf8
            $content | Should -Not -Match 'sheet_no ='
            $content | Should -Not -Match 'weight ='
        }

        It "Includes all optional metadata when provided" {
            # Arrange
            $fileData = [PSCustomObject]@{
                OriginalName   = "full-test.tif"
                Tags           = @("tag1", "tag2")
                Year           = "2024"
                ResultFileName = "result.tif"
                PngFile        = "preview.png"
                Thumbnails     = [PSCustomObject]@{
                    "400" = "thumb-400.png"
                }
            }

            # Act
            New-ContentPage -Directory "full-test" `
                -FileId "full-123" `
                -FileData $fileData `
                -OutputPath $testOutputPath

            # Assert
            $content = Get-Content (Join-Path $testOutputPath "full-test/full-123.md") -Raw
            $content | Should -Match 'scan_year = "2024"'
            $content | Should -Match 'tif_file = "result.tif"'
            $content | Should -Match 'png_file = "preview.png"'
            $content | Should -Match 'thumbnail = "thumb-400.png"'
            $content | Should -Match '\[taxonomies\]'
            $content | Should -Match 'tags = \["tag1","tag2"\]'
        }

        It "Handles missing thumbnail property" {
            # Arrange
            $fileData = [PSCustomObject]@{
                OriginalName = "no-thumb.tif"
                Tags         = @()
                Thumbnails   = [PSCustomObject]@{}
            }

            # Act
            New-ContentPage -Directory "no-thumb" `
                -FileId "no-123" `
                -FileData $fileData `
                -OutputPath $testOutputPath

            # Assert
            $content = Get-Content (Join-Path $testOutputPath "no-thumb/no-123.md") -Raw
            $content | Should -Not -Match 'thumbnail ='
        }

        It "Handles single tag as JSON array" {
            # Arrange
            $directory = "single-tag"
            $fileId = "single-123"
            $fileData = [PSCustomObject]@{
                OriginalName = "single-tag-document.tif"
                Tags = "SingleTag"  # Single string, not array
                Year = "2023"
                ResultFileName = "single-tag-document.tif"
                PngFile = "single-tag-document.png"
                Thumbnails = @{}
            }

            # Act
            New-ContentPage -Directory $directory `
                -FileId $fileId `
                -FileData $fileData `
                -OutputPath $testOutputPath

            # Assert
            $contentPath = Join-Path $testOutputPath $directory "$fileId.md"
            $content = Get-Content $contentPath -Raw

            # Should output as JSON array even for single tag
            $content | Should -Match 'tags = \["SingleTag"\]'
            $content | Should -Not -Match 'tags = "SingleTag"'
        }

        It "Handles multiple tags as JSON array" {
            # Arrange
            $directory = "multi-tag"
            $fileId = "multi-123"
            $fileData = [PSCustomObject]@{
                OriginalName = "multi-tag-document.tif"
                Tags = @("Tag1", "Tag2", "Tag3")  # Multiple tags array
                Year = "2023"
                ResultFileName = "multi-tag-document.tif"
                PngFile = "multi-tag-document.png"
                Thumbnails = @{}
            }

            # Act
            New-ContentPage -Directory $directory `
                -FileId $fileId `
                -FileData $fileData `
                -OutputPath $testOutputPath

            # Assert
            $contentPath = Join-Path $testOutputPath $directory "$fileId.md"
            $content = Get-Content $contentPath -Raw

            # Should output as JSON array for multiple tags
            $content | Should -Match 'tags = \["Tag1","Tag2","Tag3"\]'
        }

        It "Handles empty tags gracefully" {
            # Arrange
            $directory = "empty-tags"
            $fileId = "empty-123"
            $fileData = [PSCustomObject]@{
                OriginalName = "no-tags-document.tif"
                Tags = @()  # Empty array
                Year = "2023"
                ResultFileName = "no-tags-document.tif"
                PngFile = "no-tags-document.png"
                Thumbnails = @{}
            }

            # Act
            New-ContentPage -Directory $directory `
                -FileId $fileId `
                -FileData $fileData `
                -OutputPath $testOutputPath

            # Assert
            $contentPath = Join-Path $testOutputPath $directory "$fileId.md"
            $content = Get-Content $contentPath -Raw

            # Should not include tags section when empty
            $content | Should -Not -Match '\[taxonomies\]'
            $content | Should -Not -Match 'tags ='
        }

        It "Handles null tags gracefully" {
            # Arrange
            $directory = "null-tags"
            $fileId = "null-123"
            $fileData = [PSCustomObject]@{
                OriginalName = "null-tags-document.tif"
                Tags = $null  # Null tags
                Year = "2023"
                ResultFileName = "null-tags-document.tif"
                PngFile = "null-tags-document.png"
                Thumbnails = @{}
            }

            # Act
            New-ContentPage -Directory $directory `
                -FileId $fileId `
                -FileData $fileData `
                -OutputPath $testOutputPath

            # Assert
            $contentPath = Join-Path $testOutputPath $directory "$fileId.md"
            $content = Get-Content $contentPath -Raw

            # Should not include tags section when null
            $content | Should -Not -Match '\[taxonomies\]'
            $content | Should -Not -Match 'tags ='
        }

        It "Writes the main category as the razdely taxonomy next to tags" {
            $fileData = [PSCustomObject]@{
                OriginalName = "1371_ЗверобойнаяШхуна_ЛеернаяСтойка_1951.tif"
                Tags         = @("Зверобойная Шхуна", "Леерная Стойка")
                Thumbnails   = @{}
                MainCategory = "Шхуны"
            }

            New-ContentPage -Directory "cat" -FileId "cat-1" -FileData $fileData -OutputPath $testOutputPath

            $content = Get-Content (Join-Path $testOutputPath "cat/cat-1.md") -Raw -Encoding utf8
            $content | Should -Match 'razdely = \["Шхуны"\]'
            $content | Should -Match 'tags = \['
            ([regex]::Matches($content, '\[taxonomies\]')).Count | Should -Be 1
            $content.IndexOf('razdely =') | Should -BeGreaterThan $content.IndexOf('[taxonomies]')
        }

        It "Writes the razdely taxonomy when there are no tags" {
            $fileData = [PSCustomObject]@{
                OriginalName = "ОписьЧертежей.tif"
                Tags         = $null
                Thumbnails   = @{}
                MainCategory = "Верфь: цеха и здания"
            }

            New-ContentPage -Directory "cat" -FileId "cat-2" -FileData $fileData -OutputPath $testOutputPath

            $content = Get-Content (Join-Path $testOutputPath "cat/cat-2.md") -Raw -Encoding utf8
            $content | Should -Match '\[taxonomies\]'
            $content | Should -Match 'razdely = \["Верфь: цеха и здания"\]'
            $content | Should -Not -Match 'tags ='
        }

        It "Omits razdely when the main category is <Case>" -ForEach @(
            @{ Case = "null"; Value = $null }
            @{ Case = "empty"; Value = "" }
            @{ Case = "blank"; Value = "  " }
        ) {
            $fileData = [PSCustomObject]@{
                OriginalName = "test.tif"
                Tags         = @()
                Thumbnails   = @{}
                MainCategory = $Value
            }

            New-ContentPage -Directory "cat" -FileId "cat-3" -FileData $fileData -OutputPath $testOutputPath

            $content = Get-Content (Join-Path $testOutputPath "cat/cat-3.md") -Raw -Encoding utf8
            $content | Should -Not -Match 'razdely'
            $content | Should -Not -Match '\[taxonomies\]'
        }

        It "Escapes quotes in the main category" {
            $fileData = [PSCustomObject]@{
                OriginalName = "test.tif"
                Tags         = @()
                Thumbnails   = @{}
                MainCategory = 'Шхуна "Запад"'
            }

            New-ContentPage -Directory "cat" -FileId "cat-4" -FileData $fileData -OutputPath $testOutputPath

            $content = Get-Content (Join-Path $testOutputPath "cat/cat-4.md") -Raw -Encoding utf8
            $content | Should -Match ([regex]::Escape('razdely = ["Шхуна \"Запад\""]'))
        }
    }
}
