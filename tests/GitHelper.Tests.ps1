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

Describe 'Push-GitCommit' {
    BeforeAll {
        Mock Write-Host -ModuleName GitHelper {}
    }

    Context 'When the working tree has no changes to commit' {
        BeforeAll {
            $script:repoPath = Join-Path $TestDrive "no-changes-repo"
            New-Item -Path $script:repoPath -ItemType Directory -Force | Out-Null

            Push-Location $script:repoPath
            try {
                git init --quiet | Out-Null
                git config user.email "test@example.com" | Out-Null
                git config user.name "Test" | Out-Null
                "content" | Set-Content -Path (Join-Path $script:repoPath "file.txt")
                git add . | Out-Null
                git commit -m "initial" --quiet | Out-Null
            } finally {
                Pop-Location
            }
        }

        BeforeEach {
            Push-Location $script:repoPath
            Mock Invoke-GitOperation -ModuleName GitHelper {}
        }

        AfterEach {
            Pop-Location
        }

        It 'Returns the no-change sentinel' {
            $result = Push-GitCommit -BranchName "test-branch"
            $result | Should -Be "NoChanges"
        }

        It 'Invokes no commit or push' {
            Push-GitCommit -BranchName "test-branch" | Out-Null
            Should -Invoke Invoke-GitOperation -ModuleName GitHelper -Exactly 0
        }
    }
}

Describe 'ConvertTo-NormalizedGitUrl' {
    Context 'Equivalent URL pairs normalize to the same value' {
        $equivalentPairs = @(
            @{ First = "git@git.dwal.in:solombala-archive/metadata"; Second = "ssh://git@git.dwal.in:22022/solombala-archive/metadata.git" }
            @{ First = "https://gitlab.com/group/project.git"; Second = "https://gitlab.com/group/project" }
            @{ First = "https://gitlab.com/group/project/"; Second = "https://gitlab.com/group/project" }
            @{ First = "https://GitLab.com/group/project"; Second = "https://gitlab.com/group/project" }
            @{ First = "git@github.com:org/repo.git"; Second = "ssh://git@github.com/org/repo" }
        )

        It 'Normalizes <First> the same as <Second>' -TestCases $equivalentPairs {
            param($First, $Second)
            ConvertTo-NormalizedGitUrl $First | Should -Be (ConvertTo-NormalizedGitUrl $Second)
        }
    }

    Context 'Digit regression - character-set trim bug' {
        It 'Does not truncate a path ending in "digit" down to "d" (TrimEnd is a char-set trim, not a suffix trim)' {
            ConvertTo-NormalizedGitUrl "https://example.com/repo/digit" | Should -Be "https://example.com/repo/digit"
        }
    }
}
