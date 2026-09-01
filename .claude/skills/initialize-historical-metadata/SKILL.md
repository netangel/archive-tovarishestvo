---
name: initialize-historical-metadata
description: Import metadata for archive scans that were already processed before this pipeline existed (historical data). Use when the user wants to run or explain Initialize-MetadataOnProcessedScans.ps1, backfill metadata for pre-existing processed archives, or asks about DoneScannnedPath/ArchiveContentPath.
---

# Initialize metadata on already-processed scans

```powershell
# Initialize metadata from already processed scans (historical data)
./Initialize-MetadataOnProcessedScans.ps1 -DoneScannnedPath "path/to/original/scans" -ArchiveContentPath "path/to/processed/archive" -MetadataPath "path/to/metadata/output"
```

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
