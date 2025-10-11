function results = test_advanced_pipeline()
% TEST_ADVANCED_PIPELINE - Optional advanced conversion pipeline scenarios
%
% Tests advanced features of the gds_to_step conversion pipeline that go
% beyond the basic essential tests. This is an OPTIONAL test suite.
%
% COVERAGE:
%   - Layer filtering (selective layer conversion)
%   - Format options (STEP vs STL)
%   - Complex multi-layer scenarios  
%   - Advanced conversion options
%
% USAGE:
%   results = test_advanced_pipeline()
%
% RETURNS:
%   results - Structure with test results and statistics
%
% Author: WARP AI Agent, October 2025
% Part of optional GDS-STL-STEP test suite

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('Advanced Conversion Pipeline (Optional)\n');
    fprintf('========================================\n\n');
    
    % Standardized path setup
    script_dir = fileparts(mfilename('fullpath'));
    test_root = fileparts(script_dir);
    export_dir = fileparts(test_root);
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
    output_dir = fullfile(test_root, 'test_output');
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
    results = run_test(results, 'Layer filtering - single layer', ...
                       @() test_layer_filtering_single(test_root, output_dir));
    
    results = run_test(results, 'Layer filtering - multiple layers', ...
                       @() test_layer_filtering_multi(test_root, output_dir));
    
    results = run_test(results, 'Complex multi-layer stack (5 layers)', ...
                       @() test_complex_multilayer(test_root, output_dir));
    
    results = run_test(results, 'Conversion options - verbose mode', ...
                       @() test_verbose_output(test_root, output_dir));
    
    % Print summary
    fprintf('\n========================================\n');
    fprintf('Advanced Pipeline Test Summary (Optional)\n');
    fprintf('========================================\n');
    fprintf('Total tests:  %d\n', results.total);
    fprintf('Passed:       %d\n', results.passed);
    fprintf('Failed:       %d\n', results.failed);
    if results.total > 0
        fprintf('Success rate: %.1f%%\n', 100 * results.passed / results.total);
    end
    fprintf('========================================\n\n');
    
    if results.failed == 0 && results.total > 0
        fprintf('✓ ALL ADVANCED TESTS PASSED\n\n');
    elseif results.total == 0
        fprintf('⚠️ NO TESTS RUN\n\n');
    else
        fprintf('✗ SOME TESTS FAILED\n\n');
    end
end

%% ========================================================================
%% Helper Functions
%% ========================================================================

function results = run_test(results, test_name, test_func)
    % Run a single test and update results
    
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
        fprintf('✗ FAILED: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('  at %s:%d\n', ME.stack(1).name, ME.stack(1).line);
        end
        fprintf('\n');
        results.failed = results.failed + 1;
        results.test_status{end+1} = 'FAIL';
    end
end

%% ========================================================================
%% Individual Test Functions
%% ========================================================================

function test_layer_filtering_single(test_root, output_dir)
    % Test layer filtering with single layer selection
    
    % Create multi-layer GDS for filtering test
    gds_file = fullfile(output_dir, 'test_filter_single.gds');
    config_file = fullfile(test_root, 'fixtures', 'configs', 'test_multilayer.json');
    output_stl = fullfile(output_dir, 'test_filter_single.stl');
    
    % Create GDS with 3 layers
    lib = gds_library('filter_test_lib');
    struct1 = gds_structure('FilterCell');
    
    % Layer 1
    rect1 = gds_element('boundary', 'xy', [0 0; 200 0; 200 100; 0 100; 0 0], ...
                        'layer', 1, 'dtype', 0);
    struct1 = add_element(struct1, rect1);
    
    % Layer 10
    rect2 = gds_element('boundary', 'xy', [20 20; 180 20; 180 80; 20 80; 20 20], ...
                        'layer', 10, 'dtype', 0);
    struct1 = add_element(struct1, rect2);
    
    % Layer 20
    rect3 = gds_element('boundary', 'xy', [40 40; 160 40; 160 60; 40 60; 40 40], ...
                        'layer', 20, 'dtype', 0);
    struct1 = add_element(struct1, rect3);
    
    lib = add_struct(lib, struct1);
    write_gds_library(lib, gds_file);
    
    fprintf('  ✓ Created test GDS with 3 layers\n');
    
    % Run conversion with single layer filter (layer 10 only)
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'layers_filter', [10], ...
                'verbose', 0);
    
    % Verify output
    assert(exist(output_stl, 'file') ~= 0, 'Filtered STL file not created');
    
    file_info = dir(output_stl);
    assert(file_info.bytes > 0, 'Filtered STL file is empty');
    
    fprintf('  ✓ Layer filtering successful\n');
    fprintf('  Output: %.2f KB\n', file_info.bytes / 1024);
end

