# GDS to STEP Module - Quick Start Guide

**Target Audience:** Developers ready to begin implementation  
**Estimated Reading Time:** 5 minutes  
**Status:** Ready to Code

---

## 📚 Documentation Overview

You have **4 planning documents** available:

| Document | Size | Purpose | When to Read |
|----------|------|---------|--------------|
| **QUICK_START_GUIDE.md** (this file) | 2 KB | Get started immediately | First |
| **IMPLEMENTATION_SUMMARY.md** | 10 KB | Executive summary | Before coding |
| **GDS_TO_STEP_IMPLEMENTATION_PLAN.md** | 32 KB | Complete technical plan | During development |
| **MODULE_INTEGRATION_MAP.txt** | 14 KB | Architecture diagrams | Reference |
| **GDSII_TO_STEP_ASSESSMENT.md** | 16 KB | Feasibility analysis | Background |

---

## 🚀 Getting Started in 5 Steps

### Step 1: Review the Plan (10 minutes)
```bash
cd ~/Documents/gdsii-toolbox-146
cat IMPLEMENTATION_SUMMARY.md  # Quick overview
cat MODULE_INTEGRATION_MAP.txt  # Architecture diagrams
```

### Step 2: Set Up Environment (30 minutes)

**Required:**
```bash
# Already have MATLAB/Octave and gdsii-toolbox compiled
# Nothing additional needed for Phase 1-2
```

**Optional (for STEP export in Phase 3):**
```bash
# Install Python dependencies
python3 -m pip install pythonocc-core
python3 -c "from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeBox; print('pythonOCC OK')"
```

### Step 3: Create Directory Structure (5 minutes)

```bash
# Create new module directories
mkdir -p Export/private
mkdir -p Export/tests/fixtures
mkdir -p layer_configs

# Create placeholder files
touch Export/Contents.m
touch Export/README.md
touch layer_configs/README.md
```

### Step 4: Start Phase 1 Implementation (Begin coding!)

**Week 1 Goal:** Layer configuration system

**Files to create first:**
1. `layer_configs/example_cmos.json` (copy template from plan)
2. `Export/gds_read_layer_config.m` (JSON parser)
3. `Export/tests/test_layer_config.m` (unit tests)

**Template for `gds_read_layer_config.m`:**
```matlab
function layer_config = gds_read_layer_config(config_file)
% GDS_READ_LAYER_CONFIG - Parse layer configuration file
%
% See GDS_TO_STEP_IMPLEMENTATION_PLAN.md section 4.1 for details

    % Validate input
    if ~exist(config_file, 'file')
        error('gds_read_layer_config: file not found --> %s', config_file);
    end
    
    % Read JSON file
    % (Use jsondecode() in MATLAB R2016b+, or third-party parser for older)
    fid = fopen(config_file, 'r');
    raw_text = fread(fid, '*char')';
    fclose(fid);
    
    % Parse JSON
    layer_config = jsondecode(raw_text);
    
    % Validate structure
    % ... add validation code here ...
    
end
```

### Step 5: Test Your Code

```matlab
% Test layer config parsing
addpath(genpath('~/Documents/gdsii-toolbox-146'));
config = gds_read_layer_config('layer_configs/example_cmos.json');
disp(config);
```

---

## 📋 Phase 1 Checklist (Week 1-2)

### Week 1: Configuration System
- [ ] Create `layer_configs/example_cmos.json` (see plan section 4.1)
- [ ] Create `layer_configs/example_mems.json`
- [ ] Implement `Export/gds_read_layer_config.m`
- [ ] Implement `Export/private/validate_layer_config.m`
- [ ] Write unit tests: `Export/tests/test_layer_config.m`
- [ ] Test with valid and invalid configs

### Week 2: Polygon Extraction
- [ ] Implement `Export/gds_layer_to_3d.m`
- [ ] Test with simple GDS file (single layer, few polygons)
- [ ] Test with multi-layer GDS file
- [ ] Write unit tests: `Export/tests/test_layer_extraction.m`
- [ ] Document data structures in `Export/README.md`

---

## 🔗 Key Code Integration Points

### Leverage These Existing Functions

```matlab
% From Basic/ - Use these in your new code:

% 1. Read GDS files
glib = read_gds_library('design.gds');

% 2. Access structures
num_structures = numel(glib.st);
for k = 1:num_structures
    struc = glib.st{k};
    % Process structure
end

% 3. Extract layer info from elements
for el_idx = 1:numel(struc.el)
    elem = struc.el{el_idx};
    [layer_num, dtype] = layer(elem);
    
    % Get polygon coordinates
    if isa(elem.data.xy, 'cell')
        polygons = elem.data.xy;
    else
        polygons = {elem.data.xy};
    end
end

% 4. Convert paths to polygons
if strcmp(etype(elem), 'path')
    boundary_elem = poly_path(elem);
    polygons = boundary_elem.data.xy;
end

% 5. Check polygon orientation
if ~poly_iscw(elem)
    elem = poly_cw(elem);  % Make clockwise
end

% 6. Calculate bounding box
bb = bbox(elem);  % [x_min, y_min, x_max, y_max]
```

---

## 📖 Coding Standards

Follow existing gdsii-toolbox patterns:

