BeforeAll {
    Import-Module $PSScriptRoot/../libs/GitHelper.psm1 -Force
    Import-Module $PSScriptRoot/../libs/GitServerProvider.psm1 -Force
}

Describe 'Test-OpenMergeRequests Function Tests' {
    BeforeAll {
        # Mock Write-Host in the GitHelper module to suppress console output during tests
        Mock Write-Host -ModuleName GitServerProvider {}

        # Default GitLab server URL and project ID
        $script:gitServerUrl = "https://gitlab.com"
        $script:projectId = "12345"
        $script:accessToken = "test-token"

        # Create a GitServerProvider instance for GitLab
        $script:gitServiceProvider = New-GitServerProvider -ProviderType "GitLab" `
            -ServerUrl $script:gitServerUrl `
            -ProjectId $script:projectId `
            -AccessToken $script:accessToken `
            -Verbose:$false
    }

    Context 'When no open merge requests exist' {
        It 'Should return false when API returns empty array' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider {
                return @()
            }

            # Act
            $result = Test-OpenMergeRequests -Provider $script:gitServiceProvider

            # Assert
            $result | Should -Be $false

            # Verify the API was called with correct parameters
            Should -Invoke Invoke-RestMethod -ModuleName GitServerProvider -Exactly 1 -ParameterFilter {
                $Uri -eq "https://gitlab.com/api/v4/projects/12345/merge_requests?state=opened" -and
                $Method -eq "Get" -and
                $Headers["PRIVATE-TOKEN"] -eq "test-token"
            }
        }
    }

    Context 'When open merge requests exist' {
        It 'Should return true when API returns one open MR' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider {
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
            $result = Test-OpenMergeRequests -Provider $script:gitServiceProvider

            # Assert
            $result | Should -Be $true
        }

        It 'Should return true when API returns multiple open MRs' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider {
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
            $result = Test-OpenMergeRequests -Provider $script:gitServiceProvider

            # Assert
            $result | Should -Be $true
        }

        It 'Should display details of all open MRs' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider {
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
            Test-OpenMergeRequests -Provider $script:gitServiceProvider

            # Assert
            Should -Invoke Write-Host -ModuleName GitServerProvider -ParameterFilter {
                $Object -match "MR !42: Test MR"
            }
            Should -Invoke Write-Host -ModuleName GitServerProvider -ParameterFilter {
                $Object -match "feature -> main"
            }
        }
    }

    Context 'When API call fails' {
        It 'Should return false and not throw when API returns error' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider {
                throw "API Error: Unauthorized"
            }

            # Act
            $result = Test-OpenMergeRequests -Provider $script:gitServiceProvider

            # Assert
            $result | Should -Be $false

            # Should display warning message
            Should -Invoke Write-Host -ModuleName GitServerProvider -ParameterFilter {
                $Object -match "Не удалось проверить открытые merge запросы"
            }
        }

        It 'Should handle network timeout gracefully' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider {
                throw [System.Net.WebException]::new("The operation has timed out")
            }

            # Act & Assert - should not throw
            { Test-OpenMergeRequests -Provider $script:gitServiceProvider } | Should -Not -Throw
        }

        It 'Should handle 404 error gracefully' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider {
                $exception = New-Object System.Exception("404 Not Found")
                throw $exception
            }

            # Act
            $result = Test-OpenMergeRequests -Provider $script:gitServiceProvider

            # Assert
            $result | Should -Be $false
        }
    }

    Context 'Request headers and authentication' {
        It 'Should include correct authentication header' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider { return @() }

            # Act
            Test-OpenMergeRequests -Provider $script:gitServiceProvider

            # Assert
            Should -Invoke Invoke-RestMethod -ModuleName GitServerProvider -ParameterFilter {
                $Headers["PRIVATE-TOKEN"] -eq $script:accessToken
            }
        }

        It 'Should include Content-Type header' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider { return @() }

            # Act
            Test-OpenMergeRequests -Provider $script:gitServiceProvider

            # Assert
            Should -Invoke Invoke-RestMethod -ModuleName GitServerProvider -ParameterFilter {
                $Headers["Content-Type"] -eq "application/json"
            }
        }
    }

    Context 'Query parameter validation' {
        It 'Should query only for opened state merge requests' {
            # Arrange
            Mock Invoke-RestMethod -ModuleName GitServerProvider { return @() }

            # Act
            Test-OpenMergeRequests -Provider $script:gitServiceProvider

            # Assert
            Should -Invoke Invoke-RestMethod -ModuleName GitServerProvider -ParameterFilter {
                $Uri -match "state=opened"
            }
        }
    }

    Context 'TestConnection' {
        Context 'GitLab provider' {
            It 'Throws when the API call fails' {
                # Arrange
                Mock Invoke-RestMethod -ModuleName GitServerProvider {
                    throw "API Error: Unauthorized"
                }

                # Act & Assert - unlike TestOpenMergeRequests, this must throw
                { $script:gitServiceProvider.TestConnection() } | Should -Throw
            }

            It 'Does not throw when the API call succeeds' {
                # Arrange
                Mock Invoke-RestMethod -ModuleName GitServerProvider { return @() }

                # Act & Assert
                { $script:gitServiceProvider.TestConnection() } | Should -Not -Throw
            }

            It 'Calls the open merge requests endpoint with the auth header' {
                # Pins the same endpoint/header TestOpenMergeRequests uses, so the two
                # cannot silently drift apart.
                Mock Invoke-RestMethod -ModuleName GitServerProvider { return @() }

                $script:gitServiceProvider.TestConnection()

                Should -Invoke Invoke-RestMethod -ModuleName GitServerProvider -Exactly 1 -ParameterFilter {
                    $Uri -eq "https://gitlab.com/api/v4/projects/12345/merge_requests?state=opened" -and
                    $Headers["PRIVATE-TOKEN"] -eq "test-token"
                }
            }
        }

        Context 'Gitea provider' {
            BeforeAll {
                $script:giteaServiceProvider = New-GitServerProvider -ProviderType "Gitea" `
                    -ServerUrl "https://gitea.example.com" `
                    -ProjectId "owner/repo" `
                    -AccessToken "test-token" `
                    -Verbose:$false
            }

            It 'Throws when the API call fails' {
                # Arrange
                Mock Invoke-RestMethod -ModuleName GitServerProvider {
                    throw "API Error: Unauthorized"
                }

                # Act & Assert
                { $script:giteaServiceProvider.TestConnection() } | Should -Throw
            }

            It 'Does not throw when the API call succeeds' {
                # Arrange
                Mock Invoke-RestMethod -ModuleName GitServerProvider { return @() }

                # Act & Assert
                { $script:giteaServiceProvider.TestConnection() } | Should -Not -Throw
            }

            It 'Calls the open pull requests endpoint with the auth header' {
                Mock Invoke-RestMethod -ModuleName GitServerProvider { return @() }

                $script:giteaServiceProvider.TestConnection()

                Should -Invoke Invoke-RestMethod -ModuleName GitServerProvider -Exactly 1 -ParameterFilter {
                    $Uri -eq "https://gitea.example.com/api/v1/repos/owner/repo/pulls?state=open" -and
                    $Headers["Authorization"] -eq "token test-token"
                }
            }
        }
    }

    Context 'SubmitMergeRequest error reporting' {
        It 'Displays the response body from ErrorDetails.Message when the GitLab API call fails' {
            # Arrange - throwing the ErrorRecord itself (rather than a plain string)
            # preserves ErrorDetails through to the catch block's $_.
            Mock Invoke-RestMethod -ModuleName GitServerProvider {
                $exception = [System.Exception]::new("Bad Request")
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $exception, "TestError", [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
                $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"message":"branch already exists"}')
                throw $errorRecord
            }

            # Act & Assert
            { $script:gitServiceProvider.SubmitMergeRequest("feature", "main", "Title", "Desc", $true) } | Should -Throw

            Should -Invoke Write-Host -ModuleName GitServerProvider -ParameterFilter {
                $Object -match "Details:.*branch already exists"
            }
        }
    }
}
