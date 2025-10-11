function results = test_layer_extraction()
% TEST_LAYER_EXTRACTION - Test GDS layer extraction
%
% Tests the gds_layer_to_3d function which extracts polygon data from
% GDSII structures organized by layer for 3D conversion.
%
% COVERAGE:
%   - GDS structure creation
%   - Layer-by-layer polygon extraction
%   - Layer filtering (enabled layers only)
%
% USAGE:
%   results = test_layer_extraction()
%
% RETURNS:
%   results - Structure with test results and statistics
%
% Author: WARP AI Agent, October 2025
% Part of essential GDS-STL-STEP test suite

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('Testing Layer Extraction\n');
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
    
    % Initialize results
    results = struct();
    results.total = 0;
    results.passed = 0;
    results.failed = 0;
    results.test_names = {};
    results.test_status = {};
    
    % Run tests
    results = run_test(results, 'GDS structure creation', ...
                       @() test_gds_creation());
    
    results = run_test(results, 'Layer extraction', ...
                       @() test_extraction(script_dir, export_dir));
    
    results = run_test(results, 'Layer filtering', ...
                       @() test_filtering(script_dir, export_dir));
    
    % Print summary
    fprintf('\n========================================\n');
    fprintf('Layer Extraction Test Summary\n');
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

function test_gds_creation()
    % Test GDS structure creation
    
    % Create simple test geometry
    rect1 = [0 0; 10 0; 10 10; 0 10; 0 0];
    elem1 = gds_element('boundary', 'xy', rect1, 'layer', 1, 'dtype', 0);
    
    rect2 = [5 5; 15 5; 15 15; 5 15; 5 5];
    elem2 = gds_element('boundary', 'xy', rect2, 'layer', 2, 'dtype', 0);
    
    % Create structure
    test_struct = gds_structure('TestStruct', elem1, elem2);
    
    % Create library
    test_lib = gds_library('TestLib', test_struct);
    
    assert(~isempty(test_lib), 'Library creation failed');
    fprintf('  ✓ GDS library created successfully\n');
    fprintf('  ✓ 2 boundary elements added\n');
end

function test_extraction(script_dir, export_dir)
    % Test layer extraction
    
    % Create test structure
    rect1 = [0 0; 10 0; 10 10; 0 10; 0 0];
    elem1 = gds_element('boundary', 'xy', rect1, 'layer', 1, 'dtype', 0);
    
    rect2 = [5 5; 15 5; 15 15; 5 15; 5 5];
    elem2 = gds_element('boundary', 'xy', rect2, 'layer', 2, 'dtype', 0);
    
    test_struct = gds_structure('TestStruct', elem1, elem2);
    
    % Load config
    config_file = fullfile(script_dir, 'fixtures', 'configs', 'test_basic.json');
    if ~exist(config_file, 'file')
        config_file = fullfile(export_dir, 'migration_temp', 'fixtures', 'test_config.json');
    end
    cfg = gds_read_layer_config(config_file);
    
    % Extract layers
    layer_data = gds_layer_to_3d(test_struct, cfg);
    
    assert(isfield(layer_data, 'metadata'), 'Missing metadata');
    assert(isfield(layer_data, 'layers'), 'Missing layers');
    assert(isfield(layer_data, 'statistics'), 'Missing statistics');
    
    fprintf('  ✓ Layer data structure valid\n');
    fprintf('  Extracted layers: %d\n', length(layer_data.layers));
    fprintf('  Total polygons: %d\n', layer_data.statistics.total_polygons);
end

function test_filtering(script_dir, export_dir)
    % Test enabled-only layer filtering
    
    % Create structure with multiple layers
    rect1 = [0 0; 10 0; 10 10; 0 10; 0 0];
    elem1 = gds_element('boundary', 'xy', rect1, 'layer', 1, 'dtype', 0);
    
    rect2 = [5 5; 15 5; 15 15; 5 15; 5 5];
    elem2 = gds_element('boundary', 'xy', rect2, 'layer', 2, 'dtype', 0);
    
    rect3 = [12 12; 20 12; 20 20; 12 20; 12 12];
    elem3 = gds_element('boundary', 'xy', rect3, 'layer', 3, 'dtype', 0);
    
    test_struct = gds_structure('TestStruct', elem1, elem2, elem3);
    
    % Load config (layer 3 should be disabled)
    config_file = fullfile(script_dir, 'fixtures', 'configs', 'test_basic.json');
    if ~exist(config_file, 'file')
        config_file = fullfile(export_dir, 'migration_temp', 'fixtures', 'test_config.json');
    end
    cfg = gds_read_layer_config(config_file);
    
    % Extract with enabled_only filtering (default)
    layer_data = gds_layer_to_3d(test_struct, cfg, 'enabled_only', true);
    
    % Should only extract enabled layers (1 and 2, not 3)
    assert(length(layer_data.layers) == 2, ...
           sprintf('Expected 2 layers (3 disabled), got %d', length(layer_data.layers)));
    
    fprintf('  ✓ Layer filtering works correctly\n');
    fprintf('  Enabled layers extracted: %d\n', length(layer_data.layers));
    fprintf('  Disabled layers skipped: 1\n');
end
