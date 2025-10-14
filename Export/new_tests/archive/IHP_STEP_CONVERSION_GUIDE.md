# IHP SG13G2 GDS to STEP Conversion Guide

This guide provides comprehensive instructions for converting IHP SG13G2 PDK GDS files to STEP format using the updated and fixed conversion tools.

## Quick Start

### 1. Simple Conversion (Recommended)

Use the simplified conversion utility for basic GDS to STEP conversion:

```matlab
% Navigate to Export directory
cd Export

% Convert a GDS file to STEP with default settings
convert_gds_to_step_simple('path/to/your/file.gds', 'output.step');

% Convert with custom configuration
convert_gds_to_step_simple('input.gds', 'output.step', 'new_tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json');
```

### 2. Comprehensive Test Suite

Run the complete IHP SG13G2 test suite:

```matlab
% Navigate to Export directory
cd Export

% Run comprehensive conversion test
test_ihp_sg13g2_to_step();

% Run with specific configuration
test_ihp_sg13g2_to_step('config', 'accurate', 'verbose', true);
```

### 3. Integration with New Test Framework

Run tests through the new test framework:

```bash
cd Export/new_tests
./run_tests.sh
```

Or from MATLAB/Octave:

```matlab
cd Export/new_tests
run_tests('optional', true);  % Include PDK tests if available
```

## Directory Structure

```
Export/
├── test_ihp_sg13g2_to_step.m          # Comprehensive conversion test
├── convert_gds_to_step_simple.m       # Simple conversion utility
├── new_tests/
│   ├── fixtures/
│   │   └── ihp_sg13g2/
│   │       ├── layer_config_ihp_sg13g2.json           # Standard config
│   │       ├── layer_config_ihp_sg13g2_accurate.json  # LEF-based accurate config
│   │       └── pdk_test_sets/                         # Test GDS files location
│   │           ├── basic/      # Simple single-layer structures
│   │           ├── intermediate/  # Multi-layer devices
│   │           ├── complex/       # Full devices
│   │           └── comprehensive/ # Complete PDK validation
│   ├── optional/
│   │   └── test_pdk_basic.m      # Updated to use new paths
│   └── run_tests.m               # Main test runner
└── test_output_ihp_step/         # Generated STEP files
```

## Configuration Files

### Standard Configuration (`layer_config_ihp_sg13g2.json`)
- 24 defined layers
- Representative Z-heights for testing
- Good for initial validation and testing

### Accurate Configuration (`layer_config_ihp_sg13g2_accurate.json`)
- **Recommended for production use**
- Extracted from actual `sg13g2_tech.lef` file
- Precise HEIGHT and THICKNESS values from PDK
- 22 optimized layers

## Usage Examples

### Example 1: Convert Single GDS File

```matlab
% Basic conversion
convert_gds_to_step_simple('sg13_hv_nmos.gds', 'nmos_transistor.step');

% With accurate configuration
convert_gds_to_step_simple('sg13_hv_nmos.gds', 'nmos_transistor.step', ...
                          'new_tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json');
```

### Example 2: Batch Convert Multiple Files

```matlab
% Define list of GDS files
gds_files = {
    'res_metal1.gds',
    'sg13_hv_nmos.gds',
    'npn13G2.gds'
};

% Convert each file
for i = 1:length(gds_files)
    [~, filename, ~] = fileparts(gds_files{i});
    output_file = sprintf('output/%s.step', filename);

    convert_gds_to_step_simple(gds_files{i}, output_file);
    fprintf('Converted: %s -> %s\n', gds_files{i}, output_file);
end
```

### Example 3: Run Comprehensive Test Suite

```matlab
% Run with all defaults
test_ihp_sg13g2_to_step();

% Run with specific settings
test_ihp_sg13g2_to_step('config', 'accurate', ...
                       'output', 'my_output', ...
                       'verbose', true);
```

## Adding Test GDS Files

To add your own GDS files for testing:

1. **Copy GDS files to appropriate test directories:**

```bash
# For simple structures
cp your_file.gds Export/new_tests/fixtures/ihp_sg13g2/pdk_test_sets/basic/

# For complex devices
cp complex_device.gds Export/new_tests/fixtures/ihp_sg13g2/pdk_test_sets/complex/
```

2. **Run the conversion test:**

```matlab
cd Export
test_ihp_sg13g2_to_step('verbose', true);
```

## Expected Output

### Successful Conversion Output

