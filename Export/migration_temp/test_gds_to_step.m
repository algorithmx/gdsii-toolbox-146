% test_gds_to_step.m
% Test script for gds_to_step main conversion function
% Tests Section 4.5 of GDS_TO_STEP_IMPLEMENTATION_PLAN.md
%
% This script creates test GDS files and configuration files, then
% validates the complete end-to-end conversion pipeline.

fprintf('\n');
fprintf('====================================================\n');
fprintf('  Testing gds_to_step Main Conversion Function\n');
fprintf('  Section 4.5 Implementation Test\n');
fprintf('====================================================\n\n');

% Add paths
test_dir = fileparts(mfilename('fullpath'));
export_dir = fileparts(test_dir);
toolbox_root = fileparts(export_dir);

% Add all necessary paths
addpath(export_dir);
addpath(genpath(fullfile(toolbox_root, 'Basic')));
addpath(fullfile(toolbox_root, 'Elements'));
addpath(fullfile(toolbox_root, 'Structures'));

fprintf('Path setup complete.\n');

% Create test output directory
output_dir = fullfile(test_dir, 'output');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Track test results
test_count = 0;
pass_count = 0;
fail_count = 0;

%% ========================================================================
%% TEST 1: Basic Conversion - Simple Rectangle
%% ========================================================================

fprintf('TEST 1: Basic Conversion (Simple Rectangle)\n');
fprintf('-------------------------------------------\n');
test_count = test_count + 1;

try
    % Create simple GDS file
    gds_file = fullfile(output_dir, 'test_simple.gds');
    config_file = fullfile(output_dir, 'test_simple_config.json');
    output_stl = fullfile(output_dir, 'test_simple.stl');
    
    % Create GDS library with simple rectangle
    fprintf('  Creating test GDS file...\n');
    lib = gds_library('test_lib');
    struct1 = gds_structure('TopCell');
    
    % Add a boundary element (rectangle)
    rect = gds_element('boundary', 'xy', [0 0; 100 0; 100 50; 0 50; 0 0], ...
                       'layer', 1, 'dtype', 0);
    struct1 = add_element(struct1, rect);
    lib = add_struct(lib, struct1);
    
    write_gds_library(lib, gds_file);
    fprintf('  GDS file created: %s\n', gds_file);
    
    % Create simple layer config
    fprintf('  Creating layer configuration...\n');
    create_simple_config(config_file);
    fprintf('  Config file created: %s\n', config_file);
    
    % Run conversion to STL (no Python dependency)
    fprintf('  Running conversion...\n');
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 1);
    
    % Verify output
    if exist(output_stl, 'file')
        file_info = dir(output_stl);
        fprintf('  ✓ Output file created: %s (%.1f KB)\n', output_stl, file_info.bytes/1024);
        pass_count = pass_count + 1;
        fprintf('  RESULT: PASS\n\n');
    else
        fprintf('  ✗ Output file not created\n');
        fail_count = fail_count + 1;
        fprintf('  RESULT: FAIL\n\n');
    end
    
catch ME
    fprintf('  ✗ Test failed with error: %s\n', ME.message);
    fail_count = fail_count + 1;
    fprintf('  RESULT: FAIL\n\n');
end


%% ========================================================================
%% TEST 2: Multi-Layer Conversion
%% ========================================================================

fprintf('TEST 2: Multi-Layer Conversion\n');
fprintf('------------------------------\n');
test_count = test_count + 1;

