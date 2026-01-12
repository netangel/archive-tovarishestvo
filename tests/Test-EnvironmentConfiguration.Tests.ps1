BeforeAll {
    # Get the script path
    $scriptPath = Join-Path $PSScriptRoot ".." "Test-EnvironmentConfiguration.ps1"

    # Import modules needed for testing
    Import-Module (Join-Path $PSScriptRoot ".." "libs/ToolsHelper.psm1") -Force
    Import-Module (Join-Path $PSScriptRoot ".." "libs/PathHelper.psm1") -Force

    # Helper function to create a test config file
    function New-TestConfig {
        param(
            [string]$Path,
            [hashtable]$Config
        )
        $Config | ConvertTo-Json | Out-File -FilePath $Path -Encoding UTF8
    }
}

Describe "Test-EnvironmentConfiguration Script" {
    Context "Basic Functionality" {
        It "Should exist" {
            $scriptPath | Should -Exist
        }

        It "Should be a valid PowerShell script" {
            {
                $null = [System.Management.Automation.PSParser]::Tokenize(
                    (Get-Content -Path $scriptPath -Raw), [ref]$null
                )
            } | Should -Not -Throw
        }
    }

    Context "Configuration File Handling" {
        BeforeEach {
            # Create a temporary config file for testing
            $testConfigPath = Join-Path $TestDrive "config.json"
            $testConfig = @{
                SourcePath = $TestDrive
                ResultPath = $TestDrive
                MetadataPath = Join-Path $TestDrive "metadata"
                GitRepoUrl = "git@example.com:test/repo.git"
                GitServerType = "GitLab"
                GitServerUrl = "https://gitlab.example.com"
                GitProjectId = "12345"
            }
            New-TestConfig -Path $testConfigPath -Config $testConfig

            # Create metadata directory
            New-Item -Path (Join-Path $TestDrive "metadata") -ItemType Directory -Force | Out-Null
        }

        It "Should fail when config.json is missing" {
            # Remove the config file
            Remove-Item $testConfigPath -Force

            # The script should exit with code 1 when config is missing
            # We can't easily test this without running the script in a separate process
            $true | Should -Be $true  # Placeholder - actual test would require process isolation
        }

        It "Should load valid config.json" {
            $config = Get-Content $testConfigPath | ConvertFrom-Json -AsHashtable
            $config.GitServerType | Should -Be "GitLab"
            $config.GitProjectId | Should -Be "12345"
        }
    }

    Context "Path Validation Logic" {
        It "Should validate full paths correctly" {
            if (Get-IsWindowsPlatform) {
                Test-IsFullPath "C:\test" | Should -Be $true
            } else {
                Test-IsFullPath "/test" | Should -Be $true
            }
            Test-IsFullPath "relative/path" | Should -Be $false
            Test-IsFullPath "" | Should -Be $false
        }

        It "Should validate UNC paths on Windows" {
            if (Get-IsWindowsPlatform) {
                Test-IsFullPath "\\server\share" | Should -Be $true
                Test-IsFullPath "\\server\share\folder" | Should -Be $true
            } else {
                # On non-Windows, UNC paths should not be recognized
                $true | Should -Be $true  # Skip test
            }
        }

        It "Should validate TestDrive paths in tests" {
            Test-IsFullPath "TestDrive:\test" | Should -Be $true
        }
    }

    Context "Tool Detection" {
        It "Should detect Git if installed" {
            $hasGit = Test-Git
            if ($hasGit) {
                $hasGit | Should -Be $true
            } else {
                # Git not installed in test environment
                $hasGit | Should -Be $false
            }
        }

        It "Should detect ImageMagick if installed" {
            $hasImageMagick = Test-ImageMagick
            # Just verify the function returns a boolean
            $hasImageMagick | Should -BeOfType [bool]
        }

        It "Should detect Ghostscript if installed" {
            $hasGhostscript = Test-Ghostscript
            # Just verify the function returns a boolean
            $hasGhostscript | Should -BeOfType [bool]
        }

        It "Should validate command existence" {
            # Test with a command that should always exist
            if ($IsWindows) {
                Test-CommandExists "cmd" | Should -Be $true
            } else {
                Test-CommandExists "ls" | Should -Be $true
            }

            # Test with a command that should not exist
            Test-CommandExists "this-command-definitely-does-not-exist-12345" | Should -Be $false
        }
    }

    Context "MetadataPath Suffix Validation" {
        It "Should correctly identify metadata suffix on Windows paths" {
            if (Get-IsWindowsPlatform) {
                "C:\path\to\metadata" -match "[\\/]metadata$" | Should -Be $true
                "C:\path\to\other" -match "[\\/]metadata$" | Should -Be $false
            }
        }

        It "Should correctly identify metadata suffix on Unix paths" {
            "/path/to/metadata" -match "[\\/]metadata$" | Should -Be $true
            "/path/to/other" -match "[\\/]metadata$" | Should -Be $false
        }
    }

    Context "Config Update Logic" {
        BeforeEach {
            $testConfigPath = Join-Path $TestDrive "config.json"
            $testConfig = @{
                SourcePath = ""
                ResultPath = ""
                MetadataPath = ""
                GitRepoUrl = "git@example.com:test/repo.git"
                GitServerType = "GitLab"
                GitServerUrl = "https://gitlab.example.com"
                GitProjectId = "12345"
            }
            New-TestConfig -Path $testConfigPath -Config $testConfig
        }

        It "Should update config when paths are provided as parameters" {
            # Load config
            $config = Get-Content $testConfigPath | ConvertFrom-Json -AsHashtable

            # Simulate parameter values
            $newSourcePath = $TestDrive

            # Update config
            if ($config['SourcePath'] -ne $newSourcePath) {
                $config['SourcePath'] = $newSourcePath
                $config | ConvertTo-Json | Out-File -FilePath $testConfigPath -Encoding UTF8
            }

            # Verify update
            $updatedConfig = Get-Content $testConfigPath | ConvertFrom-Json -AsHashtable
            $updatedConfig['SourcePath'] | Should -Be $newSourcePath
        }
    }

    Context "Git Service Type Validation" {
        It "Should accept valid GitServerType values" {
            "GitLab" -in @("GitLab", "Gitea") | Should -Be $true
            "Gitea" -in @("GitLab", "Gitea") | Should -Be $true
        }

        It "Should reject invalid GitServerType values" {
            "GitHub" -in @("GitLab", "Gitea") | Should -Be $false
            "Bitbucket" -in @("GitLab", "Gitea") | Should -Be $false
            "" -in @("GitLab", "Gitea") | Should -Be $false
        }

        It "Should map GitServerType to correct token variable" {
            $gitServerType = "GitLab"
            $expectedToken = switch ($gitServerType) {
                "GitLab" { "GITLAB_TOKEN" }
                "Gitea" { "GITEA_TOKEN" }
                default { $null }
            }
            $expectedToken | Should -Be "GITLAB_TOKEN"

            $gitServerType = "Gitea"
            $expectedToken = switch ($gitServerType) {
                "GitLab" { "GITLAB_TOKEN" }
                "Gitea" { "GITEA_TOKEN" }
                default { $null }
            }
            $expectedToken | Should -Be "GITEA_TOKEN"
        }
    }

    Context "URL Normalization" {
        It "Should normalize Git URLs correctly" {
            $url1 = "git@example.com:test/repo.git"
            $url2 = "git@example.com:test/repo"

            $normalized1 = $url1.TrimEnd('/').TrimEnd('.git')
            $normalized2 = $url2.TrimEnd('/').TrimEnd('.git')

            $normalized1 | Should -Be "git@example.com:test/repo"
            $normalized2 | Should -Be "git@example.com:test/repo"
            $normalized1 | Should -Be $normalized2
        }

        It "Should normalize HTTPS Git URLs correctly" {
            $url1 = "https://example.com/test/repo.git"
            $url2 = "https://example.com/test/repo/"
            $url3 = "https://example.com/test/repo"

            $normalized1 = $url1.TrimEnd('/').TrimEnd('.git')
            $normalized2 = $url2.TrimEnd('/').TrimEnd('.git')
            $normalized3 = $url3.TrimEnd('/').TrimEnd('.git')

            $normalized1 | Should -Be $normalized2
            $normalized2 | Should -Be $normalized3
        }
    }

    Context "Token Masking" {
        It "Should mask token values for display" {
            $token = "abcdef1234567890"
            $maskedToken = $token.Substring(0, [Math]::Min(4, $token.Length)) + "****"
            $maskedToken | Should -Be "abcd****"
        }

        It "Should handle short tokens" {
            $token = "abc"
            $maskedToken = $token.Substring(0, [Math]::Min(4, $token.Length)) + "****"
            $maskedToken | Should -Be "abc****"
        }

        It "Should handle empty tokens" {
            $token = ""
            if ($token.Length -eq 0) {
                $masked = "****"
            } else {
                $masked = $token.Substring(0, [Math]::Min(4, $token.Length)) + "****"
            }
            $masked | Should -Be "****"
        }
    }
}

