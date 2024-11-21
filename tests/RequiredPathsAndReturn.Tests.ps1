BeforeAll {
    . $PSScriptRoot/../libs/PathHelper.psm1
}

Describe "Test-RequiredPathsAndReturn" {
    BeforeEach {
        # Setup test directories in Pester's TestDrive
        $testSourcePath = "TestDrive:\source"
        $testResultPath = "TestDrive:\result"
        New-Item -Path $testSourcePath -ItemType Directory -Force
        New-Item -Path $testResultPath -ItemType Directory -Force
    }

    Context "When using relative paths" {
        It "Should convert relative paths to full paths" {
            # Act
            $paths = Test-RequiredPathsAndReturn -SourcePath ".\source" -ResultPath ".\result" -ScriptRoot "TestDrive:"
            
            # Assert
            $paths[0] | Should -Not -BeNullOrEmpty
            $paths[1] | Should -Not -BeNullOrEmpty
            $paths.Count | Should -Be 2
        }
    }

    Context "When paths don't exist" {
        It "Should throw when source path doesn't exist" {
            # Arrange
            Remove-Item -Path $testSourcePath -Force
            
            # Act & Assert
            { Test-RequiredPathsAndReturn -SourcePath $testSourcePath -ResultPath $testResultPath } | 
                Should -Throw "*не найдена!*"
        }

        It "Should throw when result path doesn't exist" {
            # Arrange
            Remove-Item -Path $testResultPath -Force
            
            # Act & Assert
            { Test-RequiredPathsAndReturn -SourcePath $testSourcePath -ResultPath $testResultPath } | 
                Should -Throw "*не найдена!*"
        }
    }

    Context "When both paths exist" {
        It "Should return both paths" {
            # Act
            $paths = Test-RequiredPathsAndReturn -SourcePath $testSourcePath -ResultPath $testResultPath
            
            # Assert
            $paths[0] | Should -Not -BeNullOrEmpty
            $paths[1] | Should -Not -BeNullOrEmpty
        }
    }
}