function results = test_basic_pipeline()
% TEST_BASIC_PIPELINE - Test end-to-end conversion pipeline
%
% Tests the complete GDS → STL conversion workflow using gds_to_step.
%
% COVERAGE:
%   - Simple GDS → STL conversion  
%   - Multi-layer stack conversion
%
% USAGE:
%   results = test_basic_pipeline()
%
% RETURNS:
%   results - Structure with test results and statistics
%
% Author: WARP AI Agent, October 2025
% Part of essential GDS-STL-STEP test suite

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('Testing Basic Conversion Pipeline\n');
    fprintf('========================================\n\n');
    
    % Standardized path setup
    script_dir = fileparts(mfilename('fullpath'));
    export_dir = fileparts(script_dir);
    toolbox_root = fileparts(export_dir);
    
    % Add required paths (only if not already in path)
    if isempty(strfind(path, export_dir))
        addpath(export_dir);
    end
    basic_path = fullfile(toolbox_root, 'Basic');
    if isempty(strfind(path, basic_path)) && exist(basic_path, 'dir')
        addpath(genpath(basic_path));
    end
    elements_path = fullfile(toolbox_root, 'Elements');
    if isempty(strfind(path, elements_path)) && exist(elements_path, 'dir')
        addpath(elements_path);
    end
    structures_path = fullfile(toolbox_root, 'Structures');
    if isempty(strfind(path, structures_path)) && exist(structures_path, 'dir')
        addpath(structures_path);
    end
    
    % Create output directory
    output_dir = fullfile(script_dir, 'test_output');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Initialize results
    results = struct();
    results.total = 0;
    results.passed = 0;
    results.failed = 0;
    results.test_names = {};
    results.test_status = {};
    
    % Run tests
    results = run_test(results, 'Simple rectangle GDS → STL', ...
                       @() test_simple_conversion(script_dir, output_dir));
    
    results = run_test(results, 'Multi-layer stack GDS → STL', ...
                       @() test_multilayer_conversion(script_dir, output_dir));
    
    % Print summary
    fprintf('\n========================================\n');
    fprintf('Basic Pipeline Test Summary\n');
    fprintf('========================================\n');
    fprintf('Total tests:  %d\n', results.total);
    fprintf('Passed:       %d\n', results.passed);
    fprintf('Failed:       %d\n', results.failed);
    fprintf('Success rate: %.1f%%\n', 100 * results.passed / results.total);
    fprintf('========================================\n\n');
    
    if results.failed == 0
        fprintf('✓ ALL TESTS PASSED\n\n');
    else
        fprintf('✗ SOME TESTS FAILED\n\n');
    end
end

%% Helper Functions

function results = run_test(results, test_name, test_func)
    fprintf('TEST %d: %s\n', results.total + 1, test_name);
    fprintf('----------------------------------------\n');
    results.total = results.total + 1;
    results.test_names{end+1} = test_name;
    
    try
        test_func();
        fprintf('✓ PASSED\n\n');
        results.passed = results.passed + 1;
        results.test_status{end+1} = 'PASS';
    catch ME
        fprintf('✗ FAILED: %s\n\n', ME.message);
        results.failed = results.failed + 1;
        results.test_status{end+1} = 'FAIL';
    end
end

%% Individual Test Functions

function test_simple_conversion(script_dir, output_dir)
    % Test simple end-to-end conversion
    
    % Create simple GDS file
    gds_file = fullfile(output_dir, 'test_simple.gds');
    config_file = fullfile(script_dir, 'fixtures', 'configs', 'test_basic.json');
    output_stl = fullfile(output_dir, 'test_simple.stl');
    
    % Create GDS library with simple rectangle
    lib = gds_library('test_lib');
    struct1 = gds_structure('TopCell');
    
    % Add a boundary element (rectangle)
    rect = gds_element('boundary', 'xy', [0 0; 100 0; 100 50; 0 50; 0 0], ...
                       'layer', 1, 'dtype', 0);
    struct1 = add_element(struct1, rect);
    lib = add_struct(lib, struct1);
    
    write_gds_library(lib, gds_file);
    
    % Run conversion to STL
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 0);
    
    % Verify output
    assert(exist(output_stl, 'file') ~= 0, 'Output STL not created');
    
    file_info = dir(output_stl);
    assert(file_info.bytes > 0, 'Output STL is empty');
    
    fprintf('  ✓ Simple conversion completed\n');
    fprintf('  Output file: %.2f KB\n', file_info.bytes / 1024);
end

function test_multilayer_conversion(script_dir, output_dir)
    % Test multi-layer conversion
    
    % Create multi-layer GDS file
    gds_file = fullfile(output_dir, 'test_multilayer.gds');
    config_file = fullfile(script_dir, 'fixtures', 'configs', 'test_basic.json');
    output_stl = fullfile(output_dir, 'test_multilayer.stl');
    
    % Create GDS library with multi-layer structure
    lib = gds_library('test_multilayer_lib');
    struct1 = gds_structure('MultiLayerCell');
    
    % Layer 1 - Bottom layer
    rect1 = gds_element('boundary', 'xy', [0 0; 200 0; 200 100; 0 100; 0 0], ...
                        'layer', 1, 'dtype', 0);
    struct1 = add_element(struct1, rect1);
    
    % Layer 2 - Middle layer
    rect2 = gds_element('boundary', 'xy', [20 20; 180 20; 180 80; 20 80; 20 20], ...
                        'layer', 2, 'dtype', 0);
    struct1 = add_element(struct1, rect2);
    
    lib = add_struct(lib, struct1);
    write_gds_library(lib, gds_file);
    
    % Run conversion
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 0);
    
    % Verify output
    assert(exist(output_stl, 'file') ~= 0, 'Multi-layer STL not created');
    
    file_info = dir(output_stl);
    assert(file_info.bytes > 0, 'Multi-layer STL is empty');
    
    fprintf('  ✓ Multi-layer conversion completed\n');
    fprintf('  Layers: 2\n');
    fprintf('  Output file: %.2f KB\n', file_info.bytes / 1024);
end
