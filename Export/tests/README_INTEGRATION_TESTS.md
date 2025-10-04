# Integration Tests for Sections 4.6 - 4.10

This directory contains integration tests for the GDS to STEP implementation, specifically covering sections 4.6-4.10 of the `GDS_TO_STEP_IMPLEMENTATION_PLAN.md`.

## Overview

The integration tests verify that all components of the GDS-to-STEP conversion pipeline work correctly both individually and together in realistic scenarios.

### Components Tested

- **Section 4.6**: `gds_library.to_step()` method
- **Section 4.7**: `gds2step` command-line script
- **Section 4.8**: `gds_flatten_for_3d()` hierarchy flattening
- **Section 4.9**: `gds_window_library()` region extraction/windowing
- **Section 4.10**: `gds_merge_solids_3d()` 3D Boolean operations (not yet in integration tests)

## Test Files

### Main Integration Test
- **`test_integration_4_6_to_4_10.m`**: Comprehensive integration test with 13 test scenarios
  - Tests basic functionality of each component
  - Tests components working together
  - Tests full pipeline with all features enabled

### Legacy Tests
- **`test_section_4_6_and_4_7.m`**: Original test for library method and command-line script
- Other unit tests in the `tests/` directory

## Running the Tests

### Run Integration Test

From Octave/MATLAB:
```octave
cd /path/to/gdsii-toolbox-146/Export/tests
test_integration_4_6_to_4_10()
```

From command line:
```bash
cd /path/to/gdsii-toolbox-146/Export/tests
octave -q --eval "test_integration_4_6_to_4_10()"
```

### Run Individual Tests

```octave
test_section_4_6_and_4_7()
test_boolean_operations()
test_extrusion()
% etc.
```

## Test Scenarios (Integration Test)

The comprehensive integration test includes 13 scenarios:

### Basic Component Tests (1-5)
1. **Library method - basic usage**: Test `glib.to_step()` with default options
2. **Library method - with layer filter**: Test layer filtering capability
3. **Command-line script - help**: Verify help message displays correctly
4. **Command-line basic conversion**: Test `gds2step` script basic usage
5. **Command-line with options**: Test `gds2step` with various options

### Individual Component Tests (6-10)
6. **Hierarchy flattening - from library**: Test flattening a library to resolve references
7. **Hierarchy flattening - from structure**: Test flattening a single structure
8. **Hierarchy flattening - with depth limit**: Test partial flattening with depth control
9. **Windowing - extract region from library**: Test region extraction
10. **Windowing - with polygon clipping**: Test clipping polygons at window boundaries

### Integration Pipeline Tests (11-13)
11. **Integration - flatten + window + export**: Multi-step pipeline test
12. **Integration - library method with flatten and window**: Test method with multiple options
13. **Integration - full pipeline with all features**: Complete end-to-end test

## Test Results

### Current Status (October 2025)

**Passing Tests (5/13):**
- ✓ Library method - basic usage
- ✓ Command-line script - help message
- ✓ Command-line script - basic conversion
- ✓ Command-line script - with options
- ✓ Integration - library method with flatten and window options

**Failing Tests (8/13):**
- ✗ Library method - with layer filter (needs hierarchy flattening first)
- ✗ Hierarchy flattening tests (6-8) - structure access issue
- ✗ Windowing tests (9-10) - structure access issue
- ✗ Integration tests (11, 13) - related to above issues

### Known Issues

1. **Layer filtering without flattening**: When using layer filters on hierarchical designs, references aren't resolved, so polygons on referenced structures aren't included. Solution: Always flatten first when using layer filters.

2. **Structure access in Octave**: The way structures are accessed from `glib.st{k}` may have compatibility issues. This affects standalone flatten and window tests.

## Test Output

All tests create output in:
```
/path/to/gdsii-toolbox-146/Export/tests/test_output_integration_4_6_4_10/
```

Output includes:
- Test GDS files
- Layer configuration JSON files
- Exported STL files
- Test logs