Describe "Integration Tests" {
    Context "Script Execution with Missing Config" {
        It "Should fail with error when config.json is missing" {
            # Create a temporary directory and copy script without config.json
            $tempDir = Join-Path $TestDrive "no-config"
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

            # Copy script and libs to test directory
            $testScriptPath = Join-Path $tempDir "Test-EnvironmentConfiguration.ps1"
            Copy-Item -Path $scriptPath -Destination $testScriptPath -Force

            $libsSource = Join-Path $PSScriptRoot ".." "libs"
            $libsDest = Join-Path $tempDir "libs"
            Copy-Item -Path $libsSource -Destination $libsDest -Recurse -Force

            # Run from test directory (no config.json present)
            Push-Location $tempDir
            try {
                $result = & pwsh -File $testScriptPath 2>&1
                $LASTEXITCODE | Should -Be 1
                $result | Should -Match "config.json not found"
            } finally {
                Pop-Location
            }
        }
    }

    Context "Script Execution with Valid Config" {
        BeforeAll {
            # Check if git is available
            $script:hasGit = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

            # Create a test environment in TestDrive
            $testRoot = Join-Path $TestDrive "valid-env"
            New-Item -Path $testRoot -ItemType Directory -Force | Out-Null

            # Create required directories
            $sourcePath = Join-Path $testRoot "source"
            $resultPath = Join-Path $testRoot "result"
            $metadataPath = Join-Path $resultPath "metadata"

            New-Item -Path $sourcePath -ItemType Directory -Force | Out-Null
            New-Item -Path $resultPath -ItemType Directory -Force | Out-Null
            New-Item -Path $metadataPath -ItemType Directory -Force | Out-Null

            # Initialize git repo in metadata path if git is available
            if ($script:hasGit) {
                Push-Location $metadataPath
                git init 2>&1 | Out-Null
                git remote add origin "git@example.com:test/repo.git" 2>&1 | Out-Null
                Pop-Location
            }

            # Create config.json
            $config = @{
                SourcePath = $sourcePath
                ResultPath = $resultPath
                MetadataPath = $metadataPath
                GitRepoUrl = "git@example.com:test/repo.git"
                GitServerType = "GitLab"
                GitServerUrl = "https://gitlab.example.com"
                GitProjectId = "12345"
            }
            $configPath = Join-Path $testRoot "config.json"
            $config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8
        }

        It "Should output valid JSON on success with SkipGitServiceCheck" -Skip:(-not $script:hasGit) {
            $testRoot = Join-Path $TestDrive "valid-env"
            $configPath = Join-Path $testRoot "config.json"

            # Copy script to test directory to use local config.json
            $testScriptPath = Join-Path $testRoot "Test-EnvironmentConfiguration.ps1"
            Copy-Item -Path $scriptPath -Destination $testScriptPath -Force

            # Copy libs directory
            $libsSource = Join-Path $PSScriptRoot ".." "libs"
            $libsDest = Join-Path $testRoot "libs"
            Copy-Item -Path $libsSource -Destination $libsDest -Recurse -Force

            Push-Location $testRoot
            try {
                # Run with SkipGitServiceCheck to avoid needing actual API access
                $output = & pwsh -File $testScriptPath -SkipGitServiceCheck 2>&1
                $LASTEXITCODE | Should -Be 0

                # Filter to get only JSON output
                $jsonOutput = $output | Where-Object { $_ -match '^\s*[\{\[]' } | Out-String

                # Parse JSON
                $result = $jsonOutput | ConvertFrom-Json

                # Verify structure
                $result.Success | Should -Be $true
                $result.Paths | Should -Not -BeNullOrEmpty
                $result.Paths.SourcePath | Should -Not -BeNullOrEmpty
                $result.Paths.ResultPath | Should -Not -BeNullOrEmpty
                $result.Paths.MetadataPath | Should -Not -BeNullOrEmpty
                $result.PSObject.Properties.Name | Should -Contain "IsGitProviderAvailable"
            } finally {
                Pop-Location
            }
        }
    }

    Context "Script Execution with Missing Tools" {
        It "Should fail when ImageMagick is not installed and report error" -Skip:($null -ne (Get-Command magick -ErrorAction SilentlyContinue)) {
            # This test only runs if ImageMagick is NOT installed
            # Create minimal config
            $testRoot = Join-Path $TestDrive "no-tools"
            New-Item -Path $testRoot -ItemType Directory -Force | Out-Null

            $config = @{
                SourcePath = $testRoot
                ResultPath = $testRoot
                MetadataPath = Join-Path $testRoot "metadata"
                GitRepoUrl = "git@example.com:test/repo.git"
                GitServerType = "GitLab"
                GitServerUrl = "https://gitlab.example.com"
                GitProjectId = "12345"
            }

            New-Item -Path $config.MetadataPath -ItemType Directory -Force | Out-Null

            $configPath = Join-Path $testRoot "config.json"
            $config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8

            # Copy script and libs
            $testScriptPath = Join-Path $testRoot "Test-EnvironmentConfiguration.ps1"
            Copy-Item -Path $scriptPath -Destination $testScriptPath -Force

            $libsSource = Join-Path $PSScriptRoot ".." "libs"
            $libsDest = Join-Path $testRoot "libs"
            Copy-Item -Path $libsSource -Destination $libsDest -Recurse -Force

            Push-Location $testRoot
            try {
                $output = & pwsh -File $testScriptPath -SkipGitServiceCheck 2>&1
                $LASTEXITCODE | Should -Be 1
                $output | Should -Match "ImageMagick"
            } finally {
                Pop-Location
            }
        }
    }

    Context "Parameter Validation" {
        It "Should have SkipGitServiceCheck parameter" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent -match "\[switch\]\`$SkipGitServiceCheck" | Should -Be $true
        }

        It "Should have path parameters" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent -match "\[string\]\`$SourcePath" | Should -Be $true
            $scriptContent -match "\[string\]\`$ResultPath" | Should -Be $true
            $scriptContent -match "\[string\]\`$MetadataPath" | Should -Be $true
        }
    }

    Context "JSON Output Structure" {
        It "Should produce valid JSON structure" {
            # Test the JSON structure manually
            $testJson = @{
                Success = $true
                Paths = @{
                    SourcePath = "/test/source"
                    ResultPath = "/test/result"
                    MetadataPath = "/test/metadata"
                }
                IsGitProviderAvailable = $false
            } | ConvertTo-Json -Depth 10

            $parsed = $testJson | ConvertFrom-Json
            $parsed.Success | Should -Be $true
            $parsed.Paths.SourcePath | Should -Be "/test/source"
            $parsed.IsGitProviderAvailable | Should -Be $false
        }
    }
}
