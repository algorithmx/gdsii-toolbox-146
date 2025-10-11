#!/bin/bash
# Clean test output files
# Usage: ./clean_outputs.sh [--all]

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="$SCRIPT_DIR/test_output"

echo "=========================================="
echo "Cleaning Test Outputs"
echo "=========================================="
echo ""

if [ "$1" == "--all" ]; then
    echo "Removing entire test_output directory..."
    rm -rf "$OUTPUT_DIR"
    echo "✓ Removed: $OUTPUT_DIR"
    echo ""
    echo "Recreating test_output directory..."
    mkdir -p "$OUTPUT_DIR"
    echo "✓ Created: $OUTPUT_DIR"
else
    echo "Removing generated test files..."
    if [ -d "$OUTPUT_DIR" ]; then
        FILE_COUNT=$(find "$OUTPUT_DIR" -type f \( -name "*.stl" -o -name "*.gds" -o -name "*.step" \) 2>/dev/null | wc -l)
        
        if [ "$FILE_COUNT" -gt 0 ]; then
            find "$OUTPUT_DIR" -type f \( -name "*.stl" -o -name "*.gds" -o -name "*.step" \) -delete
            echo "✓ Removed $FILE_COUNT test output file(s)"
        else
            echo "No test output files to clean"
        fi
    else
        echo "test_output directory doesn't exist, creating it..."
        mkdir -p "$OUTPUT_DIR"
        echo "✓ Created: $OUTPUT_DIR"
    fi
fi

echo ""
echo "=========================================="
echo "✓ Cleanup complete"
echo "=========================================="
echo ""
echo "Usage:"
echo "  ./clean_outputs.sh       # Remove generated files only"
echo "  ./clean_outputs.sh --all # Remove and recreate output directory"
