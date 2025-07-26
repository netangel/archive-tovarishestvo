Import-Module (Join-Path $PSScriptRoot "../libs/HashHelper.psm1") -Force

Describe 'Convert-StringToMD5 Function Tests' {
    
    Context 'Basic MD5 Hash Generation' {
        It 'Should generate MD5 hash for simple string' {
            $testString = "hello world"
            $result = Convert-StringToMD5 -StringToHash $testString
            
            # MD5 hash should be 32 characters long
            $result.Length | Should -Be 32
            # Should be uppercase hexadecimal
            $result | Should -Match '^[A-F0-9]{32}$'
            # Known MD5 for "hello world" is 5EB63BBBE01EEED093CB22BB8F5ACDC3
            $result | Should -Be "5EB63BBBE01EEED093CB22BB8F5ACDC3"
        }
        
        It 'Should generate consistent hash for same input' {
            $testString = "test consistency"
            $result1 = Convert-StringToMD5 -StringToHash $testString
            $result2 = Convert-StringToMD5 -StringToHash $testString
            
            $result1 | Should -Be $result2
        }
        
        It 'Should generate different hashes for different inputs' {
            $string1 = "first string"
            $string2 = "second string"
            $hash1 = Convert-StringToMD5 -StringToHash $string1
            $hash2 = Convert-StringToMD5 -StringToHash $string2
            
            $hash1 | Should -Not -Be $hash2
        }
    }
    
    Context 'Edge Cases and Special Characters' {
        It 'Should throw error for empty string' {
            { Convert-StringToMD5 -StringToHash "" } | Should -Throw
        }
        
        It 'Should handle single character' {
            $result = Convert-StringToMD5 -StringToHash "a"
            
            $result.Length | Should -Be 32
            $result | Should -Match '^[A-F0-9]{32}$'
            # Known MD5 for "a" is 0CC175B9C0F1B6A831C399E269772661
            $result | Should -Be "0CC175B9C0F1B6A831C399E269772661"
        }
        
        It 'Should handle Unicode characters' {
            $unicodeString = "тест русский текст"
            $result = Convert-StringToMD5 -StringToHash $unicodeString
            
            $result.Length | Should -Be 32
            $result | Should -Match '^[A-F0-9]{32}$'
        }
        
        It 'Should handle special characters and symbols' {
            $specialString = '!@#$%^&*()_+-=[]{}|;''",./<>?'
            $result = Convert-StringToMD5 -StringToHash $specialString
            
            $result.Length | Should -Be 32
            $result | Should -Match '^[A-F0-9]{32}$'
        }
        
        It 'Should handle newlines and whitespace' {
            $multilineString = "line1`nline2`r`nline3"
            $result = Convert-StringToMD5 -StringToHash $multilineString
            
            $result.Length | Should -Be 32
            $result | Should -Match '^[A-F0-9]{32}$'
        }
        
        It 'Should handle very long strings' {
            $longString = "a" * 10000
            $result = Convert-StringToMD5 -StringToHash $longString
            
            $result.Length | Should -Be 32
            $result | Should -Match '^[A-F0-9]{32}$'
        }
    }
    
    Context 'Archive Processing Use Cases' {
        It 'Should handle directory and file path format' {
            $testString = "Directory:Folder1,File:document.pdf"
            $result = Convert-StringToMD5 -StringToHash $testString
            
            $result.Length | Should -Be 32
            $result | Should -Match '^[A-F0-9]{32}$'
        }
        
        It 'Should handle Russian directory and file names' {
            $testString = "Directory:Папка документов,File:скан001.pdf"
            $result = Convert-StringToMD5 -StringToHash $testString
            
            $result.Length | Should -Be 32
            $result | Should -Match '^[A-F0-9]{32}$'
        }
        
        It 'Should generate different hashes for different directories with same file' {
            $string1 = "Directory:Folder1,File:document.pdf"
            $string2 = "Directory:Folder2,File:document.pdf"
            $hash1 = Convert-StringToMD5 -StringToHash $string1
            $hash2 = Convert-StringToMD5 -StringToHash $string2
            
            $hash1 | Should -Not -Be $hash2
        }
        
        It 'Should generate different hashes for same directory with different files' {
            $string1 = "Directory:Folder1,File:document1.pdf"
            $string2 = "Directory:Folder1,File:document2.pdf"
            $hash1 = Convert-StringToMD5 -StringToHash $string1
            $hash2 = Convert-StringToMD5 -StringToHash $string2
            
            $hash1 | Should -Not -Be $hash2
        }
    }
    
    Context 'Parameter Validation' {
        It 'Should throw error for null input' {
            { Convert-StringToMD5 -StringToHash $null } | Should -Throw
        }
        
        It 'Should require StringToHash parameter' {
            { Convert-StringToMD5 } | Should -Throw
        }
    }
    
    Context 'Resource Management' {
        It 'Should properly dispose of memory streams' {
            # Test that multiple calls don't cause memory issues
            1..100 | ForEach-Object {
                $result = Convert-StringToMD5 -StringToHash "test string $($_)"
                $result.Length | Should -Be 32
            }
        }
    }
}