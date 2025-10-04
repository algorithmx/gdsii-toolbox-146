function test_intermediate_set_only()
% Run tests only on the intermediate set

fprintf('\n========================================\n');
fprintf('IHP SG13G2 PDK Intermediate Set Test\n');
fprintf('========================================\n');

% Change to Export directory and add paths
cd('/home/dabajabaza/Documents/gdsii-toolbox-146/Export');
addpath(genpath('.'));
addpath(genpath('../Basic'));

% Load configuration
cfg = gds_read_layer_config('tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json');
fprintf('✓ Loaded %d layer definitions\n', length(cfg.layers));

% Get test files
test_files = {'sg13_hv_pmos.gds', 'sg13_lv_nmos.gds', 'cap_cmim.gds'};
base_path = 'tests/fixtures/ihp_sg13g2/pdk_test_sets/intermediate';

passed = 0;
failed = 0;

for i = 1:length(test_files)
    fprintf('\n--- Test %d/%d: %s ---\n', i, length(test_files), test_files{i});
    
    gds_path = fullfile(base_path, test_files{i});
    gds_info = dir(gds_path);
    fprintf('  File size: %.1f KB\n', gds_info.bytes/1024);
    
    try
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
        active_layer_names = {};
        for k = 1:length(layer_data.layers)
            L = layer_data.layers(k);
            if L.num_polygons > 0
                active_layers = active_layers + 1;
                total_polygons = total_polygons + L.num_polygons;
                active_layer_names{end+1} = sprintf('%s(%d)', L.config.name, L.num_polygons);
            end
        end
        
        fprintf('  ✓ Extract layers: %.3f sec, %d active layers, %d polygons\n', ...
                extract_time, active_layers, total_polygons);
        fprintf('    Active layers: %s\n', strjoin(active_layer_names, ', '));
        
        % Generate solids (limit for very large files)
        max_solids = min(total_polygons, 1000);  % Cap at 1000 solids for performance
        fprintf('  Generating up to %d solids...\n', max_solids);
        
        tic;
        solids = [];
        solid_count = 0;
        
        for k = 1:length(layer_data.layers)
            L = layer_data.layers(k);
            if L.num_polygons == 0, continue; end
            
            for p = 1:L.num_polygons
                if solid_count >= max_solids
                    break;
                end
                
                poly = L.polygons{p};
                try
                    solid3d = gds_extrude_polygon(poly, L.config.z_bottom, L.config.z_top);
                    
                    if ~isempty(solid3d) && ~isempty(solid3d.vertices)
                        idx = length(solids) + 1;
                        solids(idx).vertices = solid3d.vertices;
                        solids(idx).faces = solid3d.faces;
                        solids(idx).layer_name = L.config.name;
                        solids(idx).material = L.config.material;
                        solid_count = solid_count + 1;
                    end
                catch ME
                    fprintf('    Warning: failed to extrude polygon %d from layer %s: %s\n', ...
                            p, L.config.name, ME.message);
                end
            end
            
            if solid_count >= max_solids
                break;
            end
        end
        
        solid_time = toc;
        fprintf('  ✓ Generate 3D: %.3f sec, %d solids created\n', solid_time, length(solids));
        
        % Export STL
        output_dir = 'tests/test_output_intermediate_only';
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        
        [~, basename, ~] = fileparts(test_files{i});
        stl_file = fullfile(output_dir, [basename '_3d.stl']);
        
        tic;
        gds_write_stl(solids, stl_file);
        export_time = toc;
        
        stl_info = dir(stl_file);
        fprintf('  ✓ Export STL: %.3f sec, %.2f KB\n', export_time, stl_info.bytes/1024);
        
        total_time = load_time + extract_time + solid_time + export_time;
        fprintf('  ✅ SUCCESS (%.3f sec total)\n', total_time);
        passed = passed + 1;
        
    catch ME
        fprintf('  ❌ FAILED: %s\n', ME.message);
        if ~isempty(ME.stack) && length(ME.stack) > 0
            fprintf('     at %s:%d\n', ME.stack(1).name, ME.stack(1).line);
        end
        failed = failed + 1;
    end
end

fprintf('\n========================================\n');
fprintf('Intermediate Set Results\n');
fprintf('========================================\n');
fprintf('Passed: %d/%d\n', passed, length(test_files));
fprintf('Failed: %d/%d\n', failed, length(test_files));
if failed == 0
    fprintf('✅ ALL INTERMEDIATE TESTS PASSED!\n');
else
    fprintf('⚠️ Some tests failed\n');
end
fprintf('========================================\n');

end