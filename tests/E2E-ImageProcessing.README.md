# End-to-End Image Processing Tests

## Overview

This test suite (`E2E-ImageProcessing.Tests.ps1`) provides comprehensive end-to-end testing for the archive processing system. It validates the complete workflow from raw scanned files to generated Zola static site content.

## Test Structure

### 1. Environment Setup and Validation
Tests the creation of test directory structures and generation of valid test files (PDF/TIFF).

**Test Files Generated:**
```
/input_files
  |- /тестовая папка 1
  |    |- 01-ЧертежПростой_Категория1_Деталь1_1999.pdf
  |    |- 11-ЧертежДетали_Категория1_Категория2_Деталь2_1998.pdf
  |- /тестовая папка 2
       |- 01-ЧертежДругой_Категория3_Деталь1_1999.pdf
       |- 11-Чертеж3_Категория3_Категория2_Деталь2_2000.pdf
```

### 2. File Naming and Transliteration
Validates Russian-to-Latin transliteration and filename pattern parsing for tags and years.

### 3. Image Processing Pipeline
Tests the conversion of PDF/TIFF files with proper output structure:
- TIF files (converted originals)
- PNG files (browser preview)
- Thumbnails (400px wide variants)

### 4. Metadata Generation and Validation
Verifies JSON metadata structure and content for processed files.

**Metadata Schema:**
```json
{
  "DirectoryOriginalName": "тестовая папка 1",
  "ProcessedScans": {
    "hash123": {
      "OriginalName": "01-ЧертежПростой_Категория1_Деталь1_1999.pdf",
      "ResultFileName": "01-chertezh-prostoy.tif",
      "PngFile": "01-chertezh-prostoy.png",
      "Tags": ["Категория1", "Деталь1"],
      "Year": "1999",
      "Thumbnails": {
        "400": "01-chertezh-prostoy_400.png"
      }
    }
  }
}
```

### 5. Zola Content Generation
Tests the creation of Zola static site content from metadata:
- Root index page (`_index.md`)
- Section pages (directory indexes)
- Content pages (individual file pages)

### 6. Full End-to-End Workflow
Complete integration test that:
1. Creates test directory structure
2. Processes all PDF files
3. Generates metadata
4. Creates Zola site content
5. Validates all outputs

## Running the Tests

### Prerequisites
- PowerShell 7+ installed
- Pester testing framework installed
- All project dependencies (see main README)

### Run All E2E Tests
```powershell
Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1
```

### Run Specific Test Context
```powershell
# Environment setup tests only
Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -TestName "*Environment Setup*"

# Metadata tests only
Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -TestName "*Metadata*"

# Full workflow test only
Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -TestName "*Full End-to-End*"
```

### Verbose Output
```powershell
Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -Output Detailed
```

## Test Helpers

### `New-TestPdfFile`
Creates a minimal valid PDF file for testing purposes.

**Parameters:**
- `Path` - Output file path
- `Pages` - Number of pages (default: 1)

### `New-TestTiffFile`
Creates a minimal valid TIFF file (1x1 pixel monochrome).

**Parameters:**
- `Path` - Output file path

### `New-TestDirectoryStructure`
Sets up complete test directory structure with Russian folder names and test files.

**Parameters:**
- `BasePath` - Base path for test structure

**Returns:** Path to input_files directory

## Mocking Strategy

The tests use PowerShell mocking for image conversion operations to:
- Speed up test execution
- Avoid dependency on external tools (ImageMagick, etc.)
- Focus on workflow logic rather than actual image processing

**Mocked Functions:**
- `Convert-PdfToTiff` - PDF to TIFF conversion
- `Convert-WebPngOrRename` - TIFF to PNG conversion
- `New-Thumbnail` - Thumbnail generation
- `Optimize-Tiff` - TIFF optimization

## Expected Outputs

### Processed Files Structure
```
/result
  |- /metadata
  |    |- testovaya-papka-1.json
  |    |- testovaya-papka-2.json
  |- /testovaya-papka-1
  |    |- 01-chertezh-prostoy.tif
  |    |- 01-chertezh-prostoy.png
  |    |- /thumbnails
  |         |- 01-chertezh-prostoy_400.png
  |- /testovaya-papka-2
       |- (similar structure)
```

### Zola Content Structure
```
/zola_content
  |- _index.md
  |- /testovaya-papka-1
  |    |- _index.md
  |    |- hash1.md (content page)
  |    |- hash2.md (content page)
  |- /testovaya-papka-2
       |- _index.md
       |- hash3.md
       |- hash4.md
```

## Cleanup

The test suite uses Pester's `TestDrive:` feature which automatically cleans up all test files after each test context. No manual cleanup is required.

## Integration with CI/CD

This test suite can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run E2E Tests
  run: |
    pwsh -Command "Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -CI"
```

## Troubleshooting

### Test Failures
1. **Module import errors**: Ensure all required modules are available in `libs/`
2. **Mock failures**: Verify mock module names match the actual module names
3. **Path issues**: Check that TestDrive paths are used correctly

### Common Issues
- **Russian text encoding**: Ensure terminal supports UTF-8
- **Permission errors**: Run PowerShell with appropriate permissions
- **Missing dependencies**: Install Pester: `Install-Module -Name Pester -Force`

## Future Enhancements

Potential improvements for the test suite:
- [ ] Add tests for multi-page PDF processing
- [ ] Test error handling and recovery
- [ ] Add performance benchmarks
- [ ] Test Git integration workflows
- [ ] Add tests for edge cases (corrupt files, special characters)
- [ ] Integration with actual image processing tools (optional)

## Related Documentation

- Main project documentation: `/CLAUDE.md`
- Individual module tests: `/tests/*.Tests.ps1`
- Processing scripts: Root directory `*.ps1` files