try
    % Create multi-layer GDS file
    gds_file = fullfile(output_dir, 'test_multilayer.gds');
    config_file = fullfile(output_dir, 'test_multilayer_config.json');
    output_stl = fullfile(output_dir, 'test_multilayer.stl');
    
    fprintf('  Creating multi-layer GDS file...\n');
    lib = gds_library('test_multilayer_lib');
    struct1 = gds_structure('MultiLayerCell');
    
    % Add boundary elements on different layers
    % Layer 1 - Bottom layer
    rect1 = gds_element('boundary', 'xy', [0 0; 200 0; 200 100; 0 100; 0 0], ...
                        'layer', 1, 'dtype', 0);
    struct1 = add_element(struct1, rect1);
    
    % Layer 10 - Middle layer
    rect2 = gds_element('boundary', 'xy', [20 20; 180 20; 180 80; 20 80; 20 20], ...
                        'layer', 10, 'dtype', 0);
    struct1 = add_element(struct1, rect2);
    
    % Layer 20 - Top layer
    rect3 = gds_element('boundary', 'xy', [40 40; 160 40; 160 60; 40 60; 40 40], ...
                        'layer', 20, 'dtype', 0);
    struct1 = add_element(struct1, rect3);
    
    lib = add_struct(lib, struct1);
    write_gds_library(lib, gds_file);
    fprintf('  GDS file created with 3 layers\n');
    
    % Create multi-layer config
    fprintf('  Creating multi-layer configuration...\n');
    create_multilayer_config(config_file);
    
    % Run conversion
    fprintf('  Running conversion...\n');
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 1);
    
    % Verify output
    if exist(output_stl, 'file')
        file_info = dir(output_stl);
        fprintf('  ✓ Output file created: %s (%.1f KB)\n', output_stl, file_info.bytes/1024);
        pass_count = pass_count + 1;
        fprintf('  RESULT: PASS\n\n');
    else
        fprintf('  ✗ Output file not created\n');
        fail_count = fail_count + 1;
        fprintf('  RESULT: FAIL\n\n');
    end
    
catch ME
    fprintf('  ✗ Test failed with error: %s\n', ME.message);
    fail_count = fail_count + 1;
    fprintf('  RESULT: FAIL\n\n');
end


%% ========================================================================
%% TEST 3: Layer Filtering
%% ========================================================================

fprintf('TEST 3: Layer Filtering\n');
fprintf('-----------------------\n');
test_count = test_count + 1;

try
    % Reuse multi-layer GDS from Test 2
    gds_file = fullfile(output_dir, 'test_multilayer.gds');
    config_file = fullfile(output_dir, 'test_multilayer_config.json');
    output_stl = fullfile(output_dir, 'test_filtered.stl');
    
    fprintf('  Using existing multi-layer GDS file\n');
    fprintf('  Filtering to layer 10 only...\n');
    
    % Run conversion with layer filter
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'layers_filter', [10], ...
                'verbose', 1);
    
    % Verify output
    if exist(output_stl, 'file')
        file_info = dir(output_stl);
        fprintf('  ✓ Filtered output created: %s (%.1f KB)\n', output_stl, file_info.bytes/1024);
        pass_count = pass_count + 1;
        fprintf('  RESULT: PASS\n\n');
    else
        fprintf('  ✗ Output file not created\n');
        fail_count = fail_count + 1;
        fprintf('  RESULT: FAIL\n\n');
    end
    
catch ME
    fprintf('  ✗ Test failed with error: %s\n', ME.message);
    fail_count = fail_count + 1;
    fprintf('  RESULT: FAIL\n\n');
end


%% ========================================================================
%% TEST 4: Window Filtering
%% ========================================================================

fprintf('TEST 4: Window Filtering\n');
fprintf('------------------------\n');
test_count = test_count + 1;

try
    % Reuse multi-layer GDS from Test 2
    gds_file = fullfile(output_dir, 'test_multilayer.gds');
    config_file = fullfile(output_dir, 'test_multilayer_config.json');
    output_stl = fullfile(output_dir, 'test_windowed.stl');
    
    fprintf('  Using existing multi-layer GDS file\n');
    fprintf('  Applying window filter [50 50 150 150]...\n');
    
    % Run conversion with window filter
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'window', [50 50 150 150], ...
                'verbose', 1);
    
    % Verify output
    if exist(output_stl, 'file')
        file_info = dir(output_stl);
        fprintf('  ✓ Windowed output created: %s (%.1f KB)\n', output_stl, file_info.bytes/1024);
        pass_count = pass_count + 1;
        fprintf('  RESULT: PASS\n\n');
    else
        fprintf('  ✗ Output file not created\n');
        fail_count = fail_count + 1;
        fprintf('  RESULT: FAIL\n\n');
    end
    
