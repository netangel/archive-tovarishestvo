BeforeAll {
    Import-Module $PSScriptRoot/../libs/JsonHelper.psm1 -Force
}

Describe "Read-DirectoryToJson" {
    BeforeEach {
        $testDir = "TestDrive:\testdir"
        $resultPath = "TestDrive:\result"
        New-Item -Path $testDir -ItemType Directory -Force
        New-Item -Path $resultPath -ItemType Directory -Force
    }

    It "Creates new index when json doesn't exist" {
        # Act
        $result = Read-DirectoryToJson -DirName "testdir" -ResultPath $resultPath -SourceDirName "original"

        # Assert
        $result.Directory | Should -Be "testdir"
        $result.OriginalName | Should -Be "original"
        $result.Files | Should -BeOfType [PSCustomObject]
    }
    
    It "Creates new index for cyrilic directory name when json doesn't exist" {
        # Act
        $result = Read-DirectoryToJson -DirName "original" -ResultPath $resultPath -SourceDirName "оригинал"

        # Assert
        $result.Directory | Should -Be "original"
        $result.OriginalName | Should -Be "оригинал"
        $result.Files | Should -BeOfType [PSCustomObject]
    }

    It "Reads existing json file" {
        # Arrange
        $jsonPath = Join-Path (Join-Path $resultPath "testdir") "testdir.json"
        $expected = @{
            Directory = "testdir"
            OriginalName = "original"
            Description = "test"
            Files = @{}
        } | ConvertTo-Json
        New-Item -Path (Split-Path $jsonPath) -ItemType Directory -Force
        Set-Content -Path $jsonPath -Value $expected

        # Act
        $result = Read-DirectoryToJson -DirName "testdir" -ResultPath $resultPath

        # Assert
        $result.Directory | Should -Be "testdir"
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
            $_.Files | Should -Not -BeNullOrEmpty
        }
    }

    It "Handles errors gracefully" {
        # Arrange
        Mock Get-DirectoryOrCreate { throw "Access denied" }

        # Act & Assert
        { "invalid" | Get-SubDirectoryIndex -ResultPath $resultPath } | 
            Should -Throw "Failed to process directory*"
    }
}