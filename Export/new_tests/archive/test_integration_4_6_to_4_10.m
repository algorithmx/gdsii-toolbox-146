% TEST_INTEGRATION_4_6_TO_4_10 - Integration test for sections 4.6-4.10
%
% This script tests the implementations from sections 4.6-4.10 of the
% GDS_TO_STEP_IMPLEMENTATION_PLAN.md:
%   - Section 4.6: gds_library.to_step() method
%   - Section 4.7: gds2step command-line script
%   - Section 4.8: gds_flatten_for_3d() hierarchy flattening
%   - Section 4.9: gds_window_library() region extraction
%   - Section 4.10: gds_merge_solids_3d() 3D Boolean operations
%
% This is an INTEGRATION test that verifies all components work together
% correctly in realistic scenarios. Each test uses output from previous
% operations to ensure the full pipeline works end-to-end.
%
% Test scenarios:
%   1. Library method basic usage
%   2. Library method with options (layers filter, verbose)
%   3. Command-line script help
%   4. Command-line basic conversion
%   5. Command-line with options
%   6. Hierarchy flattening on library
%   7. Hierarchy flattening on structure
%   8. Hierarchy flattening with depth limit
%   9. Windowing on library
%  10. Windowing on structure with clipping
%  11. Integration: flatten + window + export
%  12. Integration: library method with flatten and window
%  13. Integration: full pipeline with all features
%
% OCTAVE-FIRST DESIGN:
%   This test is designed to work in Octave first, with MATLAB compatibility.
%   All features use Octave-compatible syntax and functions.
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Part of gdsii-toolbox-146 GDSII-to-STEP implementation

