# IHP SG13G2 GDS to STEP Conversion - Quick Start

This README provides a quick start guide for converting IHP SG13G2 GDS files to STEP format.

## 🚀 Quick Start (3 Simple Steps)

### Step 1: Navigate to Export Directory
```bash
cd Export
```

### Step 2: Place Your GDS Files
Copy your GDS files to the test directories:
```bash
# For simple structures
cp your_file.gds new_tests/fixtures/ihp_sg13g2/pdk_test_sets/basic/

# Or create your own directory
mkdir -p my_gds_files
cp *.gds my_gds_files/
```

### Step 3: Run Conversion

**Option A: Simple Conversion (Recommended)**
```matlab
octave --eval "convert_gds_to_step_simple('my_gds_files/your_file.gds', 'output.step')"
```

**Option B: Comprehensive Test**
```matlab
octave --eval "test_ihp_sg13g2_to_step('verbose', true)"
```

**Option C: Using Test Framework**
```bash
cd new_tests
./run_tests.sh
```

## 📁 What You Need

### Minimum Requirements:
- GDS file(s) you want to convert
- Octave or MATLAB
- This GDSII toolbox

### Optional:
- Layer configuration file (JSON format)
- Custom output directory

## 🎯 Expected Results

Successful conversion will create:
- `output.step` - Main STEP file for CAD software
- `output.stl` - STL file for 3D printing/visualization
- Detailed conversion report (when using test suite)

## 🛠️ Common Use Cases

### 1. Convert Single GDS File
```matlab
convert_gds_to_step_simple('design.gds', 'design.step');
```

### 2. Convert with Custom Configuration
```matlab
convert_gds_to_step_simple('design.gds', 'design.step', ...
                          'new_tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json');
```

### 3. Batch Convert Multiple Files
```matlab
files = {'file1.gds', 'file2.gds', 'file3.gds'};
for i = 1:length(files)
    [~, name, ~] = fileparts(files{i});
    convert_gds_to_step_simple(files{i}, [name '.step']);
end
```

## 📚 More Information

For detailed documentation, see:
- `IHP_STEP_CONVERSION_GUIDE.md` - Comprehensive guide
- `test_ihp_sg13g2_to_step.m` - Advanced test functions
- `convert_gds_to_step_simple.m` - Simple conversion utility

## 🔧 Troubleshooting

**No GDS files found?**
- Add files to the test directories
- Use the simple converter with full paths

**Configuration errors?**
- Use the simple converter (no config required)
- Check JSON syntax

**Permission errors?**
- Ensure write access to output directory
- Use absolute paths

---

**Ready to start?** Place your GDS files and run the conversion! 🎉