catch ME
    fprintf('  ✗ Test failed with error: %s\n', ME.message);
    fail_count = fail_count + 1;
    fprintf('  RESULT: FAIL\n\n');
end


%% ========================================================================
%% TEST 5: Verbose Modes
%% ========================================================================

fprintf('TEST 5: Verbose Modes (Silent, Normal, Detailed)\n');
fprintf('------------------------------------------------\n');
test_count = test_count + 1;

try
    gds_file = fullfile(output_dir, 'test_simple.gds');
    config_file = fullfile(output_dir, 'test_simple_config.json');
    
    % Test verbose=0 (silent)
    fprintf('  Testing verbose=0 (silent mode)...\n');
    output_stl = fullfile(output_dir, 'test_verbose0.stl');
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 0);
    fprintf('  ✓ Silent mode completed\n');
    
    % Test verbose=1 (normal)
    fprintf('\n  Testing verbose=1 (normal mode)...\n');
    output_stl = fullfile(output_dir, 'test_verbose1.stl');
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 1);
    fprintf('  ✓ Normal mode completed\n');
    
    % Test verbose=2 (detailed)
    fprintf('\n  Testing verbose=2 (detailed mode)...\n');
    output_stl = fullfile(output_dir, 'test_verbose2.stl');
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 2);
    fprintf('  ✓ Detailed mode completed\n');
    
    pass_count = pass_count + 1;
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ Test failed with error: %s\n', ME.message);
    fail_count = fail_count + 1;
    fprintf('  RESULT: FAIL\n\n');
end


%% ========================================================================
%% TEST 6: Error Handling - Invalid Inputs
%% ========================================================================

fprintf('TEST 6: Error Handling\n');
fprintf('----------------------\n');
test_count = test_count + 1;

try
    error_count = 0;
    
    % Test 6a: Missing input file
    fprintf('  Testing missing input file...\n');
    try
        gds_to_step('nonexistent.gds', 'config.json', 'output.stl');
        fprintf('  ✗ Should have thrown error for missing file\n');
        error_count = error_count + 1;
    catch
        fprintf('  ✓ Correctly caught missing file error\n');
    end
    
    % Test 6b: Missing config file
    fprintf('  Testing missing config file...\n');
    try
        gds_file = fullfile(output_dir, 'test_simple.gds');
        gds_to_step(gds_file, 'nonexistent_config.json', 'output.stl');
        fprintf('  ✗ Should have thrown error for missing config\n');
        error_count = error_count + 1;
    catch
        fprintf('  ✓ Correctly caught missing config error\n');
    end
    
    % Test 6c: Invalid format
    fprintf('  Testing invalid format...\n');
    try
        gds_file = fullfile(output_dir, 'test_simple.gds');
        config_file = fullfile(output_dir, 'test_simple_config.json');
        gds_to_step(gds_file, config_file, 'output.xyz', ...
                    'format', 'invalid_format');
        fprintf('  ✗ Should have thrown error for invalid format\n');
        error_count = error_count + 1;
    catch
        fprintf('  ✓ Correctly caught invalid format error\n');
    end
    
    if error_count == 0
        pass_count = pass_count + 1;
        fprintf('  RESULT: PASS\n\n');
    else
        fail_count = fail_count + 1;
        fprintf('  RESULT: FAIL (%d error handling failures)\n\n', error_count);
    end
    
catch ME
    fprintf('  ✗ Test failed with unexpected error: %s\n', ME.message);
    fail_count = fail_count + 1;
    fprintf('  RESULT: FAIL\n\n');
end


%% ========================================================================
%% TEST 7: Unit Scaling
%% ========================================================================

