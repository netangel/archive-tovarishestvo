BeforeAll {
    Import-Module $PSScriptRoot/../libs/PathHelper.psm1
}

Describe 'File name => tags' {
    It 'Just words tags' {
        Get-TagsFromName 'Tag_Tag' | Should -Be @('Tag', 'Tag')
    }

    It 'Number + word tags' {
        Get-TagsFromName '1000_Tag' | Should -Be @('Tag')
    }

    It 'Two words tag' {
        Get-TagsFromName 'TwoWords_Tag' | Should -Be @('Two Words', 'Tag') 
    }
    
    It 'Multi words with number' {
        Get-TagsFromName '020_Канифас_Блок_СтальнойТрос_Диам9,5_Детали_СудовоеУстройство' 
            | Should -Be @(
                'Канифас',
                'Блок',
                'Стальной Трос',
                'Диам 9,5',
                'Детали',
                'Судовое Устройство'
            )
    }

    It 'Triple words tag' {
        Get-TagsFromName '001_БотДляМурмана' | Should -Be @('Бот Для Мурмана') 
    }
    
    It 'Digits and words tag' {
        Get-TagsFromName '90Тонн' | Should -Be @('90 Тонн') 
    }
    
    It 'Many digits and words tag' {
        Get-TagsFromName '1000И1Ночь' | Should -Be @('1000 и 1Ночь') 
    }
    
    It 'Should handle № as part of document number' {
        Get-TagsFromName 'Чертеж№123_Деталь' | Should -Be @('Чертеж №123', 'Деталь')
    }
    
    It 'Should handle # as part of document number' {
        Get-TagsFromName 'Plan#456_Section' | Should -Be @('Plan #456', 'Section')
    }
    
    It 'Should handle № with complex word' {
        Get-TagsFromName 'ТехническийДокумент№789_Раздел' | Should -Be @('Технический Документ №789', 'Раздел')
    }
    
    It 'Should split on # when not followed by number' {
        Get-TagsFromName 'Test#Symbol_Another' | Should -Be @('Test', 'Symbol', 'Another')
    }
    
    It 'Should split on № when not followed by number' {
        Get-TagsFromName 'Test№Symbol_Another' | Should -Be @('Test', 'Symbol', 'Another')
    }
    
    It 'Should handle parentheses as separators' {
        Get-TagsFromName 'Test(Symbol)_Another' | Should -Be @('Test', 'Symbol', 'Another')
    }
    
    It 'Should handle brackets as separators' {
        Get-TagsFromName 'Test[Symbol]_Another{Item}' | Should -Be @('Test', 'Symbol', 'Another', 'Item')
    }
    
    It 'Should handle multiple numbered items' {
        Get-TagsFromName 'Чертеж№123_План#456_Схема' | Should -Be @('Чертеж №123', 'План #456', 'Схема')
    }
}


Describe 'File name => year(s)' {
    It 'Single year' {
        Get-YearFromFilename '3999_ЧтоТоТам_ВНазвании_1966' | Should -Be '1966' 
    }
    
    It 'Period with _' {
        Get-YearFromFilename '3999_ЧтоТоТам_ВНазвании_1966_1965' | Should -Be '1966-1965' 
    }
    
    It 'Period with -' {
        Get-YearFromFilename '3999_ЧтоТоТам_ВНазвании_1966-1965' | Should -Be '1966-1965' 
    }

    It 'null' {
        Get-YearFromFilename '3999_ЧтоТоТам_ВНазвании_БезГода' | Should -Be $null 
    }
}

Describe 'File name => Thumbnail file name' {
    BeforeAll {
        $RootDir = Join-Path "Testdrive:" "test"
    }

    It 'File name with path' {
        Get-ThumbnailFileName (Join-Path $RootDir "filename.tif") 500 
            | Should -Be (Join-Path (Join-Path $RootDir "thumbnails" ) "filename_500.png")
    }
    
    It 'Just file name' {
        Get-ThumbnailFileName 'filename.tif' 500 
            | Should -Be (Join-Path "thumbnails" "filename_500.png")
    }
    
    It 'File name with path' {
        Get-ThumbnailFileName (Join-Path $RootDir "filename.png") 500 
            | Should -Be (Join-Path (Join-Path $RootDir "thumbnails" ) "filename_500.png")
    }
    
    It 'Just file name' {
        Get-ThumbnailFileName 'filename.png' 500 
            | Should -Be (Join-Path "thumbnails" "filename_500.png")
    }
}

Describe 'Test-IsFullPath - Network Path Support' {
    BeforeAll {
        Import-Module $PSScriptRoot/../libs/PathHelper.psm1 -Force
    }
    
    Context 'Windows UNC Paths' {
        BeforeAll {
            # Mock Get-IsWindowsPlatform to return true for Windows tests
            Mock Get-IsWindowsPlatform { return $true } -ModuleName PathHelper
        }
        
        It 'Should recognize UNC server-share path' {
            $Path = '\\server\share'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $true
        }
        
        It 'Should recognize UNC server-share path with trailing backslash' {
            $Path = '\\server\share\'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $true
        }
        
        It 'Should recognize UNC path with subdirectories' {
            $Path = '\\server\share\folder\subfolder'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $true
        }
        
        It 'Should recognize UNC path with IP address' {
            $Path = '\\192.168.1.100\share'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $true
        }
        
        It 'Should reject invalid UNC paths' {
            $Path = '\\server'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $false
        }
        
        It 'Should reject single backslash' {
            $Path = '\'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $false
        }
    }
    
    Context 'Regular Windows Paths' {
        BeforeAll {
            # Mock Get-IsWindowsPlatform to return true for Windows tests
            Mock Get-IsWindowsPlatform { return $true } -ModuleName PathHelper
        }
        
        It 'Should still recognize regular drive paths' {
            $Path = 'C:\Windows\System32'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $true
        }
        
        It 'Should still recognize single drive letter paths' {
            $Path = 'D:\'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $true
        }
    }
    
    Context 'Unix Paths' {
        BeforeAll {
            # Mock Get-IsWindowsPlatform to return false for Unix tests
            Mock Get-IsWindowsPlatform { return $false } -ModuleName PathHelper
        }
        
        It 'Should recognize Unix absolute paths' {
            $Path = '/home/user/documents'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $true
        }
        
        It 'Should reject Unix relative paths' {
            $Path = 'home/user/documents'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $false
        }
    }
    
    Context 'TestDrive Paths' {
        It 'Should still recognize TestDrive paths regardless of platform' {
            $Path = 'TestDrive:\test\path'
            $Result = Test-IsFullPath $Path
            $Result | Should -Be $true
        }
    }
}