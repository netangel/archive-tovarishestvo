BeforeAll {
    # Helper function to create minimal valid PDF
    function New-TestPdfFile {
        param([string]$Path)

        $pdfContent = @"
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>
endobj
xref
0 4
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
trailer
<< /Size 4 /Root 1 0 R >>
startxref
190
%%EOF
"@
        Set-Content -Path $Path -Value $pdfContent -NoNewline
    }

    # Verify required tools are available
    Import-Module (Join-Path $PSScriptRoot "../libs/ToolsHelper.psm1") -Force -Global

    $hasImageMagick = Test-ImageMagick
    $hasGhostScript = Test-Ghostscript

    if (-not $hasImageMagick -or -not $hasGhostScript) {
        throw "E2E tests require ImageMagick and Ghostscript. Missing: $(if (-not $hasImageMagick) { 'ImageMagick ' })$(if (-not $hasGhostScript) { 'Ghostscript' })"
    }
}

Describe "End-to-End Script Tests" {

    BeforeAll {
        # Setup test directories
        $script:testRoot = "TestDrive:\e2e-scripts"
        $script:sourcePath = Join-Path $script:testRoot "source"
        $script:resultPath = Join-Path $script:testRoot "result"
        $script:zolaPath = Join-Path $script:testRoot "zola"

        New-Item -Path $script:sourcePath -ItemType Directory -Force | Out-Null
        New-Item -Path $script:resultPath -ItemType Directory -Force | Out-Null

        # Create test input structure with Russian folder names
        $folder1 = Join-Path $script:sourcePath "тестовая папка 1"
        $folder2 = Join-Path $script:sourcePath "тестовая папка 2"

        New-Item -Path $folder1 -ItemType Directory -Force | Out-Null
        New-Item -Path $folder2 -ItemType Directory -Force | Out-Null

        # Create test PDF files with Russian names
        New-TestPdfFile -Path (Join-Path $folder1 "01-ЧертежПростой_Категория1_Деталь1_1999.pdf")
        New-TestPdfFile -Path (Join-Path $folder1 "11-ЧертежДетали_Категория1_Категория2_Деталь2_1998.pdf")
        New-TestPdfFile -Path (Join-Path $folder2 "01-ЧертежДругой_Категория3_Деталь1_1999.pdf")
        New-TestPdfFile -Path (Join-Path $folder2 "11-Чертеж3_Категория3_Категория2_Деталь2_2000.pdf")
    }

    It "Convert-ScannedFIles.ps1 processes input files and creates JSON metadata" {
        # Resolve TestDrive paths to real filesystem paths for the script
        $resolvedSourcePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($script:sourcePath)
        $resolvedResultPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($script:resultPath)

        # Act: Run the actual script
        $scriptPath = Join-Path $PSScriptRoot "../Convert-ScannedFIles.ps1"
        & $scriptPath -SourcePath $resolvedSourcePath -ResultPath $resolvedResultPath

        # Assert: Verify output structure
        # Check transliterated output directories were created
        Test-Path (Join-Path $script:resultPath "testovaya-papka-1") | Should -BeTrue
        Test-Path (Join-Path $script:resultPath "testovaya-papka-2") | Should -BeTrue

        # Check metadata directory was created
        $metadataPath = Join-Path $script:resultPath "metadata"
        Test-Path $metadataPath | Should -BeTrue

        # Check JSON metadata files were created
        Test-Path (Join-Path $metadataPath "testovaya-papka-1.json") | Should -BeTrue
        Test-Path (Join-Path $metadataPath "testovaya-papka-2.json") | Should -BeTrue

        # Verify JSON structure
        $metadata1 = Get-Content (Join-Path $metadataPath "testovaya-papka-1.json") -Raw | ConvertFrom-Json
        $metadata1.DirectoryOriginalName | Should -Be "тестовая папка 1"
        @($metadata1.ProcessedScans.PSObject.Properties).Count | Should -Be 2

        # Verify image files were created (real ImageMagick/Ghostscript processing)
        $dir1 = Join-Path $script:resultPath "testovaya-papka-1"
        @(Get-ChildItem -Path $dir1 -Filter "*.tif").Count | Should -BeGreaterThan 0
        @(Get-ChildItem -Path $dir1 -Filter "*.png").Count | Should -BeGreaterThan 0
    }

    It "ConvertTo-ZolaContent.ps1 converts JSON metadata to Zola markdown files" {
        # Arrange: Metadata should exist from previous test
        $metadataPath = Join-Path $script:resultPath "metadata"

        # Resolve TestDrive paths to real filesystem paths for the script
        $resolvedMetadataPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($metadataPath)
        $resolvedZolaPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($script:zolaPath)

        # Act: Run the actual script
        $scriptPath = Join-Path $PSScriptRoot "../ConvertTo-ZolaContent.ps1"
        & $scriptPath -MetadataPath $resolvedMetadataPath -ZolaContentPath $resolvedZolaPath

        # Assert: Verify Zola content structure
        # Check root index was created
        Test-Path (Join-Path $script:zolaPath "_index.md") | Should -BeTrue

        # Check section directories were created
        Test-Path (Join-Path $script:zolaPath "testovaya-papka-1") | Should -BeTrue
        Test-Path (Join-Path $script:zolaPath "testovaya-papka-2") | Should -BeTrue

        # Check section index files
        Test-Path (Join-Path $script:zolaPath "testovaya-papka-1" "_index.md") | Should -BeTrue
        Test-Path (Join-Path $script:zolaPath "testovaya-papka-2" "_index.md") | Should -BeTrue

        # Check content pages were created
        $contentPages1 = @(Get-ChildItem -Path (Join-Path $script:zolaPath "testovaya-papka-1") -File -Filter "*.md" | Where-Object { $_.Name -ne "_index.md" })
        $contentPages1.Count | Should -BeGreaterThan 0

        # Verify content page structure
        $samplePage = Get-Content $contentPages1[0].FullName -Raw
        $samplePage | Should -Match "title ="
        $samplePage | Should -Match "file_id ="
        $samplePage | Should -Match "\+\+\+"
    }
}
