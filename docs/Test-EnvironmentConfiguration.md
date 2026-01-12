# Test-EnvironmentConfiguration.ps1

## Overview

`Test-EnvironmentConfiguration.ps1` is a comprehensive validation script that checks your environment and configuration before running the archive processing system. It verifies paths, tools, Git repository setup, and Git service connectivity.

## Purpose

This script helps you:
- Verify that all required paths exist and are correctly configured
- Check that required tools (ImageMagick, Ghostscript, Git) are installed
- Validate Git repository setup in the metadata directory
- Confirm Git service (GitLab/Gitea) configuration
- Test API connectivity and token permissions

## Usage

### Basic Usage

Run the script without parameters to validate the current configuration:

```powershell
./Test-EnvironmentConfiguration.ps1
```

This will:
1. Read paths from `config.json`
2. Validate all configurations
3. Test Git service API connectivity
4. Display a detailed report

### With Parameters

Provide paths as parameters to validate and update `config.json`:

```powershell
./Test-EnvironmentConfiguration.ps1 `
    -SourcePath "\\pomor_schooner\drawings\done" `
    -ResultPath "\\pomor_schooner\drawings\public\archive" `
    -MetadataPath "\\pomor_schooner\drawings\public\archive\metadata"
```

If the paths are valid and different from `config.json`, the configuration file will be updated.

### Skip API Checks

Run validation without testing Git service API connectivity (useful for offline validation):

```powershell
./Test-EnvironmentConfiguration.ps1 -SkipGitServiceCheck
```

## What Gets Validated

### 1. Configuration Loading
- ✅ `config.json` exists and is valid JSON
- ✅ Configuration can be parsed successfully

### 2. Path Validation
- ✅ `SourcePath` exists (directory with scanned documents)
- ✅ `ResultPath` exists (directory for processed results)
- ✅ `MetadataPath` exists (directory with metadata)
- ✅ `MetadataPath` ends with `/metadata` or `\metadata`
- ✅ Paths are absolute (full paths or UNC network paths)

### 3. Required Tools
- ✅ ImageMagick is installed and available in PATH
- ✅ Ghostscript is installed and available in PATH
- ✅ Git is installed and available in PATH

### 4. Git Repository Configuration
- ✅ `GitRepoUrl` is defined in `config.json`
- ✅ Git repository is initialized in `MetadataPath`
- ✅ Git remote origin matches `GitRepoUrl` in config

### 5. Git Service Configuration
- ✅ `GitServerType` is defined and valid (`GitLab` or `Gitea`)
- ✅ `GitServerUrl` is defined (e.g., `https://gitlab.com`)
- ✅ `GitProjectId` is defined

### 6. Git Service Access Token
- ✅ Environment variable is set:
  - `GITLAB_TOKEN` for GitLab
  - `GITEA_TOKEN` for Gitea

### 7. Git Service API Connectivity (unless `-SkipGitServiceCheck`)
- ✅ Can connect to Git service API
- ✅ Token has valid permissions
- ✅ Can query merge/pull requests
- ⚠️ Warns if open merge/pull requests exist

## Exit Codes

| Code | Meaning |
|------|---------|
| 0    | All checks passed (or passed with warnings) |
| 1    | One or more checks failed |

## Sample Output

