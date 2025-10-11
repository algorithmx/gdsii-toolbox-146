%% test_ihp_sg13g2_pdk.m
% Test suite for IHP SG13G2 PDK GDSII files with the GDSII-to-STEP conversion module
%
% This script tests the conversion pipeline using real GDS files from the
% IHP SG13G2 open-source PDK, validating the layer extraction, 3D extrusion,
% and export functionality.
%
% Test files location: tests/fixtures/ihp_sg13g2/
% Layer config: tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2.json
%
% Usage:
%   From Export directory:
%   >> test_ihp_sg13g2_pdk
%
% Author: Test Suite
% Date: 2025-10-04

function test_ihp_sg13g2_pdk()
    fprintf('\n========================================\n');
    fprintf('IHP SG13G2 PDK Test Suite\n');
    fprintf('========================================\n\n');
    
    % Add paths
    script_dir = fileparts(mfilename('fullpath'));
    export_dir = fileparts(script_dir);
    addpath(export_dir);
    addpath(fullfile(export_dir, 'private'));
    
    % Add Basic directory (one level up from Export)
    basic_dir = fullfile(fileparts(export_dir), 'Basic');
    if exist(basic_dir, 'dir')
        addpath(genpath(basic_dir));
    else
        error('Basic directory not found. Ensure gdsii-toolbox is properly installed.');
    end
    
    % Configuration
    fixture_dir = fullfile(script_dir, 'fixtures', 'ihp_sg13g2');
    output_dir = fullfile(script_dir, 'test_output_ihp_sg13g2');
    config_file = fullfile(fixture_dir, 'layer_config_ihp_sg13g2.json');
    
    % Create output directory
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Test files
    test_files = {
        'res_metal1.gds', 'Metal resistor';
        'sg13_hv_nmos.gds', 'HV NMOS transistor';
        'sg13_hv_pmos.gds', 'HV PMOS transistor';
        'npn13G2.gds', 'NPN bipolar transistor'
    };
    
    % Run tests
    total_tests = size(test_files, 1) * 3;  % 3 tests per file
    passed_tests = 0;
    failed_tests = 0;
    
    fprintf('Testing %d GDS files from IHP SG13G2 PDK\n', size(test_files, 1));
    fprintf('Layer config: %s\n\n', config_file);
    
    for i = 1:size(test_files, 1)
        gds_file = test_files{i, 1};
        description = test_files{i, 2};
        gds_path = fullfile(fixture_dir, gds_file);
        
        fprintf('----------------------------------------\n');
        fprintf('Test %d/%d: %s (%s)\n', i, size(test_files, 1), description, gds_file);
        fprintf('----------------------------------------\n');
        
        % Test 1: Load configuration
        [test_pass, cfg] = test_load_config(config_file);
        if test_pass
            passed_tests = passed_tests + 1;
            fprintf('  ✓ Load layer configuration\n');
        else
            failed_tests = failed_tests + 1;
            fprintf('  ✗ Load layer configuration FAILED\n');
            continue;
        end
        
        % Test 2: Extract layers
        [test_pass, layer_data] = test_extract_layers(gds_path, cfg);
        if test_pass
            passed_tests = passed_tests + 1;
            fprintf('  ✓ Extract layers from GDS\n');
        else
            failed_tests = failed_tests + 1;
            fprintf('  ✗ Extract layers FAILED\n');
            continue;
        end
        
        % Test 3: Generate 3D and export
        [test_pass, output_file] = test_export_stl(gds_path, cfg, output_dir, gds_file);
        if test_pass
            passed_tests = passed_tests + 1;
            fprintf('  ✓ Generate 3D and export STL\n');
            fprintf('    Output: %s\n', output_file);
        else
            failed_tests = failed_tests + 1;
            fprintf('  ✗ Export STL FAILED\n');
        end
        
        fprintf('\n');
    end
    
    % Summary
    fprintf('\n========================================\n');
    fprintf('Test Summary\n');
    fprintf('========================================\n');
    fprintf('Total tests:  %d\n', total_tests);
    fprintf('Passed:       %d (%.1f%%)\n', passed_tests, 100*passed_tests/total_tests);
    fprintf('Failed:       %d (%.1f%%)\n', failed_tests, 100*failed_tests/total_tests);
    fprintf('========================================\n\n');
    
    if failed_tests == 0
        fprintf('✓ ALL TESTS PASSED!\n\n');
    else
        fprintf('✗ SOME TESTS FAILED\n\n');
    end
end