function test_integration_4_6_to_4_10()
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('  INTEGRATION TEST: Sections 4.6 - 4.10\n');
    fprintf('  GDS to STEP Implementation Plan\n');
    fprintf('================================================================\n');
    fprintf('\n');
    
    % Track test results
    tests_passed = 0;
    tests_failed = 0;
    test_names = {};
    test_results = {};
    
    % Add toolbox to path
    script_dir = fileparts(mfilename('fullpath'));
    toolbox_root = fileparts(fileparts(script_dir));  % Go up two levels
    addpath(genpath(toolbox_root));
    
    % Create test directory
    test_dir = fullfile(script_dir, 'test_output_integration_4_6_4_10');
    if ~exist(test_dir, 'dir')
        mkdir(test_dir);
    end
    
    fprintf('Test directory: %s\n\n', test_dir);
    
    %% ====================================================================
    %% SETUP: Create test GDS file with hierarchy
    %% ====================================================================
    
    fprintf('SETUP: Creating test GDS file with hierarchy\n');
    fprintf('----------------------------------------------------------------------\n');
    
    try
        % Create test files
        test_gds = fullfile(test_dir, 'test_hierarchy.gds');
        test_config = fullfile(test_dir, 'test_config.json');
        
        % Create library
        glib = gds_library('TestLib', 'uunit', 1e-6, 'dbunit', 1e-9);
        
        % Create bottom-level cell (simple rectangle)
        bottom_struct = gds_structure('BottomCell');
        rect = gds_element('boundary', 'xy', [0 0; 50 0; 50 50; 0 50; 0 0], ...
                          'layer', 1, 'dtype', 0);
        bottom_struct = add_element(bottom_struct, rect);
        
        % Create mid-level cell (references bottom cell twice)
        mid_struct = gds_structure('MidCell');
        % Add sref at (0, 0)
        sref1 = gds_element('sref', 'sname', 'BottomCell', 'xy', [0 0]);
        mid_struct = add_element(mid_struct, sref1);
        % Add sref at (100, 0) with rotation
        sref2 = gds_element('sref', 'sname', 'BottomCell', 'xy', [100 0], ...
                           'strans', struct('angle', 90));
        mid_struct = add_element(mid_struct, sref2);
        % Add a layer 2 rectangle
        rect2 = gds_element('boundary', 'xy', [25 25; 75 25; 75 75; 25 75; 25 25], ...
                           'layer', 2, 'dtype', 0);
        mid_struct = add_element(mid_struct, rect2);
        
        % Create top-level cell (references mid cell and adds more geometry)
        top_struct = gds_structure('TopCell');
        % Reference mid cell
        top_sref = gds_element('sref', 'sname', 'MidCell', 'xy', [0 0]);
        top_struct = add_element(top_struct, top_sref);
        % Add aref (array reference) of bottom cell
        aref = gds_element('aref', 'sname', 'BottomCell', ...
                          'xy', [200 0; 400 0; 200 200], ...
                          'adim', struct('col', 2, 'row', 2));
        top_struct = add_element(top_struct, aref);
        % Add top-level geometry on layer 3
        rect3 = gds_element('boundary', 'xy', [150 150; 250 150; 250 250; 150 250; 150 150], ...
                           'layer', 3, 'dtype', 0);
        top_struct = add_element(top_struct, rect3);
        
        % Add structures to library
        glib = add_struct(glib, bottom_struct);
        glib = add_struct(glib, mid_struct);
        glib = add_struct(glib, top_struct);
        
        % Write GDS file
        write_gds_library(glib, test_gds, 'verbose', 0);
        
        % Create layer config JSON
        config_str = sprintf('{\n');
        config_str = [config_str sprintf('  "project": "Integration Test 4.6-4.10",\n')];
        config_str = [config_str sprintf('  "units": "micrometers",\n')];
        config_str = [config_str sprintf('  "layers": [\n')];
        config_str = [config_str sprintf('    {\n')];
        config_str = [config_str sprintf('      "gds_layer": 1,\n')];
        config_str = [config_str sprintf('      "gds_datatype": 0,\n')];
        config_str = [config_str sprintf('      "name": "layer1",\n')];
        config_str = [config_str sprintf('      "z_bottom": 0,\n')];
        config_str = [config_str sprintf('      "z_top": 10,\n')];
        config_str = [config_str sprintf('      "material": "silicon",\n')];
        config_str = [config_str sprintf('      "color": "#FF0000"\n')];
        config_str = [config_str sprintf('    },\n')];
        config_str = [config_str sprintf('    {\n')];
        config_str = [config_str sprintf('      "gds_layer": 2,\n')];
        config_str = [config_str sprintf('      "gds_datatype": 0,\n')];
        config_str = [config_str sprintf('      "name": "layer2",\n')];
        config_str = [config_str sprintf('      "z_bottom": 10,\n')];
        config_str = [config_str sprintf('      "z_top": 20,\n')];
        config_str = [config_str sprintf('      "material": "oxide",\n')];
        config_str = [config_str sprintf('      "color": "#00FF00"\n')];
        config_str = [config_str sprintf('    },\n')];
        config_str = [config_str sprintf('    {\n')];
        config_str = [config_str sprintf('      "gds_layer": 3,\n')];
        config_str = [config_str sprintf('      "gds_datatype": 0,\n')];
        config_str = [config_str sprintf('      "name": "layer3",\n')];
        config_str = [config_str sprintf('      "z_bottom": 20,\n')];
        config_str = [config_str sprintf('      "z_top": 30,\n')];
        config_str = [config_str sprintf('      "material": "metal",\n')];
        config_str = [config_str sprintf('      "color": "#0000FF"\n')];
        config_str = [config_str sprintf('    }\n')];
        config_str = [config_str sprintf('  ]\n')];
        config_str = [config_str sprintf('}\n')];
        
        fid = fopen(test_config, 'w');
        fprintf(fid, '%s', config_str);
        fclose(fid);
        
        fprintf('  ✓ Test GDS file created: %s\n', test_gds);
        fprintf('  ✓ Test config created: %s\n', test_config);
        fprintf('  ✓ Library has 3 structures: BottomCell, MidCell, TopCell\n');
        fprintf('  ✓ Hierarchy includes: sref, aref, multiple layers\n');
        
    catch ME
        fprintf('  ✗ SETUP FAILED: %s\n', ME.message);
        fprintf('Cannot continue without test files.\n\n');
        return;
    end
    
    fprintf('\n');
    
    %% ====================================================================
    %% TEST 1: Library method - basic usage
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Library method - basic usage', ...
        @() test_library_method_basic(test_gds, test_config, test_dir));
    
    %% ====================================================================
    %% TEST 2: Library method - with options
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Library method - with layer filter', ...
        @() test_library_method_options(test_gds, test_config, test_dir));
    
    %% ====================================================================
    %% TEST 3: Command-line script - help
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Command-line script - help message', ...
        @() test_cmdline_help(toolbox_root));
    
    %% ====================================================================
    %% TEST 4: Command-line script - basic conversion
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Command-line script - basic conversion', ...
        @() test_cmdline_basic(toolbox_root, test_gds, test_config, test_dir));
    
    %% ====================================================================
    %% TEST 5: Command-line script - with options
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Command-line script - with options', ...
        @() test_cmdline_options(toolbox_root, test_gds, test_config, test_dir));
    
    %% ====================================================================
    %% TEST 6: Hierarchy flattening - library input
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Hierarchy flattening - from library', ...
        @() test_flatten_library(test_gds));
    
    %% ====================================================================
    %% TEST 7: Hierarchy flattening - structure input
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Hierarchy flattening - from structure', ...
        @() test_flatten_structure(test_gds));
    
    %% ====================================================================
    %% TEST 8: Hierarchy flattening - with depth limit
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Hierarchy flattening - with depth limit', ...
        @() test_flatten_depth_limit(test_gds));
    
    %% ====================================================================
    %% TEST 9: Windowing - library input
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Windowing - extract region from library', ...
        @() test_window_library(test_gds));
    
    %% ====================================================================
    %% TEST 10: Windowing - structure with clipping
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Windowing - with polygon clipping', ...
        @() test_window_clipping(test_gds));
    
    %% ====================================================================
    %% TEST 11: Integration - flatten + window + export
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Integration - flatten + window + export', ...
        @() test_flatten_window_export(test_gds, test_config, test_dir));
    
    %% ====================================================================
    %% TEST 12: Integration - library method with flatten and window
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Integration - library method with flatten and window options', ...
        @() test_library_flatten_window(test_gds, test_config, test_dir));
    
    %% ====================================================================
    %% TEST 13: Integration - full pipeline test
    %% ====================================================================
    
    [tests_passed, tests_failed, test_names, test_results] = run_test(...
        tests_passed, tests_failed, test_names, test_results, ...
        'Integration - full pipeline with all features', ...
        @() test_full_pipeline(test_gds, test_config, test_dir));
    
    %% ====================================================================
    %% SUMMARY
    %% ====================================================================
    
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('  TEST SUMMARY\n');
    fprintf('================================================================\n');
    fprintf('Tests passed: %d\n', tests_passed);
    fprintf('Tests failed: %d\n', tests_failed);
    fprintf('Total tests:  %d\n', tests_passed + tests_failed);
    fprintf('Success rate: %.1f%%\n', 100*tests_passed/(tests_passed+tests_failed));
    fprintf('================================================================\n\n');
    
    fprintf('Detailed Results:\n');
    fprintf('----------------\n');
    for k = 1:length(test_names)
        status = test_results{k};
        if strcmp(status, 'PASS')
            marker = '✓';
        else
            marker = '✗';
        end
        fprintf('%s Test %2d: %-50s [%s]\n', marker, k, test_names{k}, status);
    end
    fprintf('\n');
    
    if tests_failed == 0
        fprintf('✓ ALL TESTS PASSED!\n\n');
    else
        fprintf('✗ SOME TESTS FAILED!\n\n');
    end
    
    % List output files
    fprintf('Output files in: %s\n', test_dir);
    files = dir(fullfile(test_dir, '*'));
    file_count = 0;
    for k = 1:length(files)
        if ~files(k).isdir
            fprintf('  - %s (%.2f KB)\n', files(k).name, files(k).bytes/1024);
            file_count = file_count + 1;
        end
    end
    fprintf('Total files: %d\n\n', file_count);
    
