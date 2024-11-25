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