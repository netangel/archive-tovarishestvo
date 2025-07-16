# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a PowerShell-based archive processing system for the Solombala shipyard archive project. It processes scanned documents (PDF/TIFF files), converts them to web-friendly formats, manages metadata through Git, and generates content for a Zola-based static site.

## Key Commands

### Running Tests
```powershell
# Run individual test files using Pester
Invoke-Pester ./tests/JsonHelper.Tests.ps1
Invoke-Pester ./tests/PathHelper.Tests.ps1
Invoke-Pester ./tests/ScanFileHelper.Tests.ps1
Invoke-Pester ./tests/RequiredPathsAndReturn.Tests.ps1
Invoke-Pester ./tests/Convert-ToZola.Tests.ps1

# Run all tests
Invoke-Pester ./tests/
```

### Main Processing Pipeline
```powershell
# Complete archive processing workflow
./Complete-ArchiveProcess.ps1

# Individual processing steps
./Convert-ScannedFIles.ps1 -SourcePath "path/to/source" -ResultPath "path/to/results"
./ConvertTo-ZolaContent.ps1 -MetadataPath "path/to/metadata" -ZolaContentPath "path/to/content"
./Sync-MetadataGitRepo.ps1 -GitDirectory "path/to/git" -UpstreamUrl "git@gitlab.com:solombala-archive/metadata.git" -BranchName "branch-name"
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
- `Convert-ScannedFIles.ps1` - Converts PDF/TIFF files to optimized formats
- `ConvertTo-ZolaContent.ps1` - Generates Zola static site content from metadata
- `Sync-MetadataGitRepo.ps1` - Manages Git repository state and branching
- `Submit-MetadataToRemote.ps1` - Commits and pushes metadata changes

### Library Modules (libs/)

**Core Libraries:**
- `ZolaContentHelper.psm1` - Zola static site content generation
- `GitHelper.psm1` - Git operations and repository management
- `ScanFileHelper.psm1` - File scanning and metadata extraction
- `JsonHelper.psm1` - JSON processing and validation
- `PathHelper.psm1` - Path resolution and validation
- `ConvertImage.psm1` - Image conversion and optimization
- `ConvertText.psm1` - Text processing and transliteration
- `ToolsHelper.psm1` - System tool validation and utilities

### Configuration

**config.json** - Main configuration file containing:
- `SourcePath` - Directory with scanned documents
- `ResultPath` - Directory for processed results
- `ZolaContentPath` - Directory for Zola site content
- `GitRepoUrl` - Git repository URL for metadata storage
- `GitlabProjectId` - GitLab project ID for merge requests

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
2. **Testing**: Run individual test files with `Invoke-Pester ./tests/[TestName].Tests.ps1`
3. **Processing**: Use `Complete-ArchiveProcess.ps1` for full pipeline execution
4. **Git Integration**: The system automatically creates branches and merge requests

## Dependencies

- PowerShell 7+ (cross-platform support via `Get-CrossPlatformPwsh`)
- Git (for metadata repository management)
- ImageMagick or similar (for image conversion)
- GitLab CLI or API access (for merge request creation)
- Pester (for running tests)

## Important Notes

- All file paths are resolved through `PathHelper.psm1` functions
- The system uses transliteration for filename normalization
- Git operations are handled through custom `GitHelper.psm1` wrapper
- Metadata is stored in JSON format and versioned through Git
- The system generates timestamped branches for each processing run