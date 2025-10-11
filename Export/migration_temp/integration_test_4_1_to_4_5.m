% integration_test_4_1_to_4_5.m
% 
% COMPREHENSIVE INTEGRATION TEST SUITE
% Tests complete workflow from Sections 4.1 through 4.5
%
% Tests the complete pipeline:
%   4.1 - Layer Configuration System (gds_read_layer_config)
%   4.2 - Polygon Extraction by Layer (gds_layer_to_3d)
%   4.3 - Basic Extrusion Engine (gds_extrude_polygon)
%   4.4 - STEP/STL Writer Interface (gds_write_step, gds_write_stl)
%   4.5 - Main Conversion Function (gds_to_step)
%
% Date: October 4, 2025

fprintf('\n');
fprintf('================================================================\n');
fprintf('  INTEGRATION TEST SUITE: Sections 4.1 - 4.5\n');
fprintf('  GDS to STEP/STL Conversion Pipeline\n');
fprintf('================================================================\n\n');

% Setup
test_start_time = tic;
test_dir = fileparts(mfilename('fullpath'));
export_dir = fileparts(test_dir);
toolbox_root = fileparts(export_dir);

% Add paths
addpath(export_dir);
addpath(genpath(fullfile(toolbox_root, 'Basic')));
addpath(fullfile(toolbox_root, 'Elements'));
addpath(fullfile(toolbox_root, 'Structures'));

output_dir = fullfile(test_dir, 'output');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Test counters
total_tests = 0;
passed_tests = 0;
failed_tests = 0;
test_results = {};

% Helper function to log test results
function test_results = log_test(test_results, test_name, passed, message)
    result = struct();
    result.name = test_name;
    result.passed = passed;
    result.message = message;
    result.timestamp = datestr(now, 'HH:MM:SS');
    test_results{end+1} = result;
end

%% ========================================================================
%% SECTION 4.1 TESTS: Layer Configuration System
%% ========================================================================

fprintf('┌────────────────────────────────────────────────────────────┐\n');
fprintf('│ SECTION 4.1: Layer Configuration System                   │\n');
fprintf('└────────────────────────────────────────────────────────────┘\n\n');

% Test 4.1.1: Load existing config file
fprintf('TEST 4.1.1: Load layer configuration file\n');
fprintf('------------------------------------------\n');
total_tests = total_tests + 1;

try
    config_file = fullfile(output_dir, 'test_simple_config.json');
    if ~exist(config_file, 'file')
        error('Config file not found. Run setup first.');
    end
    
    config = gds_read_layer_config(config_file);
    
    % Validate structure
    assert(isfield(config, 'metadata'), 'Missing metadata field');
    assert(isfield(config, 'layers'), 'Missing layers field');
    assert(isfield(config, 'layer_map'), 'Missing layer_map field');
    assert(length(config.layers) > 0, 'No layers defined');
    
    fprintf('  ✓ Config loaded: %d layers\n', length(config.layers));
    fprintf('  ✓ Project: %s\n', config.metadata.project);
    fprintf('  ✓ Units: %s\n', config.metadata.units);
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Section 4.1.1', true, 'Config loaded successfully');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.1.1', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

% Test 4.1.2: Validate layer map
fprintf('TEST 4.1.2: Validate layer lookup map\n');
fprintf('--------------------------------------\n');
total_tests = total_tests + 1;

try
    config = gds_read_layer_config(fullfile(output_dir, 'test_simple_config.json'));
    
    % Test layer map access
    layer_idx = config.layers(1).gds_layer + 1;
    dtype_idx = config.layers(1).gds_datatype + 1;
    map_idx = config.layer_map(layer_idx, dtype_idx);
    
    assert(map_idx > 0, 'Layer not found in map');
    assert(map_idx <= length(config.layers), 'Invalid map index');
    
    fprintf('  ✓ Layer map working correctly\n');
    fprintf('  ✓ Layer %d/%d maps to index %d\n', ...
            config.layers(1).gds_layer, config.layers(1).gds_datatype, map_idx);
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Section 4.1.2', true, 'Layer map validated');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.1.2', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

%% ========================================================================
%% SECTION 4.2 TESTS: Polygon Extraction by Layer
%% ========================================================================

