function test_ihp_sg13g2_pdk_sets()
% TEST_IHP_SG13G2_PDK_SETS - Comprehensive test suite for IHP SG13G2 PDK test sets
%
% This function tests the GDSII to STEP converter using various complexity levels
% of test files extracted from the IHP-Open-PDK repository.
%
% Test Sets:
%   - Basic: Simple single-layer resistors (3 files)
%   - Intermediate: MOSFET devices and capacitors (3 files) 
%   - Complex: NPN transistor, inductor, RF MOSFET (3 files)
%   - Comprehensive: Multiple complex devices (15 files)
%
% Usage:
%   >> test_ihp_sg13g2_pdk_sets()

fprintf('\n');
fprintf('========================================\n');
fprintf('IHP SG13G2 PDK Test Sets - Comprehensive Suite\n');
fprintf('========================================\n');
fprintf('Generated from: /AI/PDK/IHP-Open-PDK/\n');
fprintf('Date: %s\n', datestr(now));
fprintf('Configuration: LEF-based accurate layer stack\n');
fprintf('\n');

% Add required paths
addpath(genpath('.'));  % Current Export directory
addpath(genpath('../Basic'));  % Basic directory relative to Export

% Configuration files to test
configs = {
    'tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2.json', 'Original Config';
    'tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json', 'LEF-based Accurate Config'
};

% Test sets definition
test_sets = struct();
test_sets.basic = struct('name', 'Basic (Single Layer Resistors)', ...
                        'path', 'tests/fixtures/ihp_sg13g2/pdk_test_sets/basic', ...
                        'description', 'Simple metal resistors on different layers');
                        
test_sets.intermediate = struct('name', 'Intermediate (MOSFET + Capacitor)', ...
                               'path', 'tests/fixtures/ihp_sg13g2/pdk_test_sets/intermediate', ...
                               'description', 'Multi-layer devices with few active layers');
                               
test_sets.complex = struct('name', 'Complex (Full Devices)', ...
                          'path', 'tests/fixtures/ihp_sg13g2/pdk_test_sets/complex', ...
                          'description', 'Complete devices using many layers');
                          
test_sets.comprehensive = struct('name', 'Comprehensive (Multiple Devices)', ...
                                'path', 'tests/fixtures/ihp_sg13g2/pdk_test_sets/comprehensive', ...
                                'description', 'Full range of PDK devices');

% Results tracking
total_tests = 0;
passed_tests = 0;
failed_tests = 0;
results = {};

% Test each configuration
for cfg_idx = 1:length(configs)
    config_file = configs{cfg_idx, 1};
    config_name = configs{cfg_idx, 2};
    
    fprintf('Testing Configuration: %s\n', config_name);
    fprintf('Config file: %s\n', config_file);
    fprintf('----------------------------------------\n');
    
    % Load layer configuration
    try
        cfg = gds_read_layer_config(config_file);
        fprintf('  ✓ Loaded %d layer definitions\n', length(cfg.layers));
    catch ME
        fprintf('  ✗ Failed to load configuration: %s\n', ME.message);
        continue;
    end
    
    % Test each test set
    set_names = fieldnames(test_sets);
    for set_idx = 1:length(set_names)
        set_name = set_names{set_idx};
        test_set = test_sets.(set_name);
        
        fprintf('\n--- Test Set: %s ---\n', test_set.name);
        fprintf('Description: %s\n', test_set.description);
        
        % Get GDS files in test set
        gds_files = dir(fullfile(test_set.path, '*.gds'));
        
        if isempty(gds_files)
            fprintf('  ⚠ No GDS files found in %s\n', test_set.path);
            continue;
        end
        
        fprintf('Found %d GDS files:\n', length(gds_files));
        
        % Test each GDS file
        for file_idx = 1:length(gds_files)
            gds_file = gds_files(file_idx);
            gds_path = fullfile(test_set.path, gds_file.name);
            
            total_tests = total_tests + 1;
            test_name = sprintf('%s_%s_%s', config_name, set_name, gds_file.name);
            
            fprintf('\n  Test %d/%d: %s\n', file_idx, length(gds_files), gds_file.name);
            fprintf('  Size: %.1f KB\n', gds_file.bytes/1024);
            
            try
                % Load GDS file
                tic;
                glib = read_gds_library(gds_path);
                load_time = toc;
                fprintf('    ✓ Load GDS: %.3f sec, %d structures\n', load_time, length(glib.cell));
                
                % Extract layers
                tic;
                layer_data = gds_layer_to_3d(glib, cfg);
                extract_time = toc;
                
                % Count polygons and active layers
                total_polygons = 0;
                active_layers = 0;
                layer_summary = {};
                
                for k = 1:length(layer_data.layers)
                    L = layer_data.layers(k);
                    if L.num_polygons > 0
                        total_polygons = total_polygons + L.num_polygons;
                        active_layers = active_layers + 1;
                        layer_summary{end+1} = sprintf('%s(%d)', L.config.name, L.num_polygons);
                    end
                end
                
                fprintf('    ✓ Extract layers: %.3f sec, %d active layers, %d polygons\n', ...
                        extract_time, active_layers, total_polygons);
                fprintf('      Active layers: %s\n', strjoin(layer_summary, ', '));
                
                % Generate 3D solids
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
                            solids(idx).z_range = [L.config.z_bottom, L.config.z_top];
                        end
                    end
                end
                
                solid_time = toc;
                fprintf('    ✓ Generate 3D: %.3f sec, %d solids\n', solid_time, length(solids));
                
                % Export STL
                output_dir = sprintf('tests/test_output_pdk_%s_%s', strrep(config_name, ' ', '_'), set_name);
                if ~exist(output_dir, 'dir')
                    mkdir(output_dir);
                end
                
                [~, basename, ~] = fileparts(gds_file.name);
                stl_file = fullfile(output_dir, sprintf('%s_3d.stl', basename));
                
                tic;
                gds_write_stl(solids, stl_file);
                export_time = toc;
                
                stl_info = dir(stl_file);
                fprintf('    ✓ Export STL: %.3f sec, %.2f KB\n', export_time, stl_info.bytes/1024);
                fprintf('      Output: %s\n', stl_file);
                
                % Calculate test metrics
                total_time = load_time + extract_time + solid_time + export_time;
                
                % Record success
                passed_tests = passed_tests + 1;
                results{end+1} = struct('test_name', test_name, 'status', 'PASS', ...
                                       'gds_file', gds_path, 'active_layers', active_layers, ...
                                       'total_polygons', total_polygons, 'solids', length(solids), ...
                                       'total_time', total_time, 'output_file', stl_file);
                
                fprintf('    ✅ SUCCESS (%.3f sec total)\n', total_time);
                
            catch ME
                failed_tests = failed_tests + 1;
                fprintf('    ❌ FAILED: %s\n', ME.message);
                if length(ME.stack) > 0
                    fprintf('       at %s:%d\n', ME.stack(1).name, ME.stack(1).line);
                end
                
                results{end+1} = struct('test_name', test_name, 'status', 'FAIL', ...
                                       'gds_file', gds_path, 'error', ME.message);
            end
        end
    end
    
    fprintf('\n');