## Test Data

The integration test creates a hierarchical GDS file with:
- 3 structures: `BottomCell`, `MidCell`, `TopCell`
- Structure references (sref) with transformations (rotation)
- Array references (aref)
- Multiple layers (1, 2, 3)
- Realistic geometry for testing

This test data exercises:
- Hierarchy resolution
- Reference transformations
- Array replication
- Multi-layer processing
- Windowing and clipping

## Requirements

### Software Requirements
- **Octave 3.8+** or **MATLAB R2014b+**
- For STL export: No external dependencies
- For STEP export: Python 3.x with pythonOCC (not tested in integration tests yet)

### Toolbox Requirements
All tests require the gdsii-toolbox-146 to be in the MATLAB/Octave path. The test automatically adds the toolbox using:
```octave
addpath(genpath(toolbox_root));
```

## Debugging Failed Tests

To debug a specific test:

1. **Run with verbose output**:
   Modify the test to use `'verbose', 2` instead of `'verbose', 0`

2. **Check intermediate files**:
   Test output files are preserved in `test_output_integration_4_6_4_10/`

3. **Run individual test functions**:
   You can extract and run individual test functions from the integration test file

4. **Check library structure access**:
   If flattening/windowing tests fail, verify structure access:
   ```octave
   glib = read_gds_library('test.gds');
   gstruct = glib.st{1};  % May need different access method
   ```

## Adding New Tests

To add a new test to the integration suite:

1. **Create test function**:
   ```octave
   function test_my_new_feature(test_gds, test_config, test_dir)
       % Your test code here
       % Must throw error if test fails
   end
   ```

2. **Add to main test function**:
   ```octave
   [tests_passed, tests_failed, test_names, test_results] = run_test(...
       tests_passed, tests_failed, test_names, test_results, ...
       'My new feature test', ...
       @() test_my_new_feature(test_gds, test_config, test_dir));
   ```

## Best Practices

### For Test Authors

1. **Use descriptive test names**: Makes it easy to identify what failed
2. **Test one thing per test**: Isolate functionality for easier debugging
3. **Include verification**: Don't just check if file exists, verify content
4. **Use verbose=0 by default**: Keep output clean unless debugging
5. **Clean up resources**: Tests should not leave temp files

### For Test Users

1. **Run full suite regularly**: Catch regressions early
2. **Check test output directory**: Verify generated files look correct
3. **Report failures**: If tests fail unexpectedly, report with details
4. **Keep tests updated**: Update tests when adding new features

## Future Work

### Tests to Add

1. **3D Boolean operations test**: Test `gds_merge_solids_3d()` (Section 4.10)
2. **STEP export test**: Test actual STEP file generation (requires pythonOCC)
3. **Performance tests**: Measure execution time for large designs
4. **Error handling tests**: Verify graceful failure modes
5. **Edge case tests**: Empty libraries, invalid configs, etc.

### Test Improvements

1. **Fix structure access issues**: Improve compatibility with Octave gds_library access
2. **Add validation**: Verify geometry correctness, not just file existence
3. **Parameterize tests**: Make it easier to test different configurations
4. **Add benchmarks**: Track performance over time
5. **Continuous integration**: Automate test execution

## References

- **Implementation Plan**: `GDS_TO_STEP_IMPLEMENTATION_PLAN.md`
- **Main Conversion Function**: `../gds_to_step.m`
- **Library Method**: `../../Basic/@gds_library/to_step.m`
- **Command-Line Script**: `../../Scripts/gds2step`
- **Flattening**: `../gds_flatten_for_3d.m`
- **Windowing**: `../gds_window_library.m`

## Contact

For questions or issues with these tests:
- Check the main toolbox documentation
- Review the implementation plan
- Check test output logs
- Report bugs through the project's issue tracker

---

**Last Updated**: October 4, 2025  
**Test Suite Version**: 1.0  
**Author**: WARP AI Agent
