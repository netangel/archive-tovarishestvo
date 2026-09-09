# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a PowerShell-based archive processing system for the Solombala shipyard archive project. It processes scanned documents (PDF/TIFF files), converts them to web-friendly formats, manages metadata through Git, and generates content for a Zola-based static site.

## Key Commands

### Environment Validation
```powershell
# Validate environment and configuration before processing
./Test-EnvironmentConfiguration.ps1

# Validate with custom paths (will update config.json)
./Test-EnvironmentConfiguration.ps1 -SourcePath "path/to/source" -ResultPath "path/to/results" -MetadataPath "path/to/metadata"

# Validate without API connectivity checks (offline mode)
./Test-EnvironmentConfiguration.ps1 -SkipGitServiceCheck
```

**Validation Script**: `Test-EnvironmentConfiguration.ps1` validates your environment before running the archive processing system:
- Checks path existence and correctness (SourcePath, ResultPath, MetadataPath)
- Validates MetadataPath ends with 'metadata' directory
- Verifies required tools are installed (ImageMagick, Ghostscript, Git)
- Checks Git repository in MetadataPath with correct remote origin
- Validates Git service configuration (GitServerType, GitServerUrl, GitProjectId)
- Checks environment variables for tokens (GITLAB_TOKEN or GITEA_TOKEN)
- Tests Git service API connectivity and token permissions
- See [docs/Test-EnvironmentConfiguration.md](docs/Test-EnvironmentConfiguration.md) for details

### Running Tests
```powershell
# Run a single test file
Invoke-Pester ./tests/<TestName>.Tests.ps1

# Run end-to-end tests (requires ImageMagick and Ghostscript)
Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1

# Run all tests
Invoke-Pester ./tests/
```

**E2E Tests**: `E2E-ImageProcessing.Tests.ps1` provides comprehensive end-to-end testing of the complete workflow from scanned documents to Zola site generation. These tests:
- Use **real ImageMagick and Ghostscript** (no mocking)
- Test the full pipeline: PDF/TIFF → image processing → metadata → Zola content
- Validate Russian filename handling and transliteration
- Create test files dynamically using Pester's TestDrive
- Require ImageMagick and Ghostscript to be installed

### Main Processing Pipeline
```powershell
# Complete archive processing workflow
./Complete-ArchiveProcess.ps1

# Individual processing steps
./Convert-ScannedFIles.ps1 -SourcePath "path/to/source" -ResultPath "path/to/results"
./ConvertTo-ZolaContent.ps1 -MetadataPath "path/to/metadata" -ZolaContentPath "path/to/content"
./Sync-MetadataGitRepo.ps1 -GitDirectory "path/to/git" -UpstreamUrl "git@gitlab.com:solombala-archive/metadata.git" -BranchName "branch-name"
```

### Historical Data Processing

One-time import of metadata for already-processed historical archives (not part of the everyday pipeline) — see the `initialize-historical-metadata` skill.

## Configuration

**Environment Variables:**
- `GITLAB_TOKEN` - Access token for GitLab API (when using GitLab)
- `GITEA_TOKEN` - Access token for Gitea API (when using Gitea)

## Development Workflow

1. **Setup**: Configure `config.json` with appropriate paths and Git settings
2. **Validation**: Run `./Test-EnvironmentConfiguration.ps1` to verify environment setup
3. **Testing**: Run individual test files with `Invoke-Pester ./tests/[TestName].Tests.ps1`
4. **Processing**: Use `Complete-ArchiveProcess.ps1` for full pipeline execution
5. **Git Integration**: The system automatically creates branches and merge requests

## Important Notes

- All file paths are resolved through `PathHelper.psm1` functions (supports Windows UNC network paths)
- The system uses MD5 hashing for file indexing
- The system uses transliteration for filename normalization
- Git operations are handled through custom `GitHelper.psm1` wrapper
- Metadata is stored in JSON format and versioned through Git
- The system generates timestamped branches for each processing run