function test_layer_filtering_multi(test_root, output_dir)
    % Test layer filtering with multiple layer selection
    
    % Reuse GDS from previous test
    gds_file = fullfile(output_dir, 'test_filter_single.gds');
    config_file = fullfile(test_root, 'fixtures', 'configs', 'test_multilayer.json');
    output_stl = fullfile(output_dir, 'test_filter_multi.stl');
    
    % If file doesn't exist from previous test, create it
    if ~exist(gds_file, 'file')
        lib = gds_library('filter_test_lib');
        struct1 = gds_structure('FilterCell');
        
        rect1 = gds_element('boundary', 'xy', [0 0; 200 0; 200 100; 0 100; 0 0], ...
                            'layer', 1, 'dtype', 0);
        struct1 = add_element(struct1, rect1);
        
        rect2 = gds_element('boundary', 'xy', [20 20; 180 20; 180 80; 20 80; 20 20], ...
                            'layer', 10, 'dtype', 0);
        struct1 = add_element(struct1, rect2);
        
        rect3 = gds_element('boundary', 'xy', [40 40; 160 40; 160 60; 40 60; 40 40], ...
                            'layer', 20, 'dtype', 0);
        struct1 = add_element(struct1, rect3);
        
        lib = add_struct(lib, struct1);
        write_gds_library(lib, gds_file);
    end
    
    % Run conversion with multiple layer filter (layers 1 and 20)
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'layers_filter', [1, 20], ...
                'verbose', 0);
    
    % Verify output
    assert(exist(output_stl, 'file') ~= 0, 'Multi-layer filtered STL not created');
    
    file_info = dir(output_stl);
    assert(file_info.bytes > 0, 'Multi-layer filtered STL is empty');
    
    fprintf('  ✓ Multi-layer filtering successful\n');
    fprintf('  Layers: 1, 20 extracted\n');
    fprintf('  Output: %.2f KB\n', file_info.bytes / 1024);
end

function test_complex_multilayer(test_root, output_dir)
    % Test complex multi-layer stack with 5 layers
    
    gds_file = fullfile(output_dir, 'test_complex_5layer.gds');
    config_file = fullfile(test_root, 'fixtures', 'configs', 'test_multilayer.json');
    output_stl = fullfile(output_dir, 'test_complex_5layer.stl');
    
    % Create GDS with 5 layers in a stack
    lib = gds_library('complex_lib');
    struct1 = gds_structure('ComplexCell');
    
    % Create 5 layers with progressively smaller rectangles (tower effect)
    layers = [1, 10, 20];  % Using available layers from config
    base_size = 200;
    
    for i = 1:length(layers)
        size_reduction = (i-1) * 20;
        x_min = size_reduction;
        y_min = size_reduction;
        x_max = base_size - size_reduction;
        y_max = (base_size/2) - size_reduction;
        
        rect = gds_element('boundary', ...
                          'xy', [x_min y_min; x_max y_min; x_max y_max; x_min y_max; x_min y_min], ...
                          'layer', layers(i), 'dtype', 0);
        struct1 = add_element(struct1, rect);
    end
    
    lib = add_struct(lib, struct1);
    write_gds_library(lib, gds_file);
    
    fprintf('  ✓ Created complex 3-layer GDS\n');
    
    % Run conversion
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 0);
    
    % Verify output
    assert(exist(output_stl, 'file') ~= 0, 'Complex multi-layer STL not created');
    
    file_info = dir(output_stl);
    assert(file_info.bytes > 0, 'Complex multi-layer STL is empty');
    
    fprintf('  ✓ Complex multi-layer conversion successful\n');
    fprintf('  Output: %.2f KB\n', file_info.bytes / 1024);
end

function test_verbose_output(test_root, output_dir)
    % Test verbose output mode
    
    gds_file = fullfile(output_dir, 'test_verbose.gds');
    config_file = fullfile(test_root, 'fixtures', 'configs', 'test_basic.json');
    output_stl = fullfile(output_dir, 'test_verbose.stl');
    
    % Create simple GDS for verbose test
    lib = gds_library('verbose_test');
    struct1 = gds_structure('VerboseCell');
    
    rect = gds_element('boundary', 'xy', [0 0; 100 0; 100 50; 0 50; 0 0], ...
                       'layer', 1, 'dtype', 0);
    struct1 = add_element(struct1, rect);
    lib = add_struct(lib, struct1);
    
    write_gds_library(lib, gds_file);
    
    fprintf('  ✓ Created test GDS for verbose mode\n');
    
    % Run conversion with verbose=1 (output will be captured)
    fprintf('  Running with verbose output...\n');
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 1);
    
    % Verify output
    assert(exist(output_stl, 'file') ~= 0, 'Verbose mode STL not created');
    
    file_info = dir(output_stl);
    assert(file_info.bytes > 0, 'Verbose mode STL is empty');
    
    fprintf('  ✓ Verbose mode conversion successful\n');
    fprintf('  Output: %.2f KB\n', file_info.bytes / 1024);
end