```
╔════════════════════════════════════════════════════════╗
║     IHP SG13G2 GDS to STEP Conversion Test           ║
╚════════════════════════════════════════════════════════╝

Path Setup:
  Script directory: /workspace/gdsii-toolbox-146/Export
  Export directory: /workspace/gdsii-toolbox-146/Export
  Toolbox root: /workspace/gdsii-toolbox-146

Directory Setup:
  Configuration: /workspace/.../layer_config_ihp_sg13g2_accurate.json
  Output: /workspace/.../conversion_20251013_135311

Found 3 GDS files:
  1. res_metal1
  2. sg13_hv_nmos
  3. npn13G2

Processing 3 GDS files...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/3] Processing: res_metal1
  ✓ Load GDS: 0.012 sec, 1 structures
  ✓ Extract layers: 0.008 sec, 1 active, 4 polygons
  ✓ Export STEP: 0.045 sec, 2.34 KB
  ✅ SUCCESS (0.068 sec total)

[2/3] Processing: sg13_hv_nmos
  ✓ Load GDS: 0.045 sec, 1 structures
  ✓ Extract layers: 0.123 sec, 5 active, 47 polygons
  ✓ Export STEP: 0.156 sec, 12.67 KB
  ✅ SUCCESS (0.324 sec total)

[3/3] Processing: npn13G2
  ✓ Load GDS: 0.189 sec, 1 structures
  ✓ Extract layers: 0.445 sec, 8 active, 156 polygons
  ✓ Export STEP: 0.287 sec, 28.91 KB
  ✅ SUCCESS (0.921 sec total)

Processing completed in 1.31 seconds

╔════════════════════════════════════════════════════════╗
║           CONVERSION SUMMARY REPORT                    ║
╚════════════════════════════════════════════════════════╝

Overall Results:
  Total files:     3
  Successfully converted: 3
  Failed:          0
  Success rate:    100.0%
  Total time:      1.31 seconds
  Average time:    0.437 seconds per file

Detailed Results:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  res_metal1          ✅ PASS   0.068 sec    1 layers, 4 polys
  sg13_hv_nmos        ✅ PASS   0.324 sec    5 layers, 47 polys
  npn13G2             ✅ PASS   0.921 sec    8 layers, 156 polys

Successful Conversion Statistics:
  Total layers processed: 14
  Total polygons:         207
  Total STEP size:        43.92 KB
  Total STL size:         38.45 KB
  Average layers/file:    4.7
  Average polygons/file:  69.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                🎉 ALL CONVERSIONS SUCCEEDED!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📄 Detailed report saved to: .../conversion_report.txt
```

## Troubleshooting

### Common Issues

1. **"No GDS files found"**
   - Add GDS files to the test directories
   - Check file permissions
   - Verify directory structure

2. **"Configuration file not found"**
   - Use the simplified converter (no config required)
   - Check path to configuration files
   - Use default configuration

3. **"GDS file loading failed"**
   - Verify GDS file format
   - Check if file is corrupted
   - Ensure file is not empty

4. **"STEP export failed"**
   - The simplified converter will create a geometry summary file
   - Check output directory permissions
   - Verify file path is valid

### Performance Tips

- **For large files**: Process individually rather than in batches
- **For testing**: Use the standard configuration first
- **For production**: Use the accurate LEF-based configuration

## Integration with Existing Workflows

### MATLAB Scripts

```matlab
% Add to existing MATLAB workflow
addpath('Export');
gds_file = 'your_design.gds';
step_file = 'your_design.step';
convert_gds_to_step_simple(gds_file, step_file);
```

### Command Line Integration

```bash
# Create a simple conversion script
echo "convert_gds_to_step_simple('$1', '$2')" > convert_script.m
octave convert_script.m input.gds output.step
```

### Batch Processing

```matlab
% Process all GDS files in a directory
gds_files = dir('*.gds');
for i = 1:length(gds_files)
    input_file = fullfile(pwd, gds_files(i).name);
    [~, name, ~] = fileparts(gds_files(i).name);
    output_file = fullfile('output', [name '.step']);

    convert_gds_to_step_simple(input_file, output_file);
end
```

## Advanced Features

### Custom Layer Configuration

Create your own layer configuration JSON file:

```json
{
  "layers": {
    "1_0": {
      "layer": 1,
      "datatype": 0,
      "name": "CustomLayer1",
      "z_bottom": 0.0,
      "z_top": 0.5,
      "material": "Aluminum",
      "color": "#FF0000"
    }
  }
}
```

### Error Handling

The simplified converter includes robust error handling:

```matlab
try
    convert_gds_to_step_simple('input.gds', 'output.step');
    fprintf('Conversion successful!\n');
catch ME
    fprintf('Conversion failed: %s\n', ME.message);
end
```

## Validation

### Verify STEP Files

1. **Check file size**: STEP files should be > 1KB for typical designs
2. **Verify format**: Files should start with "ISO-10303-21;"
3. **Test import**: Try importing into your preferred CAD software

### Compare with STL

The conversion automatically creates both STEP and STL files for comparison:

- **STEP**: For CAD software and manufacturing
- **STL**: For 3D printing and visualization

## Support

For issues or questions:

1. Check the troubleshooting section
2. Verify directory structure and file paths
3. Test with the simple converter first
4. Use verbose mode for detailed output

---

**Last Updated**: 2025-10-13
**Version**: 1.0
**Compatible with**: GDSII Toolbox v146+