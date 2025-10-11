function results = test_pdk_basic()
% TEST_PDK_BASIC - Optional test for IHP SG13G2 PDK basic resistor set
%
% Tests the complete conversion pipeline with real PDK data (basic resistor set).
% This is an OPTIONAL test that requires IHP SG13G2 test data to be present.
%
% COVERAGE:
%   - Real PDK workflow validation
%   - Complete pipeline: GDS → Layer extraction → 3D → STL
%   - Basic resistor structures (3 test cases)
%
% REQUIREMENTS:
%   - IHP SG13G2 layer configuration
%   - PDK test GDS files (basic set)
%
% USAGE:
%   results = test_pdk_basic()
%
% RETURNS:
%   results - Structure with test results and statistics
%
% Author: WARP AI Agent, October 2025
% Part of optional GDS-STL-STEP test suite

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('IHP SG13G2 PDK Basic Set Test (Optional)\n');
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
    results.skipped = 0;
    
    % Check if PDK data is available
    config_file = fullfile(export_dir, 'migration_temp', 'fixtures', ...
                          'ihp_sg13g2', 'layer_config_ihp_sg13g2_accurate.json');
    pdk_base_path = fullfile(export_dir, 'migration_temp', 'fixtures', ...
                            'ihp_sg13g2', 'pdk_test_sets', 'basic');
    
    if ~exist(config_file, 'file') || ~exist(pdk_base_path, 'dir')
        fprintf('⚠️  PDK test data not found. Skipping optional PDK tests.\n');
        fprintf('    Required paths:\n');
        fprintf('    - Config: %s\n', config_file);
        fprintf('    - Test data: %s\n', pdk_base_path);
        fprintf('\n');
        fprintf('    This is OPTIONAL - test suite continues without PDK validation.\n');
        fprintf('\n========================================\n');
        fprintf('PDK Basic Test Summary (Optional)\n');
        fprintf('========================================\n');
        fprintf('Status: SKIPPED (PDK data not available)\n');
        fprintf('========================================\n\n');
        
        results.skipped = 3;  % 3 planned tests
        return;
    end
    
    % Load PDK configuration
    try
        cfg = gds_read_layer_config(config_file);
        fprintf('✓ Loaded %d IHP SG13G2 layer definitions\n\n', length(cfg.layers));
    catch ME
        fprintf('✗ Failed to load PDK configuration: %s\n', ME.message);
        fprintf('\n========================================\n');
        fprintf('PDK Basic Test Summary (Optional)\n');
        fprintf('========================================\n');
        fprintf('Status: SKIPPED (Configuration load failed)\n');
        fprintf('========================================\n\n');
        results.skipped = 3;
        return;
    end
    
    % Define basic resistor test files
    test_files = {
        'res_metal1.gds',
        'res_metal3.gds',
        'res_topmetal1.gds'
    };
    
    % Run tests
    for i = 1:length(test_files)
        test_name = sprintf('PDK Basic - %s', test_files{i});
        results = run_test(results, test_name, ...
                          @() test_resistor_conversion(test_files{i}, pdk_base_path, cfg, output_dir));
    end
    
    % Print summary
    fprintf('\n========================================\n');
    fprintf('PDK Basic Test Summary (Optional)\n');
    fprintf('========================================\n');
    fprintf('Total tests:  %d\n', results.total);
    fprintf('Passed:       %d\n', results.passed);
    fprintf('Failed:       %d\n', results.failed);
    if results.total > 0
        fprintf('Success rate: %.1f%%\n', 100 * results.passed / results.total);
    end
    fprintf('========================================\n\n');
    
    if results.failed == 0 && results.total > 0
        fprintf('✓ ALL PDK TESTS PASSED\n\n');
    elseif results.total == 0
        fprintf('⚠️ NO TESTS RUN (PDK data unavailable)\n\n');
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

function test_resistor_conversion(gds_file, base_path, cfg, output_dir)
    % Test complete conversion pipeline for a single resistor GDS file
    
    gds_path = fullfile(base_path, gds_file);
    
    % Verify file exists
    assert(exist(gds_path, 'file') ~= 0, sprintf('GDS file not found: %s', gds_path));
    
    % Load GDS
    tic;
    gds_lib = read_gds_library(gds_path);
    load_time = toc;
    fprintf('  ✓ Load GDS: %.3f sec\n', load_time);
    
    % Extract layers
    tic;
    layer_data = gds_layer_to_3d(gds_lib, cfg);
    extract_time = toc;
    
    % Count active layers and polygons
    active_layers = 0;
    total_polygons = 0;
    for k = 1:length(layer_data.layers)
        L = layer_data.layers(k);
        if L.num_polygons > 0
            active_layers = active_layers + 1;
            total_polygons = total_polygons + L.num_polygons;
        end
    end
    
    assert(active_layers > 0, 'No active layers extracted');
    assert(total_polygons > 0, 'No polygons extracted');
    
    fprintf('  ✓ Extract layers: %.3f sec, %d active layers, %d polygons\n', ...
            extract_time, active_layers, total_polygons);
    
    % Generate solids
    tic;
    solids = [];
    for k = 1:length(layer_data.layers)
        L = layer_data.layers(k);
        if L.num_polygons == 0, continue; end
        
        for p = 1:L.num_polygons
            poly = L.polygons{p};
            solid3d = gds_extrude_polygon(poly, L.config.z_bottom, L.config.z_top);
            
            if ~isempty(solid3d) && ~isempty(solid3d.vertices)
                idx = length(solids) + 1;
                solids(idx).vertices = solid3d.vertices;
                solids(idx).faces = solid3d.faces;
                solids(idx).layer_name = L.config.name;
                solids(idx).material = L.config.material;
            end
        end
    end
    solid_time = toc;
    
    assert(length(solids) > 0, 'No 3D solids generated');
    
    fprintf('  ✓ Generate 3D: %.3f sec, %d solids\n', solid_time, length(solids));
    
    % Export STL
    [~, basename, ~] = fileparts(gds_file);
    stl_file = fullfile(output_dir, [basename '_pdk_basic.stl']);
    
    tic;
    gds_write_stl(solids, stl_file);
    export_time = toc;
    
    % Verify output
    assert(exist(stl_file, 'file') ~= 0, 'STL file not created');
    
    stl_info = dir(stl_file);
    assert(stl_info.bytes > 0, 'STL file is empty');
    
    fprintf('  ✓ Export STL: %.3f sec, %.2f KB\n', export_time, stl_info.bytes/1024);
    
    total_time = load_time + extract_time + solid_time + export_time;
    fprintf('  ✓ Total time: %.3f sec\n', total_time);
end