fprintf('┌────────────────────────────────────────────────────────────┐\n');
fprintf('│ SECTION 4.2: Polygon Extraction by Layer                  │\n');
fprintf('└────────────────────────────────────────────────────────────┘\n\n');

% Test 4.2.1: Extract polygons from GDS
fprintf('TEST 4.2.1: Extract polygons from GDS library\n');
fprintf('----------------------------------------------\n');
total_tests = total_tests + 1;

try
    gds_file = fullfile(output_dir, 'test_simple.gds');
    config_file = fullfile(output_dir, 'test_simple_config.json');
    
    if ~exist(gds_file, 'file')
        error('GDS file not found. Run setup first.');
    end
    
    glib = read_gds_library(gds_file);
    config = gds_read_layer_config(config_file);
    
    layer_data = gds_layer_to_3d(glib, config, 'flatten', true, 'verbose', 0);
    
    assert(isfield(layer_data, 'layers'), 'Missing layers field');
    assert(isfield(layer_data, 'statistics'), 'Missing statistics field');
    assert(layer_data.statistics.total_polygons > 0, 'No polygons extracted');
    
    fprintf('  ✓ Extracted %d polygons\n', layer_data.statistics.total_polygons);
    fprintf('  ✓ Layers with data: %d\n', length(layer_data.layers));
    fprintf('  ✓ Processing time: %.3f seconds\n', layer_data.statistics.extraction_time);
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Section 4.2.1', true, 'Polygon extraction successful');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.2.1', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

% Test 4.2.2: Validate polygon data structure
fprintf('TEST 4.2.2: Validate extracted polygon data\n');
fprintf('--------------------------------------------\n');
total_tests = total_tests + 1;

try
    gds_file = fullfile(output_dir, 'test_simple.gds');
    config_file = fullfile(output_dir, 'test_simple_config.json');
    
    glib = read_gds_library(gds_file);
    config = gds_read_layer_config(config_file);
    layer_data = gds_layer_to_3d(glib, config, 'flatten', true, 'verbose', 0);
    
    % Validate first layer
    layer = layer_data.layers(1);
    assert(isfield(layer, 'config'), 'Missing config field');
    assert(isfield(layer, 'polygons'), 'Missing polygons field');
    assert(isfield(layer, 'num_polygons'), 'Missing num_polygons field');
    assert(layer.num_polygons == length(layer.polygons), 'Polygon count mismatch');
    
    % Validate first polygon
    poly = layer.polygons{1};
    assert(size(poly, 2) == 2, 'Polygon should be Nx2 matrix');
    assert(size(poly, 1) >= 3, 'Polygon should have at least 3 vertices');
    
    fprintf('  ✓ Layer data structure valid\n');
    fprintf('  ✓ Polygon format: %dx%d matrix\n', size(poly, 1), size(poly, 2));
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Section 4.2.2', true, 'Polygon data validated');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.2.2', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

%% ========================================================================
%% SECTION 4.3 TESTS: Basic Extrusion Engine
%% ========================================================================

fprintf('┌────────────────────────────────────────────────────────────┐\n');
fprintf('│ SECTION 4.3: Basic Extrusion Engine                       │\n');
fprintf('└────────────────────────────────────────────────────────────┘\n\n');

% Test 4.3.1: Extrude simple polygon
fprintf('TEST 4.3.1: Extrude 2D polygon to 3D solid\n');
fprintf('-------------------------------------------\n');
total_tests = total_tests + 1;

try
    % Create test polygon (rectangle)
    poly = [0 0; 100 0; 100 50; 0 50; 0 0];
    z_bottom = 0;
    z_top = 10;
    
    solid = gds_extrude_polygon(poly, z_bottom, z_top);
    
    assert(isfield(solid, 'vertices'), 'Missing vertices field');
    assert(isfield(solid, 'faces'), 'Missing faces field');
    assert(isfield(solid, 'volume'), 'Missing volume field');
    assert(size(solid.vertices, 2) == 3, 'Vertices should be Mx3 matrix');
    
    expected_vertices = 2 * (size(poly, 1) - 1);  % -1 for closed polygon
    assert(solid.num_vertices == expected_vertices, 'Incorrect vertex count');
    
    fprintf('  ✓ Solid created: %d vertices, %d faces\n', ...
            solid.num_vertices, solid.num_faces);
    fprintf('  ✓ Volume: %.2f cubic units\n', solid.volume);
    fprintf('  ✓ Height: %.2f units\n', solid.height);
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Section 4.3.1', true, 'Extrusion successful');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.3.1', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

