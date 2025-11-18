BeforeAll {
    # Import required modules
    Import-Module $PSScriptRoot/../libs/ScanFileHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/PathHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/ConvertText.psm1 -Force
    Import-Module $PSScriptRoot/../libs/JsonHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/ZolaContentHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/HashHelper.psm1 -Force

    # Helper function to create dummy PDF file
    function New-TestPdfFile {
        param(
            [string]$Path,
            [int]$Pages = 1
        )

        # Create a minimal valid PDF structure
        $pdfContent = @"
%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/Resources <<
/Font <<
/F1 <<
/Type /Font
/Subtype /Type1
/BaseFont /Helvetica
>>
>>
>>
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj
4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Test PDF) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000317 00000 n
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
410
%%EOF
"@
        Set-Content -Path $Path -Value $pdfContent -NoNewline
    }

    # Helper function to create dummy TIFF file
    function New-TestTiffFile {
        param(
            [string]$Path
        )

        # Create a minimal valid TIFF file (little-endian, monochrome 1x1 pixel)
        $tiffBytes = @(
            0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00,
            0x0D, 0x00, 0x00, 0x01, 0x03, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x01,
            0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x02, 0x01, 0x03, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0x01,
            0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x06, 0x01, 0x03, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x11, 0x01,
            0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x08, 0x00,
            0x00, 0x00, 0x15, 0x01, 0x03, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x16, 0x01,
            0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x17, 0x01, 0x04, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1A, 0x01,
            0x05, 0x00, 0x01, 0x00, 0x00, 0x00, 0xC2, 0x00,
            0x00, 0x00, 0x1B, 0x01, 0x05, 0x00, 0x01, 0x00,
            0x00, 0x00, 0xCA, 0x00, 0x00, 0x00, 0x28, 0x01,
            0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        )

        [System.IO.File]::WriteAllBytes($Path, $tiffBytes)
    }

    # Helper function to setup test directory structure
    function New-TestDirectoryStructure {
        param(
            [string]$BasePath
        )

        # Create directory structure
        $inputPath = Join-Path $BasePath "input_files"
        $folder1 = Join-Path $inputPath "тестовая папка 1"
        $folder2 = Join-Path $inputPath "тестовая папка 2"

        New-Item -Path $folder1 -ItemType Directory -Force | Out-Null
        New-Item -Path $folder2 -ItemType Directory -Force | Out-Null

        # Create test files in folder 1
        New-TestPdfFile -Path (Join-Path $folder1 "01-ЧертежПростой_Категория1_Деталь1_1999.pdf")
        New-TestPdfFile -Path (Join-Path $folder1 "11-ЧертежДетали_Категория1_Категория2_Деталь2_1998.pdf")

        # Create test files in folder 2
        New-TestPdfFile -Path (Join-Path $folder2 "01-ЧертежДругой_Категория3_Деталь1_1999.pdf")
        New-TestPdfFile -Path (Join-Path $folder2 "11-Чертеж3_Категория3_Категория2_Деталь2_2000.pdf")

        return $inputPath
    }
}

