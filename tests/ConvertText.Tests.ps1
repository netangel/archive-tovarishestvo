BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../libs/ConvertText.psm1") -Force
}

Describe "ConvertTo-Translit Function Tests" {
    
    Context "Standard Cyrillic Characters" {
        It "Should transliterate standard Cyrillic text correctly" {
            $result = ConvertTo-Translit "Привет мир"
            $result | Should -Be "Privetmir"
        }
        
        It "Should transliterate standard й to y" {
            $result = ConvertTo-Translit "Сельдяной Карбас"
            $result | Should -Be "SeldyanoyKarbas"
        }
        
        It "Should transliterate standard й to y" {
            $result = ConvertTo-Translit "Новый год"
            $result | Should -Be "Novyygod"
        }
    }
    
    Context "Combined Character Cases" {
        It "Should normalize и + combining breve (U+0306) to standard й" {
            # Create test string with и + combining breve
            $testString = "Сельдяно" + [char]0x0438 + [char]0x0306 + " Карбас"
            $result = ConvertTo-Translit $testString
            $result | Should -Be "SeldyanoyKarbas"
        }
        
        It "Should normalize И + combining breve (U+0306) to standard Й" {
            # Create test string with upper case И + combining breve  
            $testString = [char]0x0418 + [char]0x0306 + "ван"
            $result = ConvertTo-Translit $testString
            $result | Should -Be "Yvan"
        }
        
        It "Should normalize е + combining diaeresis (U+0308) to standard ё" {
            # Create test string with е + combining diaeresis
            $testString = "Новы" + [char]0x0435 + [char]0x0308 + " год"
            $result = ConvertTo-Translit $testString
            $result | Should -Be "Novyegod"
        }
        
        It "Should normalize Е + combining diaeresis (U+0308) to standard Ё" {
            # Create test string with upper case Е + combining diaeresis
            $testString = [char]0x0415 + [char]0x0308 + "лка"
            $result = ConvertTo-Translit $testString
            $result | Should -Be "Elka"
        }
    }
    
    Context "Mixed Cases" {
        It "Should handle mixed standard and combined characters" {
            # Mix of standard й and combined и+breve
            $testString = "Стандартный" + " " + "комбини" + [char]0x0438 + [char]0x0306 + "рованный"
            $result = ConvertTo-Translit $testString
            $result | Should -Be "Standartnyykombiniyrovannyy"
        }
        
        It "Should handle text with no combining characters unchanged" {
            $testString = "Обычный текст"
            $result = ConvertTo-Translit $testString
            $result | Should -Be "Obychnyytekst"
        }
    }
    
    Context "Real World Examples" {
        It "Should handle the problematic directory name correctly" {
            # This is the actual case from the migration script
            $problemCase = "Сельдяной Карбас"
            $result = ConvertTo-Translit $problemCase
            $result | Should -Be "SeldyanoyKarbas"
        }
        
        It "Should handle multiple similar cases" {
            $testCases = @(
                @{ Input = "Морской флот"; Expected = "Morskoyflot" }
                @{ Input = "Новый проект"; Expected = "Novyyproekt" }
                @{ Input = "Речной транспорт"; Expected = "Rechnoytransport" }
            )
            
            foreach ($case in $testCases) {
                $result = ConvertTo-Translit $case.Input
                $result | Should -Be $case.Expected
            }
        }
    }
    
    Context "Edge Cases" {
        It "Should handle empty string" {
            $result = ConvertTo-Translit ""
            $result | Should -Be ""
        }
        
        It "Should handle string with only spaces" {
            $result = ConvertTo-Translit "   "
            $result | Should -Be ""
        }
        
        It "Should handle string with only combining characters" {
            $testString = [char]0x0306 + [char]0x0308
            $result = ConvertTo-Translit $testString
            $result | Should -Be ""
        }
        
        It "Should remove non-ASCII characters after transliteration" {
            $testString = "Test" + [char]0x2603 + "снеговик"  # Unicode snowman + Russian
            $result = ConvertTo-Translit $testString
            $result | Should -Be "Testsnegovik"
        }
    }
    
    Context "Character Verification" {
        It "Should produce expected character mappings for combined characters" {
            # Verify that и+breve becomes standard й
            $combined = [char]0x0438 + [char]0x0306  # и + combining breve
            $standard = [char]0x0439  # standard й
            
            $combinedResult = ConvertTo-Translit $combined
            $standardResult = ConvertTo-Translit $standard
            
            $combinedResult | Should -Be $standardResult
            $combinedResult | Should -Be "y"
        }
        
        It "Should produce expected character mappings for diaeresis cases" {
            # Verify that е+diaeresis becomes standard ё  
            $combined = [char]0x0435 + [char]0x0308  # е + combining diaeresis
            $standard = [char]0x0451  # standard ё
            
            $combinedResult = ConvertTo-Translit $combined
            $standardResult = ConvertTo-Translit $standard
            
            $combinedResult | Should -Be $standardResult
            $combinedResult | Should -Be "e"
        }
    }
}