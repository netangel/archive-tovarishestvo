BeforeAll {
    Import-Module $PSScriptRoot/../libs/ToolsHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/HashHelper.psm1 -Force
}

Describe 'Blake3 Tool Detection and Installation' {
    Context 'Test-Blake3' {
        It 'Should detect b3sum command availability' {
            # Test that Test-Blake3 returns a boolean
            $result = Test-Blake3
            $result | Should -BeOfType [bool]
        }
    }
    
    Context 'Install-Blake3' {
        It 'Should return true when b3sum is already available' {
            # Mock Test-Blake3 to return true
            Mock Test-Blake3 { return $true }
            
            $result = Install-Blake3
            $result | Should -Be $true
        }
    }
}

Describe 'Blake3 Hash Generation' {
    Context 'Get-Blake3Hash' {
        BeforeAll {
            # Create a test file
            $testFile = Join-Path $TestDrive "test-file.txt"
            "Test content for Blake3 hashing" | Out-File -FilePath $testFile -Encoding utf8
        }
        
        It 'Should throw error for non-existent file' {
            $nonExistentFile = Join-Path $TestDrive "non-existent.txt"
            { Get-Blake3Hash -FilePath $nonExistentFile } | Should -Throw "*не найден*"
        }
        
        It 'Should handle files with spaces in filename' {
            # Create a test file with spaces in the name
            $testFileWithSpaces = Join-Path $TestDrive "test file with spaces.txt"
            "Test content for Blake3 hashing with spaces" | Out-File -FilePath $testFileWithSpaces -Encoding utf8
            
            # Should not throw an error and should return a hash
            $result = Get-Blake3Hash -FilePath $testFileWithSpaces
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match '^[A-F0-9]{64}$'
        }
        
    }
}

Describe 'Blake3 Availability Check' {
    Context 'Ensure-Blake3Available' {
        It 'Should succeed when b3sum is available' {
            # Mock Test-Blake3 to return true
            Mock Test-Blake3 { return $true }
            
            $result = Ensure-Blake3Available
            $result | Should -Be $true
        }
        
    }
}