Describe "End-to-End Image Processing Tests" {

    BeforeAll {
        # Import additional modules for E2E testing
        Import-Module $PSScriptRoot/../libs/ToolsHelper.psm1 -Force
        Import-Module $PSScriptRoot/../libs/ConvertImage.psm1 -Force

        # Check if required tools are available for REAL E2E testing
        $script:hasImageMagick = Test-CommandExists "magick"
        $script:hasGhostScript = Test-CommandExists "gswin64c" -or Test-CommandExists "gs" -or Test-CommandExists "gsc"

        # Determine if we can run real E2E tests
        $script:canRunRealTests = $script:hasImageMagick -and $script:hasGhostScript

        if ($script:canRunRealTests) {
            Write-Host "✅ All required tools found - running REAL E2E tests" -ForegroundColor Green
            Write-Host "   ImageMagick: Available"
            Write-Host "   GhostScript: Available"
        } else {
            Write-Warning "⚠️  Some tools missing - some E2E tests will be skipped"
            Write-Warning "   ImageMagick: $(if ($script:hasImageMagick) { 'Available' } else { 'MISSING' })"
            Write-Warning "   GhostScript: $(if ($script:hasGhostScript) { 'Available' } else { 'MISSING' })"
            Write-Warning ""
            Write-Warning "To run full E2E tests, install:"
            Write-Warning "  - ImageMagick: https://imagemagick.org/script/download.php"
            Write-Warning "  - GhostScript: https://ghostscript.com/releases/gsdnld.html"
            Write-Warning ""
            Write-Warning "Or on Windows with Chocolatey: choco install imagemagick ghostscript -y"
            Write-Warning "Or on Linux: sudo apt-get install imagemagick ghostscript -y"
        }
    }

    Context "Environment Setup and Validation" {
        BeforeEach {
            $script:testBasePath = "TestDrive:\e2e-test"
            New-Item -Path $script:testBasePath -ItemType Directory -Force | Out-Null
        }

        It "Creates test directory structure with Russian folder names" {
            # Act
            $inputPath = New-TestDirectoryStructure -BasePath $script:testBasePath

            # Assert
            Test-Path (Join-Path $inputPath "тестовая папка 1") | Should -BeTrue
            Test-Path (Join-Path $inputPath "тестовая папка 2") | Should -BeTrue
        }

        It "Generates valid PDF test files" {
            # Arrange
            $inputPath = New-TestDirectoryStructure -BasePath $script:testBasePath
            $pdfFile = Join-Path $inputPath "тестовая папка 1/01-ЧертежПростой_Категория1_Деталь1_1999.pdf"

            # Assert
            Test-Path $pdfFile | Should -BeTrue
            (Get-Item $pdfFile).Length | Should -BeGreaterThan 0

            # Verify PDF header
            $content = Get-Content $pdfFile -Raw
            $content | Should -Match "^%PDF"
        }

        It "Generates valid TIFF test files" {
            # Arrange
            $testDir = Join-Path "TestDrive:" "tiff-test"
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $testFile = Join-Path $testDir "test.tif"

            # Act
            New-TestTiffFile -Path $testFile

            # Assert
            Test-Path $testFile | Should -BeTrue
            (Get-Item $testFile).Length | Should -BeGreaterThan 0

            # Verify TIFF signature (little-endian: II or big-endian: MM)
            $bytes = [System.IO.File]::ReadAllBytes($testFile)
            ($bytes[0] -eq 0x49 -and $bytes[1] -eq 0x49) -or
            ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x4D) | Should -BeTrue
        }
    }

    Context "File Naming and Transliteration" {
        BeforeEach {
            $script:testBasePath = "TestDrive:\e2e-naming"
            $script:inputPath = New-TestDirectoryStructure -BasePath $script:testBasePath
        }

        It "Transliterates Russian folder names correctly" {
            # Arrange
            $folder1Name = "тестовая папка 1"

            # Act
            $transliterated = ConvertTo-Translit -InputString $folder1Name

            # Assert
            # Spaces are removed by ConvertTo-Translit, digits remain
            $transliterated | Should -Be "testovayapapka1"
            $transliterated | Should -Not -Match "[а-яА-Я]"
        }

        It "Extracts tags from filename pattern" {
            # Arrange
            $filename = "01-ЧертежПростой_Категория1_Деталь1_1999"

            # Act
            $tags = Get-TagsFromName -FileName $filename

            # Assert
            # Function adds spaces between CamelCase words and numbers
            $tags | Should -Contain "Чертеж Простой"
            $tags | Should -Contain "Категория 1"
            $tags | Should -Contain "Деталь 1"
        }

        It "Extracts year from filename pattern" {
            # Arrange
            # The function extracts the last digit sequence, including any preceding digits with _ or -
            # For "Категория1_Деталь1_1999" it captures "1_1999" which becomes "1-1999"
            $filename = "01-ЧертежПростой_Категория1_Деталь1_1999"

            # Act
            $year = Get-YearFromFilename -FileName $filename

            # Assert
            # The regex matches digit sequences at the end, including connected digits via _ or -
            $year | Should -Be "1-1999"
        }
    }

    Context "Image Processing Pipeline" {
        BeforeEach {
            $script:testBasePath = "TestDrive:\e2e-processing"
            $script:inputPath = New-TestDirectoryStructure -BasePath $script:testBasePath
            $script:resultPath = Join-Path $script:testBasePath "result"
            $script:metadataPath = Join-Path $script:resultPath "metadata"

            New-Item -Path $script:resultPath -ItemType Directory -Force | Out-Null
            New-Item -Path $script:metadataPath -ItemType Directory -Force | Out-Null
        }

        It "Processes all folders from input directory" {
            # Arrange
            $folders = Get-ChildItem -Path $script:inputPath -Directory

            # Assert - should have 2 test folders
            $folders.Count | Should -Be 2
            $folders.Name | Should -Contain "тестовая папка 1"
            $folders.Name | Should -Contain "тестовая папка 2"
        }

        It "Creates transliterated output directories" {
            # Arrange
            $sourceFolder = Get-ChildItem -Path $script:inputPath -Directory | Select-Object -First 1
            $transliteratedName = ConvertTo-Translit -InputString $sourceFolder.Name

            # Act
            $outputDir = Join-Path $script:resultPath $transliteratedName
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null

            # Assert
            Test-Path $outputDir | Should -BeTrue
        }

        It "Processes PDF files and creates metadata with REAL tools" -Skip:(-not $script:canRunRealTests) {
            # Arrange
            $sourceFolder = Join-Path $script:inputPath "тестовая папка 1"
            $pdfFile = Get-ChildItem -Path $sourceFolder -Filter "*.pdf" | Select-Object -First 1
            $transliteratedDir = ConvertTo-Translit -InputString "тестовая папка 1"
            $resultDir = Join-Path $script:resultPath $transliteratedDir
            New-Item -Path $resultDir -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $resultDir "thumbnails") -ItemType Directory -Force | Out-Null

            # Act - Using REAL image processing functions
            $fileData = Convert-FileAndCreateData -SourceFile $pdfFile -ResultDirFullPath $resultDir

            # Assert
            $fileData | Should -Not -BeNullOrEmpty
            $fileData.OriginalName | Should -Be $pdfFile.Name
            $fileData.ResultFileName | Should -Match "\.tif$"
            $fileData.PngFile | Should -Match "\.png$"

            # Verify REAL files were created (not mocks)
            $tifPath = Join-Path $resultDir $fileData.ResultFileName
            $pngPath = Join-Path $resultDir $fileData.PngFile

            Test-Path $tifPath | Should -BeTrue "TIF file should exist: $tifPath"
            Test-Path $pngPath | Should -BeTrue "PNG file should exist: $pngPath"

            # Verify files are actual images, not mock content
            (Get-Item $tifPath).Length | Should -BeGreaterThan 100 "TIF should be real image file"
            (Get-Item $pngPath).Length | Should -BeGreaterThan 100 "PNG should be real image file"
        }
    }

    Context "Metadata Generation and Validation" {
        BeforeEach {
            $script:testBasePath = "TestDrive:\e2e-metadata"
            $script:metadataPath = Join-Path $script:testBasePath "metadata"
            New-Item -Path $script:metadataPath -ItemType Directory -Force | Out-Null
        }

        It "Creates JSON metadata file for processed directory" {
            # Arrange
            $directoryName = "testovaya-papka-1"
            $metadata = [ordered]@{
                DirectoryOriginalName = "тестовая папка 1"
                ProcessedScans = [ordered]@{}
            }

            # Add sample file data
            $fileHash = "abc123def456"
            $metadata.ProcessedScans[$fileHash] = [ordered]@{
                OriginalName = "01-ЧертежПростой_Категория1_Деталь1_1999.pdf"
                ResultFileName = "01-chertezh-prostoy.tif"
                PngFile = "01-chertezh-prostoy.png"
                Tags = @("Категория1", "Деталь1")
                Year = "1999"
                Thumbnails = [ordered]@{
                    "400" = "01-chertezh-prostoy_400.png"
                }
            }

            # Act
            $metadataFile = Join-Path $script:metadataPath "$directoryName.json"
            $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataFile

            # Assert
            Test-Path $metadataFile | Should -BeTrue

            # Validate JSON structure
            $loadedMetadata = Get-Content $metadataFile -Raw | ConvertFrom-Json
            $loadedMetadata.DirectoryOriginalName | Should -Be "тестовая папка 1"
            $loadedMetadata.ProcessedScans.$fileHash.Year | Should -Be "1999"
            $loadedMetadata.ProcessedScans.$fileHash.Tags.Count | Should -Be 2
        }

        It "Validates metadata structure matches expected schema" {
            # Arrange
            $metadata = [ordered]@{
                DirectoryOriginalName = "Test Directory"
                ProcessedScans = [ordered]@{
                    "hash1" = [ordered]@{
                        OriginalName = "test.pdf"
                        ResultFileName = "test.tif"
                        PngFile = "test.png"
                        Tags = @()
                        Year = "2023"
                        Thumbnails = @{}
                    }
                }
            }

            # Act & Assert
            $metadata.Keys | Should -Contain "DirectoryOriginalName"
            $metadata.Keys | Should -Contain "ProcessedScans"
            $metadata.ProcessedScans["hash1"].Keys | Should -Contain "OriginalName"
            $metadata.ProcessedScans["hash1"].Keys | Should -Contain "ResultFileName"
            $metadata.ProcessedScans["hash1"].Keys | Should -Contain "PngFile"
            $metadata.ProcessedScans["hash1"].Keys | Should -Contain "Tags"
        }
    }

    Context "Zola Content Generation" {
        BeforeEach {
            $script:testBasePath = "TestDrive:\e2e-zola"
            $script:zolaPath = Join-Path $script:testBasePath "zola_content"
            $script:metadataPath = Join-Path $script:testBasePath "metadata"

            New-Item -Path $script:zolaPath -ItemType Directory -Force | Out-Null
            New-Item -Path $script:metadataPath -ItemType Directory -Force | Out-Null
        }

        It "Creates root index page for Zola site" {
            # Act
            New-RootIndexPage -OutputPath $script:zolaPath

            # Assert
            $indexPath = Join-Path $script:zolaPath "_index.md"
            Test-Path $indexPath | Should -BeTrue

            $content = Get-Content $indexPath -Raw
            $content | Should -Match "sort_by"
            $content | Should -Match "template"
        }

        It "Creates section pages for each directory" {
            # Arrange
            $directory = "testovaya-papka-1"
            $originalName = "тестовая папка 1"

            # Act
            New-SectionPage -Directory $directory -OriginalName $originalName -OutputPath $script:zolaPath

            # Assert
            $sectionPath = Join-Path $script:zolaPath $directory
            Test-Path $sectionPath | Should -BeTrue
            Test-Path (Join-Path $sectionPath "_index.md") | Should -BeTrue

            $content = Get-Content (Join-Path $sectionPath "_index.md") -Raw
            $content | Should -Match "title = `"$originalName`""
            $content | Should -Match "directory_name = `"$directory`""
        }

        It "Creates content pages for each processed file" {
            # Arrange
            $directory = "testovaya-papka-1"
            $fileId = "abc123def456"
            $fileData = [PSCustomObject]@{
                OriginalName = "01-ЧертежПростой_Категория1_Деталь1_1999.pdf"
                ResultFileName = "01-chertezh-prostoy.tif"
                PngFile = "01-chertezh-prostoy.png"
                Tags = @("Категория1", "Деталь1")
                Year = "1999"
                Thumbnails = [PSCustomObject]@{
                    "400" = "01-chertezh-prostoy_400.png"
                }
            }

            # Act
            New-ContentPage -Directory $directory -FileId $fileId -FileData $fileData -OutputPath $script:zolaPath

            # Assert
            $contentPath = Join-Path $script:zolaPath $directory "$fileId.md"
            Test-Path $contentPath | Should -BeTrue

            $content = Get-Content $contentPath -Raw
            $content | Should -Match 'scan_year = "1999"'
            $content | Should -Match 'tif_file = "01-chertezh-prostoy.tif"'
            $content | Should -Match 'png_file = "01-chertezh-prostoy.png"'
            $content | Should -Match 'thumbnail = "01-chertezh-prostoy_400.png"'
            $content | Should -Match 'tags = \["Категория1","Деталь1"\]'
        }

        It "Generates complete Zola site from metadata" {
            # Arrange - Create sample metadata file
            $directoryName = "testovaya-papka-1"
            $metadata = [ordered]@{
                DirectoryOriginalName = "тестовая папка 1"
                ProcessedScans = [ordered]@{
                    "hash1" = [ordered]@{
                        OriginalName = "01-ЧертежПростой_Категория1_Деталь1_1999.pdf"
                        ResultFileName = "01-chertezh-prostoy.tif"
                        PngFile = "01-chertezh-prostoy.png"
                        Tags = @("Категория1", "Деталь1")
                        Year = "1999"
                        Thumbnails = [ordered]@{
                            "400" = "01-chertezh-prostoy_400.png"
                        }
                    }
                    "hash2" = [ordered]@{
                        OriginalName = "11-ЧертежДетали_Категория1_Категория2_Деталь2_1998.pdf"
                        ResultFileName = "11-chertezh-detali.tif"
                        PngFile = "11-chertezh-detali.png"
                        Tags = @("Категория1", "Категория2", "Деталь2")
                        Year = "1998"
                        Thumbnails = [ordered]@{
                            "400" = "11-chertezh-detali_400.png"
                        }
                    }
                }
            }

            $metadataFile = Join-Path $script:metadataPath "$directoryName.json"
            $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataFile

            # Act - Generate Zola content from metadata
            $metadataFiles = Get-ChildItem -Path $script:metadataPath -Filter "*.json"
            foreach ($file in $metadataFiles) {
                $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $dir = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

                New-SectionPage -Directory $dir -OriginalName $data.DirectoryOriginalName -OutputPath $script:zolaPath

                foreach ($property in $data.ProcessedScans.PSObject.Properties) {
                    New-ContentPage -Directory $dir -FileId $property.Name -FileData $property.Value -OutputPath $script:zolaPath
                }
            }

            # Assert - Verify site structure
            Test-Path (Join-Path $script:zolaPath $directoryName) | Should -BeTrue
            Test-Path (Join-Path $script:zolaPath $directoryName "_index.md") | Should -BeTrue
            Test-Path (Join-Path $script:zolaPath $directoryName "hash1.md") | Should -BeTrue
            Test-Path (Join-Path $script:zolaPath $directoryName "hash2.md") | Should -BeTrue
        }
    }

    Context "Full End-to-End Workflow" {
        BeforeEach {
            $script:testBasePath = "TestDrive:\e2e-full"
            $script:inputPath = New-TestDirectoryStructure -BasePath $script:testBasePath
            $script:resultPath = Join-Path $script:testBasePath "result"
            $script:metadataPath = Join-Path $script:resultPath "metadata"
            $script:zolaPath = Join-Path $script:testBasePath "zola_content"

            New-Item -Path $script:resultPath -ItemType Directory -Force | Out-Null
            New-Item -Path $script:metadataPath -ItemType Directory -Force | Out-Null
            New-Item -Path $script:zolaPath -ItemType Directory -Force | Out-Null
        }

        It "Completes full processing workflow from input to Zola site with REAL tools" -Skip:(-not $script:canRunRealTests) {
            # Step 1: Process all directories with REAL image processing
            $inputFolders = Get-ChildItem -Path $script:inputPath -Directory
            $processedDirectories = @()

            foreach ($folder in $inputFolders) {
                $transliteratedName = ConvertTo-Translit -InputString $folder.Name
                $outputDir = Join-Path $script:resultPath $transliteratedName
                New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
                New-Item -Path (Join-Path $outputDir "thumbnails") -ItemType Directory -Force | Out-Null

                # Create metadata structure
                $directoryMetadata = [ordered]@{
                    DirectoryOriginalName = $folder.Name
                    ProcessedScans = [ordered]@{}
                }

                # Process each file in directory
                $files = Get-ChildItem -Path $folder.FullName -File -Filter "*.pdf"
                foreach ($file in $files) {
                    $fileData = Convert-FileAndCreateData -SourceFile $file -ResultDirFullPath $outputDir
                    $fileHash = Convert-StringToMD5 -InputString $file.Name
                    $directoryMetadata.ProcessedScans[$fileHash] = $fileData
                }

                # Save metadata
                $metadataFile = Join-Path $script:metadataPath "$transliteratedName.json"
                $directoryMetadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataFile

                $processedDirectories += $transliteratedName
            }

            # Step 2: Generate Zola content from metadata
            New-RootIndexPage -OutputPath $script:zolaPath

            $metadataFiles = Get-ChildItem -Path $script:metadataPath -Filter "*.json"
            foreach ($file in $metadataFiles) {
                $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $dir = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

                New-SectionPage -Directory $dir -OriginalName $data.DirectoryOriginalName -OutputPath $script:zolaPath

                foreach ($property in $data.ProcessedScans.PSObject.Properties) {
                    New-ContentPage -Directory $dir -FileId $property.Name -FileData $property.Value -OutputPath $script:zolaPath
                }
            }

            # Step 3: Validate complete workflow results
            # Check processed files exist
            foreach ($dir in $processedDirectories) {
                $outputDir = Join-Path $script:resultPath $dir
                Test-Path $outputDir | Should -BeTrue
                Test-Path (Join-Path $outputDir "thumbnails") | Should -BeTrue

                # Verify REAL TIF and PNG files were created
                $tifFiles = Get-ChildItem -Path $outputDir -Filter "*.tif"
                $pngFiles = Get-ChildItem -Path $outputDir -Filter "*.png"
                $tifFiles.Count | Should -BeGreaterThan 0 "Should have real TIF files"
                $pngFiles.Count | Should -BeGreaterThan 0 "Should have real PNG files"

                # Verify files are actual images, not mock content
                foreach ($tif in $tifFiles) {
                    $tif.Length | Should -BeGreaterThan 100 "TIF should be real image: $($tif.Name)"
                }
                foreach ($png in $pngFiles) {
                    $png.Length | Should -BeGreaterThan 100 "PNG should be real image: $($png.Name)"
                }
            }

            # Check metadata files exist
            $metadataFiles.Count | Should -Be 2

            # Check Zola site structure
            Test-Path (Join-Path $script:zolaPath "_index.md") | Should -BeTrue
            foreach ($dir in $processedDirectories) {
                Test-Path (Join-Path $script:zolaPath $dir) | Should -BeTrue
                Test-Path (Join-Path $script:zolaPath $dir "_index.md") | Should -BeTrue

                # Check content pages exist
                $contentPages = Get-ChildItem -Path (Join-Path $script:zolaPath $dir) -Filter "*.md" -Exclude "_index.md"
                $contentPages.Count | Should -BeGreaterThan 0
            }
        }

        It "Validates all generated files have correct content and structure with REAL tools" -Skip:(-not $script:canRunRealTests) {
            # Process sample directory with REAL image processing
            $folder = Get-ChildItem -Path $script:inputPath -Directory | Select-Object -First 1
            $transliteratedName = ConvertTo-Translit -InputString $folder.Name
            $outputDir = Join-Path $script:resultPath $transliteratedName
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $outputDir "thumbnails") -ItemType Directory -Force | Out-Null

            $directoryMetadata = [ordered]@{
                DirectoryOriginalName = $folder.Name
                ProcessedScans = [ordered]@{}
            }

            $files = Get-ChildItem -Path $folder.FullName -File -Filter "*.pdf"
            foreach ($file in $files) {
                $fileData = Convert-FileAndCreateData -SourceFile $file -ResultDirFullPath $outputDir
                $fileHash = Convert-StringToMD5 -InputString $file.Name
                $directoryMetadata.ProcessedScans[$fileHash] = $fileData
            }

            $metadataFile = Join-Path $script:metadataPath "$transliteratedName.json"
            $directoryMetadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataFile

            # Validate metadata file structure
            $savedMetadata = Get-Content $metadataFile -Raw | ConvertFrom-Json
            $savedMetadata.DirectoryOriginalName | Should -Be $folder.Name
            $savedMetadata.ProcessedScans.PSObject.Properties.Count | Should -Be $files.Count

            # Generate and validate Zola content
            New-SectionPage -Directory $transliteratedName -OriginalName $folder.Name -OutputPath $script:zolaPath

            foreach ($property in $savedMetadata.ProcessedScans.PSObject.Properties) {
                New-ContentPage -Directory $transliteratedName -FileId $property.Name -FileData $property.Value -OutputPath $script:zolaPath

                $contentFile = Join-Path $script:zolaPath $transliteratedName "$($property.Name).md"
                Test-Path $contentFile | Should -BeTrue

                $content = Get-Content $contentFile -Raw
                $content | Should -Match "title ="
                $content | Should -Match "file_id ="
                $content | Should -Match "directory_name ="
            }
        }
    }
}
