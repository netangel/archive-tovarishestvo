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
# Run individual test files using Pester
Invoke-Pester ./tests/JsonHelper.Tests.ps1
Invoke-Pester ./tests/PathHelper.Tests.ps1
Invoke-Pester ./tests/ScanFileHelper.Tests.ps1
Invoke-Pester ./tests/RequiredPathsAndReturn.Tests.ps1
Invoke-Pester ./tests/Convert-ToZola.Tests.ps1
Invoke-Pester ./tests/Test-EnvironmentConfiguration.Tests.ps1

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
```powershell
# Initialize metadata from already processed scans (historical data)
./Initialize-MetadataOnProcessedScans.ps1 -DoneScannnedPath "path/to/original/scans" -ArchiveContentPath "path/to/processed/archive" -MetadataPath "path/to/metadata/output"
```

### GitLab Integration
```powershell
# Create merge request for processed results
./Create-MergeRequest.ps1

# Test merge request creation
./Test-CreateMR.ps1
```

## Architecture

### Core Components

**Complete-ArchiveProcess.ps1** - Main orchestration script that:
- Validates required paths and tools
- Manages Git repository synchronization
- Coordinates the entire processing pipeline
- Creates GitLab merge requests for processed results

**Processing Scripts:**
- `Test-EnvironmentConfiguration.ps1` - Validates environment and configuration setup
- `Convert-ScannedFIles.ps1` - Converts PDF/TIFF files to optimized formats
- `ConvertTo-ZolaContent.ps1` - Generates Zola static site content from metadata
- `Sync-MetadataGitRepo.ps1` - Manages Git repository state and branching
- `Submit-MetadataToRemote.ps1` - Commits and pushes metadata changes
- `Initialize-MetadataOnProcessedScans.ps1` - Initializes metadata JSON files from already processed historical data

### Library Modules (libs/)

**Core Libraries:**
- `ZolaContentHelper.psm1` - Zola static site content generation
- `GitHelper.psm1` - Git operations and repository management
- `ScanFileHelper.psm1` - File scanning and metadata extraction
- `JsonHelper.psm1` - JSON processing and validation
- `PathHelper.psm1` - Path resolution and validation (supports UNC network paths)
- `ConvertImage.psm1` - Image conversion and optimization
- `ConvertText.psm1` - Text processing and transliteration
- `ToolsHelper.psm1` - System tool validation and utilities
- `HashHelper.psm1` - MD5 hash generation for file indexing

### Configuration

**config.json** - Main configuration file containing:
- `SourcePath` - Directory with scanned documents
- `ResultPath` - Directory for processed results
- `ZolaContentPath` - Directory for Zola site content
- `GitRepoUrl` - Git repository URL for metadata storage
- `GitServerType` - Git service provider type (`GitLab` or `Gitea`)
- `GitServerUrl` - Git service URL (e.g., `https://gitlab.com`)
- `GitProjectId` - Project ID for merge/pull requests

**Environment Variables:**
- `GITLAB_TOKEN` - Access token for GitLab API (when using GitLab)
- `GITEA_TOKEN` - Access token for Gitea API (when using Gitea)

### Directory Structure

```
/
├── libs/                    # PowerShell modules
├── tests/                   # Unit and integration tests
├── old/                     # Legacy scripts and templates
├── integrations/            # External integrations
├── config.json              # Main configuration
└── *.ps1                    # Main processing scripts
```

## Development Workflow

1. **Setup**: Configure `config.json` with appropriate paths and Git settings
2. **Validation**: Run `./Test-EnvironmentConfiguration.ps1` to verify environment setup
3. **Testing**: Run individual test files with `Invoke-Pester ./tests/[TestName].Tests.ps1`
4. **Processing**: Use `Complete-ArchiveProcess.ps1` for full pipeline execution
5. **Git Integration**: The system automatically creates branches and merge requests

## Dependencies

- PowerShell 7+ (cross-platform support via `Get-CrossPlatformPwsh`)
- Git (for metadata repository management)
- ImageMagick or similar (for image conversion)
- GitLab CLI or API access (for merge request creation)
- Pester (for running tests)

## Script Details

### Initialize-MetadataOnProcessedScans.ps1

This script initializes metadata JSON files based on files that have been already processed (historical data). It's used to create metadata for existing processed archives.

**Parameters:**
- `DoneScannnedPath` - Directory with original scanned files (PDF/TIFF), filenames can be in Russian (un-formatted)
- `ArchiveContentPath` - Directory with results from previous processing containing:
  - Transliterated sub-folder names
  - Transliterated scanned file names
  - Two formats: TIF (original converted) and PNG (browser preview)
  - Thumbnails sub-directory with 400px wide variants
- `MetadataPath` - Output directory for JSON metadata files

**Processing Logic:**
1. **Directory Processing**: For each subdirectory in `DoneScannnedPath`:
   - Checks if transliterated counterpart exists in `ArchiveContentPath` using `ConvertTo-Translit`
   - Creates empty metadata structure similar to `Read-ResultDirectoryMetadata`
   
2. **File Processing**: For each scanned original file:
   - Calculates MD5 hash using `Convert-StringToMD5`
   - Transliterates original filename and checks for TIF file in processed directory
   - Detects single-page vs multi-page scenarios:
     - **Single-page**: Looks for `filename.png`
     - **Multi-page**: Looks for `filename-0.png`, `filename-1.png`, etc.
   - Creates data structure with: `ResultFileName`, `OriginalName`, `PngFile`, `MultiPage`, `Tags`, `Year`, `Thumbnails`
   - For multi-page files: adds `PngFilePages` array with all page filenames, sets `MultiPage: true`, uses first page as main `PngFile`
   - Uses original scan filename for tags and year extraction
   - Adds processed scan data to directory metadata using original file hash as key
   
3. **Output**: Saves directory metadata as `<transliterated-name>.json` in `MetadataPath`

## Important Notes

- All file paths are resolved through `PathHelper.psm1` functions (supports Windows UNC network paths)
- The system uses MD5 hashing for file indexing
- The system uses transliteration for filename normalization
- Git operations are handled through custom `GitHelper.psm1` wrapper
- Metadata is stored in JSON format and versioned through Git
- The system generates timestamped branches for each processing run