```
═══════════════════════════════════════════════════════
  Configuration Loading
═══════════════════════════════════════════════════════
✅ config.json loaded successfully

═══════════════════════════════════════════════════════
  Path Validation
═══════════════════════════════════════════════════════
✅ SourcePath exists: \\pomor_schooner\drawings\done
✅ ResultPath exists: \\pomor_schooner\drawings\public\archive
✅ MetadataPath exists: \\pomor_schooner\drawings\public\archive\metadata
✅ MetadataPath correctly ends with 'metadata'

═══════════════════════════════════════════════════════
  Required Tools Check
═══════════════════════════════════════════════════════
✅ ImageMagick is installed
✅ Ghostscript is installed
✅ Git is installed

═══════════════════════════════════════════════════════
  Git Repository Configuration
═══════════════════════════════════════════════════════
✅ GitRepoUrl is defined: git@gitlab.com:solombala-archive/metadata.git
✅ Git repository exists in MetadataPath
✅ Git remote origin matches config: git@gitlab.com:solombala-archive/metadata.git

═══════════════════════════════════════════════════════
  Git Service Configuration
═══════════════════════════════════════════════════════
✅ GitServerType is set to: GitLab
✅ GitServerUrl is set to: https://gitlab.com
✅ GitProjectId is set to: 69777976

═══════════════════════════════════════════════════════
  Git Service Access Token
═══════════════════════════════════════════════════════
✅ Environment variable GITLAB_TOKEN is set (glpa****)

═══════════════════════════════════════════════════════
  Git Service API Connectivity
═══════════════════════════════════════════════════════
Testing API connectivity to GitLab...
✅ Successfully connected to GitLab API
✅ No open merge/pull requests found
✅ Token has valid permissions for reading merge/pull requests

═══════════════════════════════════════════════════════
  Validation Summary
═══════════════════════════════════════════════════════

Results:
  ✅ Passed:   15
  ⚠️  Warnings: 0
  ❌ Failed:   0

✅ Environment validation PASSED
   All checks completed successfully. The system is ready to use!
```

## Common Issues and Solutions

### Issue: "MetadataPath should end with 'metadata'"

**Solution:** Ensure your metadata directory ends with the correct suffix:
```powershell
# Correct
-MetadataPath "\\server\path\archive\metadata"

# Incorrect
-MetadataPath "\\server\path\archive\meta"
```

### Issue: "Git remote origin mismatch"

**Solution:** Update your Git remote origin:
```powershell
cd $MetadataPath
git remote set-url origin git@gitlab.com:your-org/metadata.git
```

### Issue: "Environment variable GITLAB_TOKEN is not set"

**Solution:** Set the appropriate environment variable:
```powershell
# For GitLab
$env:GITLAB_TOKEN = "your-gitlab-token"

# For Gitea
$env:GITEA_TOKEN = "your-gitea-token"
```

To make it persistent, add it to your PowerShell profile or system environment variables.

### Issue: "ImageMagick is not installed"

**Solution:** Install ImageMagick:
```powershell
# Using Chocolatey
choco install imagemagick -y

# Or download from: https://imagemagick.org/script/download.php
```

### Issue: "Failed to query GitLab/Gitea API"

**Possible causes:**
1. Invalid access token
2. Incorrect project ID
3. Token lacks required permissions
4. Network connectivity issues
5. Wrong Git service URL

**Solution:**
1. Verify your token has API access permissions
2. Check the project ID is correct
3. Ensure the GitServerUrl is correct
4. Test network connectivity to the Git service

## Integration with Complete-ArchiveProcess.ps1

The validation logic in this script was extracted from `Complete-ArchiveProcess.ps1`. You can run this script independently to verify your setup before running the full archive processing pipeline.

## Running Tests

To test the validation script:

```powershell
Invoke-Pester ./tests/Test-EnvironmentConfiguration.Tests.ps1
```

## Parameters Reference

### -SourcePath
- **Type:** String
- **Required:** No
- **Description:** Directory with scanned documents (PDF/TIFF files)
- **Default:** Value from `config.json`

### -ResultPath
- **Type:** String
- **Required:** No
- **Description:** Directory for processed results
- **Default:** Value from `config.json`

### -MetadataPath
- **Type:** String
- **Required:** No
- **Description:** Directory with metadata (should end with 'metadata')
- **Default:** Value from `config.json`

### -SkipGitServiceCheck
- **Type:** Switch
- **Required:** No
- **Description:** Skip Git service API connectivity checks
- **Default:** False (API checks are performed)

## Best Practices

1. **Run Before Processing:** Always run this script before executing `Complete-ArchiveProcess.ps1` to catch configuration issues early.

2. **Workstation Validation:** Run this on new workstations to verify the environment is properly set up.

3. **After Configuration Changes:** Re-run after modifying `config.json` or changing Git service settings.

4. **CI/CD Integration:** Include this script in your CI/CD pipeline to validate the environment before automated processing.

5. **Offline Validation:** Use `-SkipGitServiceCheck` when validating in environments without internet access.

## See Also

- `Complete-ArchiveProcess.ps1` - Main archive processing script
- `CLAUDE.md` - Project documentation
- `config.json` - Configuration file