% Test 4.3.2: Validate solid geometry
fprintf('TEST 4.3.2: Validate extruded solid geometry\n');
fprintf('---------------------------------------------\n');
total_tests = total_tests + 1;

try
    poly = [0 0; 100 0; 100 50; 0 50; 0 0];
    z_bottom = 0;
    z_top = 10;
    
    solid = gds_extrude_polygon(poly, z_bottom, z_top);
    
    % Check bounding box
    assert(length(solid.bbox) == 6, 'BBox should have 6 elements');
    assert(solid.bbox(3) == z_bottom, 'BBox z_min incorrect');
    assert(solid.bbox(6) == z_top, 'BBox z_max incorrect');
    
    % Check volume calculation
    expected_volume = 100 * 50 * 10;  % width * depth * height
    volume_error = abs(solid.volume - expected_volume) / expected_volume;
    assert(volume_error < 0.01, 'Volume calculation error > 1%');
    
    fprintf('  ✓ Bounding box: [%.1f %.1f %.1f %.1f %.1f %.1f]\n', solid.bbox);
    fprintf('  ✓ Volume accuracy: %.2f%% error\n', volume_error * 100);
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Section 4.3.2', true, 'Geometry validated');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.3.2', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

%% ========================================================================
%% SECTION 4.4 TESTS: STEP/STL Writer Interface
%% ========================================================================

fprintf('┌────────────────────────────────────────────────────────────┐\n');
fprintf('│ SECTION 4.4: STEP/STL Writer Interface                    │\n');
fprintf('└────────────────────────────────────────────────────────────┘\n\n');

% Test 4.4.1: Write STL file
fprintf('TEST 4.4.1: Write 3D solid to STL file\n');
fprintf('---------------------------------------\n');
total_tests = total_tests + 1;

try
    % Create test solid
    poly = [0 0; 50 0; 50 25; 0 25; 0 0];
    solid = gds_extrude_polygon(poly, 0, 5);
    
    output_stl = fullfile(output_dir, 'test_4_4_1.stl');
    gds_write_stl(solid, output_stl);
    
    assert(exist(output_stl, 'file') > 0, 'STL file not created');
    
    file_info = dir(output_stl);
    assert(file_info.bytes > 0, 'STL file is empty');
    
    fprintf('  ✓ STL file created: %s\n', output_stl);
    fprintf('  ✓ File size: %.2f KB\n', file_info.bytes / 1024);
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Section 4.4.1', true, 'STL write successful');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.4.1', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

% Test 4.4.2: Write multiple solids to STL
fprintf('TEST 4.4.2: Write multiple solids to single STL\n');
fprintf('------------------------------------------------\n');
total_tests = total_tests + 1;

try
    % Create multiple solids
    solids = {};
    solids{1} = gds_extrude_polygon([0 0; 20 0; 20 20; 0 20; 0 0], 0, 5);
    solids{2} = gds_extrude_polygon([25 0; 45 0; 45 20; 25 20; 25 0], 0, 5);
    
    output_stl = fullfile(output_dir, 'test_4_4_2_multi.stl');
    gds_write_stl(solids, output_stl);
    
    assert(exist(output_stl, 'file') > 0, 'STL file not created');
    
    file_info = dir(output_stl);
    fprintf('  ✓ Multi-solid STL created\n');
    fprintf('  ✓ Solids: %d\n', length(solids));
    fprintf('  ✓ File size: %.2f KB\n', file_info.bytes / 1024);
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Section 4.4.2', true, 'Multi-solid STL successful');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.4.2', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

%% ========================================================================
%% SECTION 4.5 TESTS: Main Conversion Function (End-to-End)
%% ========================================================================

fprintf('┌────────────────────────────────────────────────────────────┐\n');
fprintf('│ SECTION 4.5: Main Conversion Function (End-to-End)        │\n');
fprintf('└────────────────────────────────────────────────────────────┘\n\n');