fprintf('TEST 7: Unit Scaling\n');
fprintf('--------------------\n');
test_count = test_count + 1;

try
    gds_file = fullfile(output_dir, 'test_simple.gds');
    config_file = fullfile(output_dir, 'test_simple_config.json');
    
    % Test different unit scales
    fprintf('  Testing unit scaling factor 1e-6 (nm to m)...\n');
    output_stl = fullfile(output_dir, 'test_scaled.stl');
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'units', 1e-6, ...
                'verbose', 0);
    
    if exist(output_stl, 'file')
        fprintf('  ✓ Scaled output created\n');
        pass_count = pass_count + 1;
        fprintf('  RESULT: PASS\n\n');
    else
        fprintf('  ✗ Output file not created\n');
        fail_count = fail_count + 1;
        fprintf('  RESULT: FAIL\n\n');
    end
    
catch ME
    fprintf('  ✗ Test failed with error: %s\n', ME.message);
    fail_count = fail_count + 1;
    fprintf('  RESULT: FAIL\n\n');
end


%% ========================================================================
%% SUMMARY
%% ========================================================================

fprintf('====================================================\n');
fprintf('  TEST SUMMARY\n');
fprintf('====================================================\n');
fprintf('Total tests:  %d\n', test_count);
fprintf('Passed:       %d\n', pass_count);
fprintf('Failed:       %d\n', fail_count);
fprintf('Success rate: %.1f%%\n', 100 * pass_count / test_count);
fprintf('====================================================\n\n');

if fail_count == 0
    fprintf('✓ ALL TESTS PASSED!\n\n');
else
    fprintf('✗ Some tests failed. Review output above.\n\n');
end


%% ========================================================================
%% HELPER FUNCTIONS
%% ========================================================================

function create_simple_config(filename)
% Create a simple single-layer configuration file

    config = struct();
    config.project = 'Simple Test';
    config.units = 'nanometers';
    
    layer1 = struct();
    layer1.gds_layer = 1;
    layer1.gds_datatype = 0;
    layer1.name = 'layer1';
    layer1.z_bottom = 0;
    layer1.z_top = 100;
    layer1.thickness = 100;
    layer1.material = 'silicon';
    layer1.color = '#808080';
    layer1.enabled = true;
    
    config.layers = layer1;
    
    % Write JSON
    fid = fopen(filename, 'w');
    fprintf(fid, '%s', jsonencode(config));
    fclose(fid);
end


function create_multilayer_config(filename)
% Create a multi-layer configuration file

    config = struct();
    config.project = 'Multi-Layer Test';
    config.units = 'nanometers';
    
    % Layer 1 - Bottom
    layer1 = struct();
    layer1.gds_layer = 1;
    layer1.gds_datatype = 0;
    layer1.name = 'substrate';
    layer1.z_bottom = 0;
    layer1.z_top = 50;
    layer1.thickness = 50;
    layer1.material = 'silicon';
    layer1.color = '#808080';
    layer1.enabled = true;
    
    % Layer 10 - Middle
    layer2 = struct();
    layer2.gds_layer = 10;
    layer2.gds_datatype = 0;
    layer2.name = 'metal1';
    layer2.z_bottom = 50;
    layer2.z_top = 100;
    layer2.thickness = 50;
    layer2.material = 'aluminum';
    layer2.color = '#FF5500';
    layer2.enabled = true;
    
    % Layer 20 - Top
    layer3 = struct();
    layer3.gds_layer = 20;
    layer3.gds_datatype = 0;
    layer3.name = 'metal2';
    layer3.z_bottom = 100;
    layer3.z_top = 150;
    layer3.thickness = 50;
    layer3.material = 'copper';
    layer3.color = '#FF0000';
    layer3.enabled = true;
    
    config.layers = [layer1, layer2, layer3];
    
    % Write JSON
    fid = fopen(filename, 'w');
    fprintf(fid, '%s', jsonencode(config));
    fclose(fid);
end