### Function Documentation Template
```matlab
function output = my_function(input1, input2, varargin)
% MY_FUNCTION - Brief one-line description
%
% output = my_function(input1, input2)
% output = my_function(input1, input2, options)
%
% Detailed description goes here.
%
% INPUT:
%   input1  : description
%   input2  : description
%   options : (Optional) structure with fields:
%       .field1 - description (default: value)
%       .field2 - description (default: value)
%
% OUTPUT:
%   output : description
%
% EXAMPLE:
%   result = my_function(x, y);
%   result = my_function(x, y, struct('field1', 10));
%
% SEE ALSO: related_function1, related_function2

    % Parse optional arguments
    if nargin < 3
        options = struct();
    else
        options = varargin{1};
    end
    
    % Set defaults
    if ~isfield(options, 'field1')
        options.field1 = default_value;
    end
    
    % Validate inputs
    if ~isnumeric(input1)
        error('my_function: input1 must be numeric.');
    end
    
    % Implementation
    % ...
    
end
```

### Error Handling Pattern
```matlab
if ~exist('file.gds', 'file')
    error('function_name: file not found --> %s', file);
end

if ~isfield(config, 'layers')
    error('function_name: config missing required field ''layers''');
end
```

### Verbose Output Pattern
```matlab
if verbose
    fprintf('Processing layer %d (%s)...\n', layer_num, layer_name);
end

if verbose > 1
    fprintf('  Found %d polygons\n', num_polygons);
    fprintf('  Bounding box: [%.2f, %.2f, %.2f, %.2f]\n', bb);
end
```

---

## 🧪 Testing Strategy

### Unit Tests (Create as you go)
```matlab
% Export/tests/test_layer_config.m
function test_layer_config()
    fprintf('Testing gds_read_layer_config...\n');
    
    % Test 1: Valid config
    config = gds_read_layer_config('fixtures/test_config.json');
    assert(isfield(config, 'layers'), 'Missing layers field');
    fprintf('  ✓ Valid config parsed\n');
    
    % Test 2: Invalid file
    try
        gds_read_layer_config('nonexistent.json');
        error('Should have thrown error');
    catch err
        fprintf('  ✓ Error handling works\n');
    end
    
    fprintf('All tests passed!\n');
end
```

### Run Tests
```matlab
addpath(genpath('~/Documents/gdsii-toolbox-146'));
cd Export/tests
test_layer_config();
```

---

## 🎯 Phase 1 Success Criteria

By end of Week 2, you should have:

✅ JSON layer configuration parser working  
✅ Example config files for CMOS and MEMS  
✅ Function to extract polygons by layer from gds_library  
✅ Unit tests with 100% pass rate  
✅ Documentation in Export/README.md  

**Deliverable:** Can extract polygons organized by layer from a GDS file using a JSON config

---

## 🆘 Troubleshooting

### Issue: JSON parsing fails
**Solution:** Use `jsondecode()` (MATLAB R2016b+) or download JSONlab for older versions

### Issue: Can't find gdsii-toolbox functions
**Solution:** Make sure toolbox is in path:
```matlab
addpath(genpath('~/Documents/gdsii-toolbox-146/Basic'));
```

### Issue: Polygon coordinates in wrong format
**Solution:** Elements store polygons as cell arrays internally:
```matlab
if ~iscell(polygon_xy)
    polygon_xy = {polygon_xy};
end
```

---

## 📞 Getting Help

1. **Architecture questions:** See `MODULE_INTEGRATION_MAP.txt`
2. **Implementation details:** See `GDS_TO_STEP_IMPLEMENTATION_PLAN.md`
3. **Existing code patterns:** See `WARP.md` and existing code in `Basic/`
4. **Data structures:** Read class definitions:
   - `Basic/@gds_library/gds_library.m`
   - `Basic/@gds_structure/gds_structure.m`
   - `Basic/@gds_element/gds_element.m`

---

## 🎓 Learning Resources

### Understand the Existing Codebase (1 hour)
```bash
# Read existing examples
cat Basic/funcs/topstruct.m        # Hierarchy analysis
cat Basic/@gds_library/layerinfo.m # Layer statistics
cat Elements/gdsii_arc.m           # Example element creator
```

### Test the Existing Toolbox (30 minutes)
```matlab
% Create a simple test
glib = gds_library('test');
rect = gds_element('boundary', 'xy', [0 0; 100 0; 100 50; 0 50; 0 0], ...
                   'layer', 1);
gstruc = gds_structure('test_struct', rect);
glib = add_struct(glib, gstruc);

% Write and read back
write_gds_library(glib, 'test.gds');
glib2 = read_gds_library('test.gds');

% Inspect
disp(glib2);
```

---

## ✅ Ready to Code!

You now have:
- ✅ Complete implementation plan
- ✅ Architecture understanding  
- ✅ Development environment
- ✅ Phase 1 task breakdown
- ✅ Code templates and patterns
- ✅ Testing strategy

**Start coding with:**
```bash
cd ~/Documents/gdsii-toolbox-146
mkdir -p Export layer_configs
# Begin with layer_configs/example_cmos.json
# Then implement Export/gds_read_layer_config.m
```

**Next Review Point:** After Phase 1 completion (2 weeks)

---

**Good luck with the implementation!** 🚀

---

**Document Version:** 1.0  
**Author:** WARP AI Agent  
**Date:** October 4, 2025
