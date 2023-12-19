BeforeAll {
    Import-Module $PSScriptRoot/../tools/PathHelper.psm1
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
}