% Test 4.5.1: Complete pipeline - Simple geometry
fprintf('TEST 4.5.1: Complete conversion pipeline (simple)\n');
fprintf('--------------------------------------------------\n');
total_tests = total_tests + 1;

try
    gds_file = fullfile(output_dir, 'test_simple.gds');
    config_file = fullfile(output_dir, 'test_simple_config.json');
    output_stl = fullfile(output_dir, 'test_4_5_1_complete.stl');
    
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 0);
    
    assert(exist(output_stl, 'file') > 0, 'Output file not created');
    
    file_info = dir(output_stl);
    fprintf('  ✓ Complete pipeline successful\n');
    fprintf('  ✓ Output: %s (%.2f KB)\n', output_stl, file_info.bytes / 1024);
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Section 4.5.1', true, 'End-to-end conversion successful');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.5.1', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

% Test 4.5.2: Multi-layer conversion
fprintf('TEST 4.5.2: Multi-layer conversion pipeline\n');
fprintf('--------------------------------------------\n');
total_tests = total_tests + 1;

try
    gds_file = fullfile(output_dir, 'test_multilayer.gds');
    config_file = fullfile(output_dir, 'test_multilayer_config.json');
    output_stl = fullfile(output_dir, 'test_4_5_2_multilayer.stl');
    
    if ~exist(gds_file, 'file')
        warning('Multi-layer test GDS not found, skipping');
        fprintf('  ⊘ SKIPPED: Test file not available\n\n');
        total_tests = total_tests - 1;
    else
        gds_to_step(gds_file, config_file, output_stl, ...
                    'format', 'stl', ...
                    'verbose', 0);
        
        assert(exist(output_stl, 'file') > 0, 'Output file not created');
        
        file_info = dir(output_stl);
        fprintf('  ✓ Multi-layer conversion successful\n');
        fprintf('  ✓ Output: %.2f KB\n', file_info.bytes / 1024);
        
        passed_tests = passed_tests + 1;
        test_results = log_test(test_results, 'Section 4.5.2', true, 'Multi-layer conversion successful');
        fprintf('  RESULT: PASS\n\n');
    end
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.5.2', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

% Test 4.5.3: Conversion with options (layer filter)
fprintf('TEST 4.5.3: Conversion with layer filtering\n');
fprintf('--------------------------------------------\n');
total_tests = total_tests + 1;

try
    gds_file = fullfile(output_dir, 'test_multilayer.gds');
    config_file = fullfile(output_dir, 'test_multilayer_config.json');
    output_stl = fullfile(output_dir, 'test_4_5_3_filtered.stl');
    
    if ~exist(gds_file, 'file')
        warning('Multi-layer test GDS not found, skipping');
        fprintf('  ⊘ SKIPPED: Test file not available\n\n');
        total_tests = total_tests - 1;
    else
        gds_to_step(gds_file, config_file, output_stl, ...
                    'format', 'stl', ...
                    'layers_filter', [10], ...
                    'verbose', 0);
        
        assert(exist(output_stl, 'file') > 0, 'Output file not created');
        
        fprintf('  ✓ Layer filtering successful\n');
        
        passed_tests = passed_tests + 1;
        test_results = log_test(test_results, 'Section 4.5.3', true, 'Layer filtering successful');
        fprintf('  RESULT: PASS\n\n');
    end
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Section 4.5.3', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

%% ========================================================================
%% INTEGRATION TESTS: Cross-section validation
%% ========================================================================

fprintf('┌────────────────────────────────────────────────────────────┐\n');
fprintf('│ INTEGRATION: Cross-Section Validation                     │\n');
fprintf('└────────────────────────────────────────────────────────────┘\n\n');

% Integration Test 1: Data flow validation
fprintf('INTEGRATION TEST 1: Data flow through pipeline\n');
fprintf('-----------------------------------------------\n');
total_tests = total_tests + 1;

