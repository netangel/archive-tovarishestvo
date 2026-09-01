BeforeAll {
    Import-Module $PSScriptRoot/../libs/GitHelper.psm1 -Force
}

Describe 'Invoke-GitOperation error handling' {
    BeforeAll {
        # Mock Write-Host in the GitHelper module to suppress console output during tests
        Mock Write-Host -ModuleName GitHelper {}
    }

    Context 'When the underlying git command fails' {
        BeforeEach {
            Mock Invoke-GitCommand -ModuleName GitHelper {
                return @{
                    ExitCode = 128
                    StdOut   = ""
                    StdErr   = "fatal: not a git repository"
                    Success  = $false
                }
            }
        }

        It 'Throws rather than terminating the runspace' {
            { Add-AllNewFiles } | Should -Throw
        }

        It 'Includes the operation name, exit code and stderr in the message' {
            { Add-AllNewFiles } | Should -Throw -ExpectedMessage "*add **exit 128*fatal: not a git repository*"
        }
    }

    Context 'When the underlying git command succeeds' {
        BeforeEach {
            Mock Invoke-GitCommand -ModuleName GitHelper {
                return @{
                    ExitCode = 0
                    StdOut   = ""
                    StdErr   = ""
                    Success  = $true
                }
            }
        }

        It 'Does not throw' {
            { Add-AllNewFiles } | Should -Not -Throw
        }
    }
}
