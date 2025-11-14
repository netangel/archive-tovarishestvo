BeforeAll {
    Import-Module $PSScriptRoot/../libs/GitHelper.psm1 -Force
}

Describe 'Test-OpenMergeRequests Function Tests' {
    BeforeEach {
        # Mock Write-Host to suppress console output during tests
        Mock Write-Host {}
    }

    Context 'When no open merge requests exist' {
        It 'Should return false when API returns empty array' {
            # Arrange
            Mock Invoke-RestMethod {
                return @()
            }

            # Act
            $result = Test-OpenMergeRequests -ProjectId "12345" -AccessToken "test-token"

            # Assert
            $result | Should -Be $false

            # Verify the API was called with correct parameters
            Should -Invoke Invoke-RestMethod -Exactly 1 -ParameterFilter {
                $Uri -eq "https://gitlab.com/api/v4/projects/12345/merge_requests?state=opened" -and
                $Method -eq "Get" -and
                $Headers["PRIVATE-TOKEN"] -eq "test-token"
            }
        }
    }

    Context 'When open merge requests exist' {
        It 'Should return true when API returns one open MR' {
            # Arrange
            Mock Invoke-RestMethod {
                return @(
                    @{
                        iid = 42
                        title = "Test Merge Request"
                        source_branch = "feature-branch"
                        target_branch = "main"
                        web_url = "https://gitlab.com/project/merge_requests/42"
                    }
                )
            }

            # Act
            $result = Test-OpenMergeRequests -ProjectId "12345" -AccessToken "test-token"

            # Assert
            $result | Should -Be $true
        }

        It 'Should return true when API returns multiple open MRs' {
            # Arrange
            Mock Invoke-RestMethod {
                return @(
                    @{
                        iid = 42
                        title = "First MR"
                        source_branch = "feature-1"
                        target_branch = "main"
                        web_url = "https://gitlab.com/project/merge_requests/42"
                    },
                    @{
                        iid = 43
                        title = "Second MR"
                        source_branch = "feature-2"
                        target_branch = "main"
                        web_url = "https://gitlab.com/project/merge_requests/43"
                    }
                )
            }

            # Act
            $result = Test-OpenMergeRequests -ProjectId "12345" -AccessToken "test-token"

            # Assert
            $result | Should -Be $true
        }

        It 'Should display details of all open MRs' {
            # Arrange
            Mock Invoke-RestMethod {
                return @(
                    @{
                        iid = 42
                        title = "Test MR"
                        source_branch = "feature"
                        target_branch = "main"
                        web_url = "https://gitlab.com/project/merge_requests/42"
                    }
                )
            }

            # Act
            $result = Test-OpenMergeRequests -ProjectId "12345" -AccessToken "test-token"

            # Assert
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "MR !42: Test MR"
            }
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "feature -> main"
            }
        }
    }

    Context 'When using custom GitLab URL' {
        It 'Should use custom GitLab URL when provided' {
            # Arrange
            Mock Invoke-RestMethod { return @() }
            $customUrl = "https://gitlab.example.com"

            # Act
            Test-OpenMergeRequests -GitLabUrl $customUrl -ProjectId "12345" -AccessToken "test-token"

            # Assert
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq "$customUrl/api/v4/projects/12345/merge_requests?state=opened"
            }
        }

        It 'Should use default GitLab URL when not provided' {
            # Arrange
            Mock Invoke-RestMethod { return @() }

            # Act
            Test-OpenMergeRequests -ProjectId "12345" -AccessToken "test-token"

            # Assert
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq "https://gitlab.com/api/v4/projects/12345/merge_requests?state=opened"
            }
        }
    }

    Context 'When API call fails' {
        It 'Should return false and not throw when API returns error' {
            # Arrange
            Mock Invoke-RestMethod {
                throw "API Error: Unauthorized"
            }

            # Act
            $result = Test-OpenMergeRequests -ProjectId "12345" -AccessToken "invalid-token"

            # Assert
            $result | Should -Be $false

            # Should display warning message
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Не удалось проверить открытые merge запросы"
            }
        }

        It 'Should handle network timeout gracefully' {
            # Arrange
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("The operation has timed out")
            }

            # Act & Assert - should not throw
            { Test-OpenMergeRequests -ProjectId "12345" -AccessToken "test-token" } | Should -Not -Throw
        }

        It 'Should handle 404 error gracefully' {
            # Arrange
            Mock Invoke-RestMethod {
                $exception = New-Object System.Exception("404 Not Found")
                throw $exception
            }

            # Act
            $result = Test-OpenMergeRequests -ProjectId "99999" -AccessToken "test-token"

            # Assert
            $result | Should -Be $false
        }
    }

    Context 'Request headers and authentication' {
        It 'Should include correct authentication header' {
            # Arrange
            Mock Invoke-RestMethod { return @() }
            $testToken = "secret-token-12345"

            # Act
            Test-OpenMergeRequests -ProjectId "12345" -AccessToken $testToken

            # Assert
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Headers["PRIVATE-TOKEN"] -eq $testToken
            }
        }

        It 'Should include Content-Type header' {
            # Arrange
            Mock Invoke-RestMethod { return @() }

            # Act
            Test-OpenMergeRequests -ProjectId "12345" -AccessToken "test-token"

            # Assert
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Headers["Content-Type"] -eq "application/json"
            }
        }
    }

    Context 'Query parameter validation' {
        It 'Should query only for opened state merge requests' {
            # Arrange
            Mock Invoke-RestMethod { return @() }

            # Act
            Test-OpenMergeRequests -ProjectId "12345" -AccessToken "test-token"

            # Assert
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -match "state=opened"
            }
        }
    }
}