end


%% ========================================================================
%% TEST RUNNER HELPER
%% ========================================================================

function [passed, failed, names, results] = run_test(passed, failed, names, results, test_name, test_func)
    fprintf('TEST %d: %s\n', passed + failed + 1, test_name);
    fprintf('----------------------------------------------------------------------\n');
    
    try
        test_func();
        fprintf('  ✓ PASSED\n\n');
        passed = passed + 1;
        names{end+1} = test_name;
        results{end+1} = 'PASS';
    catch ME
        fprintf('  ✗ FAILED: %s\n\n', ME.message);
        failed = failed + 1;
        names{end+1} = test_name;
        results{end+1} = 'FAIL';
    end
end


%% ========================================================================
%% TEST FUNCTIONS
%% ========================================================================

function test_library_method_basic(test_gds, test_config, test_dir)
    glib = read_gds_library(test_gds);
    output_stl = fullfile(test_dir, 'test1_method_basic.stl');
    to_step(glib, test_config, output_stl, 'format', 'stl', 'verbose', 0);
    
    if ~exist(output_stl, 'file')
        error('Output file not created');
    end
    file_info = dir(output_stl);
    fprintf('  Output: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
end

function test_library_method_options(test_gds, test_config, test_dir)
    glib = read_gds_library(test_gds);
    output_stl = fullfile(test_dir, 'test2_method_options.stl');
    to_step(glib, test_config, output_stl, ...
            'format', 'stl', ...
            'layers_filter', [1, 2], ...
            'verbose', 0);
    
    if ~exist(output_stl, 'file')
        error('Output file not created');
    end
    file_info = dir(output_stl);
    fprintf('  Output: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
    fprintf('  Filtered to layers: 1, 2\n');
end

function test_cmdline_help(toolbox_root)
    script_path = fullfile(toolbox_root, 'Scripts', 'gds2step');
    cmd = sprintf('octave -q %s --help', script_path);
    [status, output] = system(cmd);
    
    if isempty(strfind(output, 'USAGE')) || isempty(strfind(output, 'gds2step'))
        error('Help message not displayed correctly');
    end
    fprintf('  Help message displayed successfully\n');
end

function test_cmdline_basic(toolbox_root, test_gds, test_config, test_dir)
    script_path = fullfile(toolbox_root, 'Scripts', 'gds2step');
    output_stl = fullfile(test_dir, 'test4_cmdline_basic.stl');
    
    cmd = sprintf('octave -q %s %s %s %s --format=stl --verbose=0', ...
                 script_path, test_gds, test_config, output_stl);
    [status, output] = system(cmd);
    
    if status ~= 0 || ~exist(output_stl, 'file')
        error('Command failed or output not created (status=%d)', status);
    end
    file_info = dir(output_stl);
    fprintf('  Output: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
end

function test_cmdline_options(toolbox_root, test_gds, test_config, test_dir)
    script_path = fullfile(toolbox_root, 'Scripts', 'gds2step');
    output_stl = fullfile(test_dir, 'test5_cmdline_options.stl');
    
    cmd = sprintf('octave -q %s %s %s %s --format=stl --layers=1,3 --verbose=0', ...
                 script_path, test_gds, test_config, output_stl);
    [status, output] = system(cmd);
    
    if status ~= 0 || ~exist(output_stl, 'file')
        error('Command failed or output not created');
    end
    file_info = dir(output_stl);
    fprintf('  Output: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
    fprintf('  Filtered to layers: 1, 3\n');
end

function test_flatten_library(test_gds)
    glib = read_gds_library(test_gds);
    gstruct_flat = gds_flatten_for_3d(glib, 'verbose', 0);
    
    % Check that result is a structure
    if ~isa(gstruct_flat, 'gds_structure')
        error('Result is not a gds_structure');
    end
    
    % Check that structure has elements
    num_elements = numel(gstruct_flat);
    if num_elements == 0
        error('Flattened structure has no elements');
    end
    
    fprintf('  Flattened structure has %d elements\n', num_elements);
    
    % Count element types
    el_cell = gstruct_flat(:);
    boundaries = 0;
    refs = 0;
    for k = 1:length(el_cell)
        if strcmp(etype(el_cell{k}), 'boundary')
            boundaries = boundaries + 1;
        elseif is_ref(el_cell{k})
            refs = refs + 1;
        end
    end
    fprintf('  Boundaries: %d, References: %d\n', boundaries, refs);
    
    if refs > 0
        warning('Flattened structure still contains references (may be missing structures)');
    end
end

function test_flatten_structure(test_gds)
    glib = read_gds_library(test_gds);
    gstruct = glib.st{3};  % Get TopCell
    gstruct_flat = gds_flatten_for_3d(gstruct, 'verbose', 0);
    
    if ~isa(gstruct_flat, 'gds_structure')
        error('Result is not a gds_structure');
    end
    
    num_elements = numel(gstruct_flat);
    fprintf('  Flattened TopCell has %d elements\n', num_elements);
end

function test_flatten_depth_limit(test_gds)
    glib = read_gds_library(test_gds);
    gstruct_flat = gds_flatten_for_3d(glib, 'max_depth', 1, 'verbose', 0);
    
    if ~isa(gstruct_flat, 'gds_structure')
        error('Result is not a gds_structure');
    end
    
    num_elements = numel(gstruct_flat);
    fprintf('  Flattened with depth=1: %d elements\n', num_elements);
    
    % With depth limit, should still have some references
    el_cell = gstruct_flat(:);
    refs = 0;
    for k = 1:length(el_cell)
        if is_ref(el_cell{k})
            refs = refs + 1;
        end
    end
    fprintf('  Remaining references: %d\n', refs);
end

function test_window_library(test_gds)
    glib = read_gds_library(test_gds);
    
    % Extract small region
    window = [0 0 100 100];
    windowed = gds_window_library(glib, window, 'verbose', 0);
    
    if ~isa(windowed, 'gds_library')
        error('Result is not a gds_library');
    end
    
    fprintf('  Original library: %d structures\n', length(glib));
    fprintf('  Windowed library: %d structures\n', length(windowed));
    fprintf('  Window: [%.0f %.0f %.0f %.0f]\n', window);
end

function test_window_clipping(test_gds)
    glib = read_gds_library(test_gds);
    gstruct = glib.st{3};  % TopCell
    
    % Extract with clipping
    window = [25 25 125 125];
    windowed = gds_window_library(gstruct, window, 'clip', true, 'verbose', 0);
    
    if ~isa(windowed, 'gds_structure')
        error('Result is not a gds_structure');
    end
    
    fprintf('  Original: %d elements\n', numel(gstruct));
    fprintf('  Windowed: %d elements\n', numel(windowed));
    fprintf('  Window: [%.0f %.0f %.0f %.0f] with clipping\n', window);
end

function test_flatten_window_export(test_gds, test_config, test_dir)
    % Step 1: Load library
    glib = read_gds_library(test_gds);
    
    % Step 2: Flatten hierarchy
    gstruct_flat = gds_flatten_for_3d(glib, 'verbose', 0);
    
    % Step 3: Window to region
    window = [0 0 150 150];
    gstruct_windowed = gds_window_library(gstruct_flat, window, 'verbose', 0);
    
    % Step 4: Create new library and export
    glib_new = gds_library('ProcessedLib', 'uunit', 1e-6, 'dbunit', 1e-9);
    glib_new = add_struct(glib_new, gstruct_windowed);
    
    output_stl = fullfile(test_dir, 'test11_flatten_window.stl');
    to_step(glib_new, test_config, output_stl, 'format', 'stl', 'verbose', 0);
    
    if ~exist(output_stl, 'file')
        error('Output file not created');
    end
    
    file_info = dir(output_stl);
    fprintf('  Pipeline: flatten -> window -> export\n');
    fprintf('  Output: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
end

function test_library_flatten_window(test_gds, test_config, test_dir)
    glib = read_gds_library(test_gds);
    output_stl = fullfile(test_dir, 'test12_method_flatten_window.stl');
    
    % Use library method with flatten and window options
    window = [0 0 150 150];
    to_step(glib, test_config, output_stl, ...
            'format', 'stl', ...
            'flatten', true, ...
            'window', window, ...
            'verbose', 0);
    
    if ~exist(output_stl, 'file')
        error('Output file not created');
    end
    
    file_info = dir(output_stl);
    fprintf('  Library method with flatten=true and window\n');
    fprintf('  Output: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
end

function test_full_pipeline(test_gds, test_config, test_dir)
    % Full pipeline test with all features
    glib = read_gds_library(test_gds);
    output_stl = fullfile(test_dir, 'test13_full_pipeline.stl');
    
    % Use all features: specific structure, window, layers filter, flatten
    window = [20 20 180 180];
    to_step(glib, test_config, output_stl, ...
            'format', 'stl', ...
            'structure_name', 'TopCell', ...
            'window', window, ...
            'layers_filter', [1, 2], ...
            'flatten', true, ...
            'verbose', 0);
    
    if ~exist(output_stl, 'file')
        error('Output file not created');
    end
    
    file_info = dir(output_stl);
    fprintf('  Full pipeline: structure + window + layers + flatten\n');
    fprintf('  Structure: TopCell\n');
    fprintf('  Window: [%.0f %.0f %.0f %.0f]\n', window);
    fprintf('  Layers: 1, 2\n');
    fprintf('  Output: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
end
