#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test and compare modern image processing tools (Poppler/libvips) against legacy tools (ImageMagick/Ghostscript)

.DESCRIPTION
This script tests the availability and basic functionality of both old and new image processing tools.
It provides a comparison of performance and validates that the new tools work correctly.

.PARAMETER TestPdfPath
Path to a test PDF file for conversion testing

.PARAMETER SkipPerformanceTest
Skip the performance comparison test

.EXAMPLE
./Test-ModernImageProcessing.ps1

.EXAMPLE
./Test-ModernImageProcessing.ps1 -TestPdfPath "./test-data/sample.pdf"
#>

param(
    [string]$TestPdfPath = "",
    [switch]$SkipPerformanceTest
)

Import-Module (Join-Path $PSScriptRoot "libs/ToolsHelper.psm1") -Force

Write-Host "=== Testing Image Processing Tools ===" -ForegroundColor Cyan
Write-Host ""

# Test current tools (ImageMagick/Ghostscript)
Write-Host "Current Tools (Legacy):" -ForegroundColor Yellow
Write-Host "  ImageMagick: " -NoNewline
if (Test-ImageMagick) {
    $magickCmd = Get-ToolCommand -Tool ImageMagick
    $version = & $magickCmd --version | Select-Object -First 1
    Write-Host "✓ Found ($version)" -ForegroundColor Green
} else {
    Write-Host "✗ Not found" -ForegroundColor Red
}

Write-Host "  Ghostscript: " -NoNewline
if (Test-Ghostscript) {
    try {
        $gsCmd = Get-ToolCommand -Tool GhostScript
        $version = & $gsCmd --version 2>&1
        Write-Host "✓ Found (version $version)" -ForegroundColor Green
    } catch {
        Write-Host "✓ Found (version unknown)" -ForegroundColor Green
    }
} else {
    Write-Host "✗ Not found" -ForegroundColor Red
}

Write-Host ""

# Test new tools (Poppler/libvips)
Write-Host "Modern Tools (Proposed):" -ForegroundColor Yellow
Write-Host "  Poppler (pdftoppm): " -NoNewline
if (Test-Poppler) {
    try {
        $popplerCmd = Get-ToolCommand -Tool Poppler
        $version = & $popplerCmd -v 2>&1 | Select-Object -First 1
        Write-Host "✓ Found ($version)" -ForegroundColor Green
    } catch {
        Write-Host "✓ Found" -ForegroundColor Green
    }
} else {
    Write-Host "✗ Not found" -ForegroundColor Red
    Write-Host "    Install: macOS: brew install poppler | Windows: scoop install poppler" -ForegroundColor Gray
}

Write-Host "  libvips: " -NoNewline
if (Test-Vips) {
    try {
        $vipsCmd = Get-ToolCommand -Tool Vips
        $version = & $vipsCmd --version 2>&1 | Select-Object -First 1
        Write-Host "✓ Found ($version)" -ForegroundColor Green
    } catch {
        Write-Host "✓ Found" -ForegroundColor Green
    }
} else {
    Write-Host "✗ Not found" -ForegroundColor Red
    Write-Host "    Install: macOS: brew install vips | Windows: https://github.com/libvips/libvips/releases" -ForegroundColor Gray
}

Write-Host ""

# Check if both stacks are available
$hasLegacy = (Test-ImageMagick) -and (Test-Ghostscript)
$hasModern = (Test-Poppler) -and (Test-Vips)

if (-not $hasLegacy -and -not $hasModern) {
    Write-Host "ERROR: Neither legacy nor modern tools are available!" -ForegroundColor Red
    Write-Host "Please install at least one set of tools." -ForegroundColor Red
    exit 1
}

if ($hasLegacy -and $hasModern) {
    Write-Host "✓ Both tool sets available - performance comparison possible" -ForegroundColor Green
} elseif ($hasLegacy) {
    Write-Host "⚠ Only legacy tools available - install modern tools to test migration" -ForegroundColor Yellow
} else {
    Write-Host "✓ Modern tools available - legacy tools not needed" -ForegroundColor Green
}

Write-Host ""