%% Test 1: Load Configuration
function [pass, cfg] = test_load_config(config_file)
    pass = false;
    cfg = [];
    
    try
        cfg = gds_read_layer_config(config_file);
        
        % Validate structure
        if ~isstruct(cfg)
            fprintf('    Error: Config is not a struct\n');
            return;
        end
        
        if ~isfield(cfg, 'layers') || ~isfield(cfg, 'metadata')
            fprintf('    Error: Missing required fields\n');
            return;
        end
        
        if length(cfg.layers) == 0
            fprintf('    Error: No layers defined\n');
            return;
        end
        
        fprintf('    Loaded %d layer definitions\n', length(cfg.layers));
        pass = true;
        
    catch ME
        fprintf('    Error: %s\n', ME.message);
    end
end

%% Test 2: Extract Layers
function [pass, layer_data] = test_extract_layers(gds_path, cfg)
    pass = false;
    layer_data = [];
    
    try
        % Read GDS library
        glib = read_gds_library(gds_path);
        
        if isempty(glib)
            fprintf('    Error: Failed to read GDS library\n');
            return;
        end
        
        fprintf('    Loaded GDS: %d structures\n', length(glib));
        
        % Extract layers
        layer_data = gds_layer_to_3d(glib, cfg);
        
        if ~isstruct(layer_data)
            fprintf('    Error: Layer extraction failed\n');
            return;
        end
        
        if ~isfield(layer_data, 'layers')
            fprintf('    Error: Missing layers field\n');
            return;
        end
        
        % Count polygons
        total_polygons = 0;
        layers_with_data = 0;
        for k = 1:length(layer_data.layers)
            if layer_data.layers(k).num_polygons > 0
                layers_with_data = layers_with_data + 1;
                total_polygons = total_polygons + layer_data.layers(k).num_polygons;
            end
        end
        
        fprintf('    Extracted %d layers with %d total polygons\n', ...
                layers_with_data, total_polygons);
        
        if total_polygons == 0
            fprintf('    Warning: No polygons extracted\n');
        end
        
        pass = true;
        
    catch ME
        fprintf('    Error: %s\n', ME.message);
        if exist('OCTAVE_VERSION', 'builtin')
            fprintf('    Stack trace:\n');
            for k = 1:length(ME.stack)
                fprintf('      %s at line %d\n', ME.stack(k).name, ME.stack(k).line);
            end
        end
    end
end

%% Test 3: Export to STL
function [pass, output_file] = test_export_stl(gds_path, cfg, output_dir, gds_filename)
    pass = false;
    [~, base_name, ~] = fileparts(gds_filename);
    output_file = fullfile(output_dir, [base_name '_3d.stl']);
    
    try
        % Read GDS library
        glib = read_gds_library(gds_path);
        
        % Extract layers
        layer_data = gds_layer_to_3d(glib, cfg);
        
        % Generate 3D solids
        solids = struct('vertices', {}, 'faces', {}, 'layer_name', {}, ...
                       'material', {}, 'z_bottom', {}, 'z_top', {});
        
        for k = 1:length(layer_data.layers)
            L = layer_data.layers(k);
            
            if L.num_polygons == 0
                continue;
            end
            
            % Extrude each polygon
            for p = 1:L.num_polygons
                poly = L.polygons{p};
                
                % Skip invalid polygons
                if size(poly, 1) < 3
                    continue;
                end
                
                % Extrude polygon to 3D
                [V, F] = gds_extrude_polygon(poly, L.config.z_bottom, L.config.z_top);
                
                if ~isempty(V) && ~isempty(F)
                    solid_idx = length(solids) + 1;
                    solids(solid_idx).vertices = V;
                    solids(solid_idx).faces = F;
                    solids(solid_idx).layer_name = L.config.name;
                    solids(solid_idx).material = L.config.material;
                    solids(solid_idx).z_bottom = L.config.z_bottom;
                    solids(solid_idx).z_top = L.config.z_top;
                end
            end
        end
        
        if isempty(solids)
            fprintf('    Warning: No solids generated\n');
            return;
        end
        
        fprintf('    Generated %d 3D solids\n', length(solids));
        
        % Write STL file
        gds_write_stl(output_file, solids);
        
        % Verify output file
        if ~exist(output_file, 'file')
            fprintf('    Error: Output file not created\n');
            return;
        end
        
        file_info = dir(output_file);
        fprintf('    STL file size: %.2f KB\n', file_info.bytes/1024);
        
        pass = true;
        
    catch ME
        fprintf('    Error: %s\n', ME.message);
        if exist('OCTAVE_VERSION', 'builtin')
            fprintf('    Stack trace:\n');
            for k = 1:length(ME.stack)
                fprintf('      %s at line %d\n', ME.stack(k).name, ME.stack(k).line);
            end
        end
    end
end
