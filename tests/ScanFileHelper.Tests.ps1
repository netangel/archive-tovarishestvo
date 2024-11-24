BeforeAll {
    Import-Module $PSScriptRoot/../libs/ScanFileHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/PathHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/ConvertText.psm1 -Force
    Import-Module $PSScriptRoot/../libs/ConvertImage.psm1 -Force

    Mock -ModuleName ScanFileHelper Convert-WebPngOrRename {
        param($InputFileName)

        $pngFile = $InputFileName.Replace('.tif', '.png')
        Set-Content -Path $pngFile -Value "mock png content"
        return (Split-Path $pngFile -Leaf)
    } -Verifiable

    Mock -ModuleName ScanFileHelper Convert-PdfToTiff { 
        param($InputPdfFile, $OutputTiffFileName)

        Set-Content -Path $OutputTiffFileName -Value "mock tiff content"
    }

    Mock -ModuleName ScanFileHelper Optimize-Tiff { }

    Mock -ModuleName ScanFileHelper New-Thumbnail { 
        param($InputFileName, $Pixels)

        $thumbnailFile = Get-ThumbnailFileName $InputFileName $Pixels
        Set-Content -Path $thumbnailFile -Value "mock thumbnail content"
        return (Split-Path $thumbnailFile -Leaf)
    }
}

Describe "Convert-FileAndCreateData" {
    BeforeEach {
        # Папка с оригиналами
        $sourcePath = "TestDrive:\source"
        New-Item -Path $sourcePath -ItemType Directory -Force

        # Create test files
        New-Item -Path (Join-Path $sourcePath "оригинал.pdf") -ItemType File -Force
        New-Item -Path (Join-Path $sourcePath "оригинал2.tif") -ItemType File -Force
        New-Item -Path (Join-Path $sourcePath "оригинал3.pdf") -ItemType File -Force

        $resultPath = "TestDrive:\result"
        New-Item -Path $resultPath -ItemType Directory -Force
        New-Item -Path "$resultPath\thumbnails" -ItemType Directory -Force
    }

    It "Returns existing data when file already processed" {
        # Arrange
        $sourceFile = Get-Item -Path "TestDrive:\source\оригинал.pdf"
        $existingData = [PSCustomObject]@{
            OriginalName    = "оригинал.pdf"
            ResultFileName  = "original.tif"
        }

        # Act
        $result = Convert-FileAndCreateData -SourceFile $sourceFile -MaybeFileData $existingData -ResultDirFullPath $resultPath

        # Assert
        $result | Should -Be $existingData
    }

    It "Creates new file data for unprocessed pdf file" {
        # Arrange
        $sourceFile = Get-Item -Path "TestDrive:\source\оригинал.pdf"

        # Act
        $result = Convert-FileAndCreateData -SourceFile $sourceFile -ResultDirFullPath $resultPath

        # Assert
        $result.OriginalName    | Should -Be "оригинал.pdf"
        $result.ResultFileName  | Should -Be "original.tif"
        $result.PngFile         | Should -Be "original.png"

        Should -Invoke -ModuleName ScanFileHelper Convert-PdfToTiff -Times 1 -Exactly
        Should -Invoke -ModuleName ScanFileHelper Convert-WebPngOrRename -Times 1 -Exactly
    }

    It "Creates new file data for unprocessed tif file" {
        # Arrange
        $sourceFile = Get-Item -Path "TestDrive:\source\оригинал2.tif"

        # Act
        $result = Convert-FileAndCreateData -SourceFile $sourceFile -ResultDirFullPath $resultPath

        # Assert
        $result.OriginalName    | Should -Be "оригинал2.tif"
        $result.ResultFileName  | Should -Be "original2.tif"
        $result.PngFile         | Should -Be "original2.png"

        Should -Invoke -ModuleName ScanFileHelper Optimize-Tiff -Times 1 -Exactly
        Should -Invoke -ModuleName ScanFileHelper Convert-WebPngOrRename -Times 1 -Exactly
    }


    It "Renames files when metadata exists but filename changed" {
        # Arrange
        $sourceFile = Get-Item -Path "TestDrive:\source\оригинал3.pdf"
        
        $existingData = [PSCustomObject]@{
            OriginalName    = "old-оригинал3.pdf"
            ResultFileName  = "old-original3.tif"
            PngFile         = "old-original3.png"
        }
        
        # Create test files
        $oldTiff        = Join-Path $resultPath "old-original3.tif"
        $oldPng         = Join-Path $resultPath "old-original3.png"
        $oldThumbnail   = Get-ThumbnailFileName $oldTiff 400
        Set-Content -Path $oldTiff -Value "test"
        Set-Content -Path $oldPng -Value "test"
        Set-Content -Path $oldThumbnail -Value "test"

        # Act
        $result = Convert-FileAndCreateData -SourceFile $sourceFile -MaybeFileData $existingData -ResultDirFullPath $resultPath

        # Assert
        Test-Path (Join-Path $resultPath "original3.tif") | Should -BeTrue
        Test-Path (Join-Path $resultPath "original3.png") | Should -BeTrue
        Test-Path $oldTiff | Should -BeFalse
        Test-Path $oldPng  | Should -BeFalse
        Test-Path $oldThumbnail  | Should -BeFalse
        $result.OriginalName    | Should -Be "оригинал3.pdf"
        $result.ResultFileName  | Should -Be "original3.tif"
        $result.PngFile         | Should -Be "original3.png"
        $result.Thumbnails."400" | Should -Be "original3_400.png"
    }
}