# Performance test if requested and both stacks available
if (-not $SkipPerformanceTest -and $hasLegacy -and $hasModern -and $TestPdfPath -ne "") {
    if (-not (Test-Path $TestPdfPath)) {
        Write-Host "ERROR: Test PDF not found: $TestPdfPath" -ForegroundColor Red
        exit 1
    }

    Write-Host "=== Performance Comparison ===" -ForegroundColor Cyan
    Write-Host "Testing with: $TestPdfPath" -ForegroundColor Gray
    Write-Host ""

    $testDir = Join-Path $PSScriptRoot "temp_test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        # Test legacy tools
        Write-Host "Testing legacy tools (ImageMagick + Ghostscript)..." -ForegroundColor Yellow
        Import-Module (Join-Path $PSScriptRoot "libs/ConvertImage.psm1") -Force

        $legacyOutput = Join-Path $testDir "output_legacy.tif"
        $legacyTime = Measure-Command {
            Convert-PdfToTiff -InputPdfFile (Get-Item $TestPdfPath) -OutputTiffFileName $legacyOutput
        }

        $legacySize = (Get-Item $legacyOutput).Length / 1MB
        Write-Host "  Time: $($legacyTime.TotalSeconds.ToString('F2'))s" -ForegroundColor Gray
        Write-Host "  Output size: $($legacySize.ToString('F2')) MB" -ForegroundColor Gray
        Write-Host ""

        # Test modern tools
        Write-Host "Testing modern tools (Poppler + libvips)..." -ForegroundColor Yellow
        Import-Module (Join-Path $PSScriptRoot "libs/ConvertImage-Modern.psm1") -Force

        $modernOutput = Join-Path $testDir "output_modern.tif"
        $modernTime = Measure-Command {
            Convert-PdfToTiff -InputPdfFile (Get-Item $TestPdfPath) -OutputTiffFileName $modernOutput
        }

        $modernSize = (Get-Item $modernOutput).Length / 1MB
        Write-Host "  Time: $($modernTime.TotalSeconds.ToString('F2'))s" -ForegroundColor Gray
        Write-Host "  Output size: $($modernSize.ToString('F2')) MB" -ForegroundColor Gray
        Write-Host ""

        # Comparison
        Write-Host "Results:" -ForegroundColor Cyan
        $speedup = $legacyTime.TotalSeconds / $modernTime.TotalSeconds
        if ($speedup -gt 1) {
            Write-Host "  Modern tools are $($speedup.ToString('F2'))x faster! ⚡" -ForegroundColor Green
        } else {
            Write-Host "  Legacy tools are $(1/$speedup.ToString('F2'))x faster" -ForegroundColor Yellow
        }

        $sizeDiff = (($modernSize - $legacySize) / $legacySize) * 100
        if ($sizeDiff -lt 0) {
            Write-Host "  Modern output is $([Math]::Abs($sizeDiff).ToString('F1'))% smaller 📦" -ForegroundColor Green
        } else {
            Write-Host "  Modern output is $($sizeDiff.ToString('F1'))% larger" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Output files for visual comparison:" -ForegroundColor Gray
        Write-Host "  Legacy: $legacyOutput" -ForegroundColor Gray
        Write-Host "  Modern: $modernOutput" -ForegroundColor Gray

    } catch {
        Write-Host "ERROR during performance test: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    } finally {
        # Cleanup - comment this out if you want to inspect the files
        # Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host "Test files saved in: $testDir" -ForegroundColor Gray
        Write-Host "(Delete manually when done inspecting)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "For detailed migration guide, see: docs/IMAGE-PROCESSING-MIGRATION.md" -ForegroundColor Gray
Write-Host ""

if ($hasModern) {
    Write-Host "✓ Ready to use modern image processing tools!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To switch your scripts:" -ForegroundColor Gray
    Write-Host "  Change: Import-Module ./libs/ConvertImage.psm1" -ForegroundColor Gray
    Write-Host "  To:     Import-Module ./libs/ConvertImage-Modern.psm1" -ForegroundColor Gray
} else {
    Write-Host "Install modern tools to proceed with migration:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "macOS:" -ForegroundColor Gray
    Write-Host "  brew install poppler vips" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Windows:" -ForegroundColor Gray
    Write-Host "  scoop install poppler" -ForegroundColor Gray
    Write-Host "  # Download libvips from: https://github.com/libvips/libvips/releases" -ForegroundColor Gray
}

Write-Host ""
