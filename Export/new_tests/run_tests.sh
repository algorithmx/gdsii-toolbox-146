#!/bin/bash
# Run the GDS-STL-STEP Essential Test Suite
# Usage: ./run_tests.sh

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change to the test directory
cd "$SCRIPT_DIR"

# Run the tests using Octave
echo "=========================================="
echo "Running GDS-STL-STEP Test Suite"
echo "=========================================="
echo ""

octave --eval "run_tests()"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Test suite completed successfully"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "✗ Test suite failed with exit code $EXIT_CODE"
    echo "=========================================="
fi

exit $EXIT_CODE
