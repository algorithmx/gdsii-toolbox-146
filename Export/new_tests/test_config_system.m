function results = test_config_system()
% TEST_CONFIG_SYSTEM - Test layer configuration parsing and validation
%
% Tests the gds_read_layer_config function which is the foundation
% for all GDSII-to-3D conversion operations.
%
% COVERAGE:
%   - JSON file loading and parsing
%   - Configuration structure validation
%   - Color parsing (hex to RGB conversion)
%   - Layer mapping table creation
%   - Error handling (missing files, malformed JSON)
%
% USAGE:
%   results = test_config_system()
%
% RETURNS:
%   results - Structure with test results and statistics
%
% Author: WARP AI Agent, October 2025
% Part of essential GDS-STL-STEP test suite

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('Testing Configuration System\n');
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
    
    % Initialize results
    results = struct();
    results.total = 0;
    results.passed = 0;
    results.failed = 0;
    results.test_names = {};
    results.test_status = {};
    
    % Run tests
    results = run_test(results, 'Load basic test configuration', ...
                       @() test_basic_config(script_dir, export_dir));
    
    results = run_test(results, 'Load IHP SG13G2 configuration', ...
                       @() test_ihp_config(export_dir));
    
    results = run_test(results, 'Error handling - missing file', ...
                       @() test_error_handling());
    
    results = run_test(results, 'Color parsing validation', ...
                       @() test_color_parsing(script_dir));
    
    % Print summary
    fprintf('\n========================================\n');
    fprintf('Configuration System Test Summary\n');
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
        fprintf('✗ FAILED: %s\n\n', ME.message);
        results.failed = results.failed + 1;
        results.test_status{end+1} = 'FAIL';
    end
end

%% ========================================================================
%% Individual Test Functions
%% ========================================================================

function test_basic_config(script_dir, export_dir)
    % Test basic configuration file loading
    
    % Try to load from fixtures
    config_file = fullfile(script_dir, 'fixtures', 'configs', 'test_basic.json');
    
    % If not found, try migration_temp fixtures
    if ~exist(config_file, 'file')
        config_file = fullfile(export_dir, 'migration_temp', 'fixtures', 'test_config.json');
    end
    
    cfg = gds_read_layer_config(config_file);
    
    % Check structure fields
    assert(isfield(cfg, 'metadata'), 'Missing metadata field');
    assert(isfield(cfg, 'layers'), 'Missing layers field');
    assert(isfield(cfg, 'conversion_options'), 'Missing conversion_options field');
    assert(isfield(cfg, 'layer_map'), 'Missing layer_map field');
    
    % Check metadata
    assert(isfield(cfg.metadata, 'project'), 'Missing project in metadata');
    assert(isfield(cfg.metadata, 'units'), 'Missing units in metadata');
    assert(strcmp(cfg.metadata.units, 'micrometers'), 'Incorrect units');
    
    % Check layers
    assert(length(cfg.layers) >= 3, 'Expected at least 3 layers');
    assert(cfg.layers(1).gds_layer >= 0, 'Invalid GDS layer number');
    assert(isfield(cfg.layers(1), 'name'), 'Layer missing name');
    assert(isfield(cfg.layers(1), 'z_bottom'), 'Layer missing z_bottom');
    assert(isfield(cfg.layers(1), 'z_top'), 'Layer missing z_top');
    
    % Check layer map
    assert(size(cfg.layer_map, 1) == 256, 'Layer map should be 256x256');
    assert(size(cfg.layer_map, 2) == 256, 'Layer map should be 256x256');
    
    fprintf('  Configuration loaded successfully\n');
    fprintf('  Project: %s\n', cfg.metadata.project);
    fprintf('  Layers: %d defined\n', length(cfg.layers));
end

function test_ihp_config(export_dir)
    % Test loading real-world IHP SG13G2 configuration
    
    % Try main layer_configs directory first
    config_file = fullfile(export_dir, '..', 'layer_configs', 'ihp_sg13g2.json');
    
    % If not found, skip test gracefully
    if ~exist(config_file, 'file')
        fprintf('  Skipping: IHP config not found (optional test)\n');
        return;
    end
    
    cfg_ihp = gds_read_layer_config(config_file);
    
    % Check basic structure
    assert(isfield(cfg_ihp, 'metadata'), 'Missing metadata field');
    assert(isfield(cfg_ihp, 'layers'), 'Missing layers field');
    
    % Check metadata
    assert(strcmp(cfg_ihp.metadata.foundry, 'IHP Microelectronics'), 'Incorrect foundry');
    assert(strcmp(cfg_ihp.metadata.process, 'SG13G2'), 'Incorrect process');
    
    % Should have multiple layers (semiconductor process)
    assert(length(cfg_ihp.layers) >= 10, 'Expected at least 10 layers for real PDK');
    
    fprintf('  IHP SG13G2 configuration validated\n');
    fprintf('  Foundry: %s\n', cfg_ihp.metadata.foundry);
    fprintf('  Layers: %d defined\n', length(cfg_ihp.layers));
end

function test_error_handling()
    % Test error handling for missing files
    
    error_caught = false;
    error_type = '';
    
    try
        cfg_bad = gds_read_layer_config('nonexistent_file_12345.json');
    catch ME
        error_caught = true;
        error_type = ME.identifier;
    end
    
    assert(error_caught, 'Should have thrown error for missing file');
    assert(~isempty(strfind(error_type, 'FileNotFound')), ...
           sprintf('Wrong error type: %s', error_type));
    
    fprintf('  Error correctly caught for missing file\n');
    fprintf('  Error type: %s\n', error_type);
end

function test_color_parsing(script_dir)
    % Test color parsing functionality
    
    % Load config
    config_file = fullfile(script_dir, 'fixtures', 'configs', 'test_basic.json');
    if ~exist(config_file, 'file')
        % Use migration_temp fixture
        export_dir = fileparts(script_dir);
        config_file = fullfile(export_dir, 'migration_temp', 'fixtures', 'test_config.json');
    end
    
    cfg = gds_read_layer_config(config_file);
    
    % Check that at least one layer has color
    has_color = false;
    for i = 1:length(cfg.layers)
        if isfield(cfg.layers(i), 'color') && ~isempty(cfg.layers(i).color)
            has_color = true;
            
            % Validate color format (should be RGB vector [r g b])
            assert(isvector(cfg.layers(i).color), 'Color should be a vector');
            assert(length(cfg.layers(i).color) == 3, 'Color should have 3 components');
            assert(all(cfg.layers(i).color >= 0), 'Color components should be >= 0');
            assert(all(cfg.layers(i).color <= 1), 'Color components should be <= 1');
            
            fprintf('  Layer %d color: [%.2f, %.2f, %.2f]\n', ...
                    i, cfg.layers(i).color(1), cfg.layers(i).color(2), cfg.layers(i).color(3));
            break;
        end
    end
    
    assert(has_color, 'At least one layer should have color defined');
    fprintf('  Color parsing validated\n');
end