try
    % Trace data through all sections
    gds_file = fullfile(output_dir, 'test_simple.gds');
    config_file = fullfile(output_dir, 'test_simple_config.json');
    
    % Section 4.1
    config = gds_read_layer_config(config_file);
    assert(length(config.layers) > 0, '4.1 failed');
    
    % Section 4.2
    glib = read_gds_library(gds_file);
    layer_data = gds_layer_to_3d(glib, config, 'flatten', true, 'verbose', 0);
    assert(layer_data.statistics.total_polygons > 0, '4.2 failed');
    
    % Section 4.3
    poly = layer_data.layers(1).polygons{1};
    solid = gds_extrude_polygon(poly, ...
                                layer_data.layers(1).config.z_bottom, ...
                                layer_data.layers(1).config.z_top);
    assert(solid.num_vertices > 0, '4.3 failed');
    
    % Section 4.4
    output_stl = fullfile(output_dir, 'test_integration_1.stl');
    gds_write_stl(solid, output_stl);
    assert(exist(output_stl, 'file') > 0, '4.4 failed');
    
    fprintf('  ✓ Data flows correctly through all sections\n');
    fprintf('  ✓ 4.1 → 4.2 → 4.3 → 4.4 validated\n');
    
    passed_tests = passed_tests + 1;
    test_results = log_test(test_results, 'Integration 1', true, 'Data flow validated');
    fprintf('  RESULT: PASS\n\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    failed_tests = failed_tests + 1;
    test_results = log_test(test_results, 'Integration 1', false, ME.message);
    fprintf('  RESULT: FAIL\n\n');
end

%% ========================================================================
%% FINAL SUMMARY
%% ========================================================================

total_time = toc(test_start_time);

fprintf('\n');
fprintf('================================================================\n');
fprintf('  INTEGRATION TEST SUMMARY\n');
fprintf('================================================================\n\n');

fprintf('Time: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('Duration: %.2f seconds\n\n', total_time);

fprintf('Test Results:\n');
fprintf('  Total tests:  %d\n', total_tests);
fprintf('  Passed:       %d (%.1f%%)\n', passed_tests, 100*passed_tests/total_tests);
fprintf('  Failed:       %d (%.1f%%)\n', failed_tests, 100*failed_tests/total_tests);
fprintf('\n');

fprintf('Section Breakdown:\n');
fprintf('  4.1 Layer Configuration:  ');
section_4_1_pass = sum(cellfun(@(x) x.passed && ~isempty(strfind(x.name, '4.1')), test_results));
fprintf('%d/%d tests passed\n', section_4_1_pass, 2);

fprintf('  4.2 Polygon Extraction:   ');
section_4_2_pass = sum(cellfun(@(x) x.passed && ~isempty(strfind(x.name, '4.2')), test_results));
fprintf('%d/%d tests passed\n', section_4_2_pass, 2);

fprintf('  4.3 Extrusion Engine:     ');
section_4_3_pass = sum(cellfun(@(x) x.passed && ~isempty(strfind(x.name, '4.3')), test_results));
fprintf('%d/%d tests passed\n', section_4_3_pass, 2);

fprintf('  4.4 STEP/STL Writers:     ');
section_4_4_pass = sum(cellfun(@(x) x.passed && ~isempty(strfind(x.name, '4.4')), test_results));
fprintf('%d/%d tests passed\n', section_4_4_pass, 2);

fprintf('  4.5 Main Conversion:      ');
section_4_5_pass = sum(cellfun(@(x) x.passed && ~isempty(strfind(x.name, '4.5')), test_results));
fprintf('%d/3 tests passed\n', section_4_5_pass);

fprintf('\n');

% Final verdict
if failed_tests == 0
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                                                            ║\n');
    fprintf('║              ✓ ALL INTEGRATION TESTS PASSED!               ║\n');
    fprintf('║                                                            ║\n');
    fprintf('║   Sections 4.1 - 4.5 are fully integrated and working!    ║\n');
    fprintf('║                                                            ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
else
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                                                            ║\n');
    fprintf('║         ⚠ SOME INTEGRATION TESTS FAILED                    ║\n');
    fprintf('║                                                            ║\n');
    fprintf('║   Review failed tests above for details.                  ║\n');
    fprintf('║                                                            ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    
    fprintf('\nFailed Tests:\n');
    for i = 1:length(test_results)
        if ~test_results{i}.passed
            fprintf('  - %s: %s\n', test_results{i}.name, test_results{i}.message);
        end
    end
end

fprintf('\n');
fprintf('Test output directory: %s\n', output_dir);
fprintf('\n');

fprintf('================================================================\n');
fprintf('  Integration testing complete\n');
fprintf('================================================================\n\n');
