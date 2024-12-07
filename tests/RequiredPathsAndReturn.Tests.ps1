BeforeAll {
    Import-Module $PSScriptRoot/../libs/PathHelper.psm1
}

Describe "Test-RequiredPathsAndReturn" {
    BeforeEach {
        # Setup test directories in Pester's TestDrive
        $testSourcePath = Join-Path "TestDrive:" "source"
        $testResultPath = Join-Path "TestDrive:" "result"
        New-Item -Path $testSourcePath -ItemType Directory -Force
        New-Item -Path $testResultPath -ItemType Directory -Force
    }

    Context "When using relative paths" {
        It "Should convert relative paths to full paths" {
            # Act
            $SourcePath = Test-RequiredPathsAndReturn -SourcePath ".\source" -ScriptRoot "TestDrive:"
            $ResultPath = Test-RequiredPathsAndReturn -SourcePath ".\result" -ScriptRoot "TestDrive:"

            
            # Assert
            $SourcePath | Should -Not -BeNullOrEmpty
            $ResultPath | Should -Not -BeNullOrEmpty
        }
    }

    Context "When paths don't exist" {
        It "Should throw when source path doesn't exist" {
            # Arrange
            Remove-Item -Path $testSourcePath -Force
            
            # Act & Assert
            { Test-RequiredPathsAndReturn -SourcePath $testSourcePath } | 
                Should -Throw "*не найдена!*"
        }

        It "Should throw when result path doesn't exist" {
            # Arrange
            Remove-Item -Path $testResultPath -Force
            
            # Act & Assert
            { Test-RequiredPathsAndReturn -SourcePath $testResultPath } | 
                Should -Throw "*не найдена!*"
        }
    }

    Context "When both paths exist" {
        It "Should return both paths" {
            # Act
            $SourcePath = Test-RequiredPathsAndReturn -SourcePath $testSourcePath
            $ResultPath = Test-RequiredPathsAndReturn -SourcePath $testResultPath 

            
            # Assert
            $SourcePath | Should -Not -BeNullOrEmpty
            $ResultPath | Should -Not -BeNullOrEmpty
        }
    }
}