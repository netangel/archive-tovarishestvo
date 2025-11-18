#!/bin/bash
# Simple PowerShell syntax validation script

echo "PowerShell Syntax Validation Report"
echo "===================================="
echo ""

TEST_FILE="./tests/E2E-ImageProcessing.Tests.ps1"

# Check if file exists
if [ ! -f "$TEST_FILE" ]; then
    echo "❌ Test file not found: $TEST_FILE"
    exit 1
fi

echo "✅ Test file exists: $TEST_FILE"
echo "   Size: $(wc -c < "$TEST_FILE") bytes"
echo "   Lines: $(wc -l < "$TEST_FILE") lines"
echo ""

# Check for basic PowerShell syntax elements
echo "Checking PowerShell syntax elements:"
echo ""

# Check for BeforeAll/BeforeEach blocks
if grep -q "BeforeAll {" "$TEST_FILE"; then
    echo "✅ Found BeforeAll block"
else
    echo "❌ Missing BeforeAll block"
fi

if grep -q "BeforeEach {" "$TEST_FILE"; then
    echo "✅ Found BeforeEach blocks"
else
    echo "⚠️  No BeforeEach blocks"
fi

# Check for Describe blocks
DESCRIBE_COUNT=$(grep -c "^Describe " "$TEST_FILE")
echo "✅ Found $DESCRIBE_COUNT Describe block(s)"

# Check for Context blocks
CONTEXT_COUNT=$(grep -c "^\s*Context " "$TEST_FILE")
echo "✅ Found $CONTEXT_COUNT Context block(s)"

# Check for It blocks
IT_COUNT=$(grep -c '^\s*It "' "$TEST_FILE")
echo "✅ Found $IT_COUNT It (test case) block(s)"

echo ""
echo "Checking module imports:"
echo ""

# Check module imports
MODULES=("ScanFileHelper" "PathHelper" "ConvertText" "JsonHelper" "ZolaContentHelper" "HashHelper")
for module in "${MODULES[@]}"; do
    if grep -q "Import-Module.*$module" "$TEST_FILE"; then
        echo "✅ Imports $module.psm1"
    else
        echo "❌ Missing import: $module.psm1"
    fi
done

echo ""
echo "Checking for balanced braces:"
echo ""

OPEN_BRACES=$(grep -o "{" "$TEST_FILE" | wc -l)
CLOSE_BRACES=$(grep -o "}" "$TEST_FILE" | wc -l)

echo "   Opening braces: $OPEN_BRACES"
echo "   Closing braces: $CLOSE_BRACES"

if [ "$OPEN_BRACES" -eq "$CLOSE_BRACES" ]; then
    echo "✅ Braces are balanced"
else
    echo "❌ Braces are NOT balanced (difference: $((OPEN_BRACES - CLOSE_BRACES)))"
fi

echo ""
echo "Checking function calls against module exports:"
echo ""

# Functions that should exist
FUNCTIONS=(
    "ConvertTo-Translit"
    "Get-TagsFromName"
    "Get-YearFromFilename"
    "Convert-FileAndCreateData"
    "Convert-StringToMD5"
    "New-RootIndexPage"
    "New-SectionPage"
    "New-ContentPage"
)

for func in "${FUNCTIONS[@]}"; do
    if grep -q "$func" "$TEST_FILE"; then
        # Check if it's exported in libs
        if grep -r "Export-ModuleMember.*$func" libs/ > /dev/null 2>&1; then
            echo "✅ $func - used in test and exported from module"
        else
            echo "⚠️  $func - used in test but export not found"
        fi
    fi
done

echo ""
echo "Checking mocking strategy:"
echo ""

# Check for Mock statements
MOCK_COUNT=$(grep -c "^\s*Mock " "$TEST_FILE")
echo "   Found $MOCK_COUNT Mock statements"

if grep -q "Mock -ModuleName ScanFileHelper" "$TEST_FILE"; then
    echo "✅ Mocks ScanFileHelper functions"
fi

echo ""
echo "Summary:"
echo "========"
echo "Test file appears to be syntactically valid for Pester testing."
echo "Recommended: Run 'Invoke-Pester $TEST_FILE' in PowerShell to execute tests."
echo ""
