BeforeAll {
    Import-Module $PSScriptRoot/../libs/JsonHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/PathHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/ConvertText.psm1 -Force
}

Describe "Read-DirectoryToJson" {
    BeforeEach {
        $testDir = "TestDrive:\testdir"
        $resultPath = "TestDrive:\result"
        $metadataPath = Join-Path $resultPath $MetadataDir
        New-Item -Path $testDir -ItemType Directory -Force
        New-Item -Path $resultPath -ItemType Directory -Force
        New-Item -Path $metadataPath -ItemType Directory -Force
    }

    It "Creates new index when json doesn't exist" {
        # Act
        $result = Read-ResultDirectoryMetadata -DirName "testdir" -ResultPath $resultPath -SourceDirName "original"

        # Assert
        $result.Directory | Should -Be "testdir"
        $result.OriginalName | Should -Be "original"
        $result.Files | Should -BeOfType [PSCustomObject]
    }
    
    It "Creates new index for cyrilic directory name when json doesn't exist" {
        # Act
        $result = Read-ResultDirectoryMetadata -DirName "original" -ResultPath $resultPath -SourceDirName "оригинал"

        # Assert
        $result.Directory | Should -Be "original"
        $result.OriginalName | Should -Be "оригинал"
        $result.Files | Should -BeOfType [PSCustomObject]
    }

    It "Reads existing json file" {
        # Arrange
        $jsonPath = Join-Path $metadataPath "testdir.json"
        $expected = @{
            Directory = "testdir"
            OriginalName = "original"
            Description = "test"
            Files = @{}
        } | ConvertTo-Json
        Set-Content -Path $jsonPath -Value $expected

        # Act
        $result = Read-ResultDirectoryMetadata -DirName "testdir" -ResultPath $resultPath

        # Assert
        $result.Directory | Should -Be "testdir"
        $result.OriginalName | Should -Be "original"
        $result.Description | Should -Be "test"
    }
}

Describe "Get-SubDirectoryIndex" {
    BeforeEach {
        $resultPath = "TestDrive:\result"
        New-Item -Path $resultPath -ItemType Directory -Force
    }

    It "Processes pipeline input" {
        # Arrange
        $dirs = @("dir1", "dir2")

        # Act & Assert
        $dirs | Get-SubDirectoryIndex -ResultPath $resultPath | ForEach-Object {
            $_.Directory | Should -BeIn $dirs
            $_.Files | Should -BeOfType [PSCustomObject]

            # Check thumbnail directory created
            $expectedThumbnailPath = Join-Path (Join-Path $resultPath $_.Directory) ( Get-ThumbnailDir )

            # Assert
            Test-Path $expectedThumbnailPath | Should -BeTrue
        }
    }
}