end

% Print comprehensive summary
fprintf('\n========================================\n');
fprintf('COMPREHENSIVE TEST SUMMARY\n');
fprintf('========================================\n');
fprintf('Total tests:     %d\n', total_tests);
fprintf('Passed:          %d (%.1f%%)\n', passed_tests, 100*passed_tests/total_tests);
fprintf('Failed:          %d (%.1f%%)\n', failed_tests, 100*failed_tests/total_tests);
fprintf('Configurations:  %d\n', length(configs));
fprintf('Test sets:       %d\n', length(set_names));
fprintf('========================================\n');

if failed_tests == 0
    fprintf('✅ ALL TESTS PASSED!\n');
else
    fprintf('⚠️  Some tests failed. Check details above.\n');
    
    % Show failed tests
    fprintf('\nFailed tests:\n');
    for i = 1:length(results)
        if strcmp(results{i}.status, 'FAIL')
            fprintf('  - %s: %s\n', results{i}.test_name, results{i}.error);
        end
    end
end

% Performance analysis
if passed_tests > 0
    fprintf('\nPerformance Analysis (Passed Tests):\n');
    times = [];
    layers_count = [];
    polygons_count = [];
    solids_count = [];
    
    for i = 1:length(results)
        if strcmp(results{i}.status, 'PASS')
            times(end+1) = results{i}.total_time;
            layers_count(end+1) = results{i}.active_layers;
            polygons_count(end+1) = results{i}.total_polygons;
            solids_count(end+1) = results{i}.solids;
        end
    end
    
    fprintf('  Average processing time: %.3f sec\n', mean(times));
    fprintf('  Average active layers:   %.1f\n', mean(layers_count));
    fprintf('  Average polygons:        %.0f\n', mean(polygons_count));
    fprintf('  Average 3D solids:       %.0f\n', mean(solids_count));
    fprintf('  Fastest test:           %.3f sec\n', min(times));
    fprintf('  Slowest test:           %.3f sec\n', max(times));
end

fprintf('\n🔬 Test completed: %s\n', datestr(now));
fprintf('📁 Results saved in tests/test_output_pdk_* directories\n');

end

% Helper function to format file size
function str = format_size(bytes)
    if bytes < 1024
        str = sprintf('%d B', bytes);
    elseif bytes < 1024^2
        str = sprintf('%.1f KB', bytes/1024);
    elseif bytes < 1024^3
        str = sprintf('%.1f MB', bytes/1024^2);
    else
        str = sprintf('%.1f GB', bytes/1024^3);
    end
end