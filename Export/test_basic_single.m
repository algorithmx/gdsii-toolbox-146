function test_basic_single()
% Test a single basic case to verify functionality

fprintf('Testing single basic case...\n');

% Ensure we are in the Export directory
cd('/home/dabajabaza/Documents/gdsii-toolbox-146/Export');

% Add paths explicitly 
addpath(genpath('.'));
addpath(genpath('../Basic'));

fprintf('Current directory: %s\n', pwd);
fprintf('Checking paths:\n');

% Test path availability
if exist('gds_read_layer_config', 'file')
    fprintf('  ✓ gds_read_layer_config found\n');
else
    fprintf('  ✗ gds_read_layer_config NOT found\n');
end

if exist('read_gds_library', 'file')  
    fprintf('  ✓ read_gds_library found\n');
else
    fprintf('  ✗ read_gds_library NOT found\n');
end

if exist('gds_layer_to_3d', 'file')
    fprintf('  ✓ gds_layer_to_3d found\n');
else
    fprintf('  ✗ gds_layer_to_3d NOT found\n');
end

% Test configuration loading
try
    cfg = gds_read_layer_config('tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json');
    fprintf('  ✓ Configuration loaded: %d layers\n', length(cfg.layers));
catch ME
    fprintf('  ✗ Configuration load failed: %s\n', ME.message);
    return;
end

% Test GDS file loading
gds_file = 'tests/fixtures/ihp_sg13g2/pdk_test_sets/basic/res_metal1.gds';
try
    glib = read_gds_library(gds_file);
    fprintf('  ✓ GDS file loaded successfully\n');
catch ME
    fprintf('  ✗ GDS file load failed: %s\n', ME.message);
    return;
end

% Test layer extraction
try
    layer_data = gds_layer_to_3d(glib, cfg);
    fprintf('  ✓ Layer extraction successful\n');
    
    % Count active layers
    active_layers = 0;
    total_polygons = 0;
    for k = 1:length(layer_data.layers)
        L = layer_data.layers(k);
        if L.num_polygons > 0
            active_layers = active_layers + 1;
            total_polygons = total_polygons + L.num_polygons;
            fprintf('    Layer %s: %d polygons\n', L.config.name, L.num_polygons);
        end
    end
    fprintf('  Active layers: %d, Total polygons: %d\n', active_layers, total_polygons);
    
catch ME
    fprintf('  ✗ Layer extraction failed: %s\n', ME.message);
    return;
end

% Test 3D solid generation
try
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
    fprintf('  ✓ 3D solid generation: %d solids created\n', length(solids));
    
catch ME
    fprintf('  ✗ 3D solid generation failed: %s\n', ME.message);
    return;
end

% Test STL export
try
    output_dir = 'tests/test_output_basic';
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    stl_file = fullfile(output_dir, 'res_metal1_test.stl');
    gds_write_stl(solids, stl_file);
    
    stl_info = dir(stl_file);
    fprintf('  ✓ STL export successful: %s (%.2f KB)\n', stl_file, stl_info.bytes/1024);
    
catch ME
    fprintf('  ✗ STL export failed: %s\n', ME.message);
    return;
end

fprintf('\n✅ ALL TESTS PASSED! Basic functionality is working correctly.\n');

end