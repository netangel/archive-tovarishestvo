# Quick Start: Modern Image Processing Tools

This is a quick reference for installing and testing Poppler and libvips as replacements for Ghostscript and ImageMagick.

## Installation (5 minutes)

### macOS
```bash
brew install poppler vips
```

### Windows

**Option 1: Scoop (Easiest)**
```powershell
# Install Scoop (if needed)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Install Poppler
scoop install poppler
```

**Option 2: Manual**
- Poppler: Download from https://github.com/oschwartz10612/poppler-windows/releases
- libvips: Download from https://github.com/libvips/libvips/releases (get `vips-dev-w64-all-*.zip`)

Extract both and add their `bin` directories to PATH.

## Quick Test

```powershell
# Run the test script
./Test-ModernImageProcessing.ps1

# With a test PDF for performance comparison
./Test-ModernImageProcessing.ps1 -TestPdfPath "path/to/test.pdf"
```

## Using in Your Scripts

**Before:**
```powershell
Import-Module ./libs/ConvertImage.psm1
```

**After:**
```powershell
Import-Module ./libs/ConvertImage-Modern.psm1
```

All functions remain the same - it's a drop-in replacement!

## Why Switch?

| Benefit | Improvement |
|---------|-------------|
| Speed | 2-8x faster |
| Memory | 15x less (200MB vs 3GB) |
| Quality | Better PDF conversion quality |
| Reliability | Handles large images better |

## Verify Installation

```powershell
# Check if tools are available
pdftoppm -v
vips --version
vipsthumbnail --version
```

## Command Examples

### PDF to TIFF (300 DPI, grayscale)
```bash
pdftoppm -tiff -gray -r 300 -tiffcompression lzw input.pdf output
```

### Resize TIFF to 50%
```bash
vips resize input.tif output.tif 0.5 --kernel lanczos3
```

### Create thumbnail (400px)
```bash
vipsthumbnail input.png --size=400 -o thumbnail.png[Q=95]
```

### Convert TIFF to PNG
```bash
vips copy input.tif output.png[compression=9]
```

## Next Steps

1. Install the tools
2. Run `./Test-ModernImageProcessing.ps1` to verify
3. Test with a sample PDF from your archive
4. Review detailed migration guide: [IMAGE-PROCESSING-MIGRATION.md](./IMAGE-PROCESSING-MIGRATION.md)

## Troubleshooting

**"Command not found" on Windows:**
```powershell
# Add to PATH temporarily
$env:PATH += ";C:\path\to\poppler\bin;C:\path\to\vips\bin"
```

**"Missing DLL" error:**
- Make sure you extracted the FULL vips-dev-w64-all package
- The `bin` directory should contain many DLL files
- Add the `bin` directory to PATH, not the parent

## Links

- Full migration guide: [docs/IMAGE-PROCESSING-MIGRATION.md](./IMAGE-PROCESSING-MIGRATION.md)
- Poppler: https://poppler.freedesktop.org/
- libvips: https://www.libvips.org/
- Test script: [Test-ModernImageProcessing.ps1](../Test-ModernImageProcessing.ps1)
