function generate_visualization_files()
% GENERATE_VISUALIZATION_FILES - Create both composite and per-layer STL files
%
% This script generates two types of STL outputs for each GDS file:
%   1. COMPOSITE STL - Single file with all layers merged
%   2. SEPARATE STLs - Individual files for each layer
%
% This allows for:
%   - Complete device visualization (composite)
%   - Layer-by-layer inspection (separate)
%   - Selective layer viewing in CAD software

fprintf('\n');
fprintf('========================================\n');
fprintf('3D Visualization File Generator\n');
fprintf('========================================\n');
fprintf('Generating both composite and per-layer STL files\n');
fprintf('Date: %s\n', datestr(now));
fprintf('========================================\n\n');

% Setup paths
cd('/home/dabajabaza/Documents/gdsii-toolbox-146/Export');
addpath(genpath('.'));
addpath(genpath('../Basic'));

% Configuration
config_file = 'tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json';

% Define test cases
test_cases = {
    {'basic', 'res_metal1.gds', 'Metal1 Resistor'};
    {'basic', 'res_metal3.gds', 'Metal3 Resistor'};
    {'intermediate', 'sg13_hv_pmos.gds', 'HV PMOS Transistor'};
    {'intermediate', 'sg13_lv_nmos.gds', 'LV NMOS Transistor'};
    {'intermediate', 'cap_cmim.gds', 'MIM Capacitor'};
};

% Create output directories
output_base = 'tests/visualization_output';
composite_dir = fullfile(output_base, 'composite');
separate_dir = fullfile(output_base, 'by_layer');

if ~exist(composite_dir, 'dir'), mkdir(composite_dir); end
if ~exist(separate_dir, 'dir'), mkdir(separate_dir); end

% Load configuration once
cfg = gds_read_layer_config(config_file);
fprintf('✓ Loaded %d layer definitions\n\n', length(cfg.layers));

% Statistics
total_composite = 0;
total_separate = 0;

% Process each test case
for i = 1:length(test_cases)
    test_set = test_cases{i}{1};
    gds_file = test_cases{i}{2};
    description = test_cases{i}{3};
    
    fprintf('=== [%d/%d] Processing: %s ===\n', i, length(test_cases), description);
    fprintf('    File: %s\n', gds_file);
    
    % Full path to GDS
    gds_path = fullfile('tests/fixtures/ihp_sg13g2/pdk_test_sets', test_set, gds_file);
    [~, basename, ~] = fileparts(gds_file);
    
    try
        tic;
        
        % 1. Load GDS and extract layers
        gds_lib = read_gds_library(gds_path);
        layer_data = gds_layer_to_3d(gds_lib, cfg);
        
        % Count active layers and total polygons
        active_layers = [];
        total_polygons = 0;
        for k = 1:length(layer_data.layers)
            L = layer_data.layers(k);
            if L.num_polygons > 0
                active_layers(end+1).idx = k;
                active_layers(end).data = L;
                total_polygons = total_polygons + L.num_polygons;
            end
        end
        
        fprintf('    Loaded: %d active layers, %d polygons\n', length(active_layers), total_polygons);
        
        % 2. Generate 3D solids
        all_solids = {};  % Use cell array to store structs
        layer_solid_map = struct();  % Track which solids belong to which layer
        
        for k = 1:length(active_layers)
            L = active_layers(k).data;
            layer_name = L.config.name;
            layer_solids = [];
            
            for p = 1:L.num_polygons
                poly = L.polygons{p};
                solid3d = gds_extrude_polygon(poly, L.config.z_bottom, L.config.z_top);
                
                if ~isempty(solid3d) && ~isempty(solid3d.vertices)
                    % Add layer metadata to solid
                    solid3d.layer_name = layer_name;
                    solid3d.material = L.config.material;
                    
                    % Append to cell array
                    all_solids{end+1} = solid3d;
                    layer_solids(end+1) = length(all_solids);
                end
            end
            
            layer_solid_map.(sanitize_field_name(layer_name)) = layer_solids;
        end
        
        fprintf('    Generated: %d 3D solids\n', length(all_solids));
        
        % 3. Export COMPOSITE STL (all layers in one file)
        composite_file = fullfile(composite_dir, [basename '_composite.stl']);
        gds_write_stl(all_solids, composite_file);
        
        composite_info = dir(composite_file);
        fprintf('    ✓ Composite STL: %s (%.1f KB)\n', ...
                [basename '_composite.stl'], composite_info.bytes/1024);
        total_composite = total_composite + 1;
        
        % 4. Export SEPARATE STLs (one per layer)
        layer_dir = fullfile(separate_dir, basename);
        if ~exist(layer_dir, 'dir'), mkdir(layer_dir); end
        
        layer_names = fieldnames(layer_solid_map);
        for k = 1:length(layer_names)
            layer_field = layer_names{k};
            solid_indices = layer_solid_map.(layer_field);
            
            if ~isempty(solid_indices)
                % Get actual layer name (before sanitization)
                layer_name = all_solids{solid_indices(1)}.layer_name;
                
                % Extract solids for this layer (cell array indexing)
                layer_solids = all_solids(solid_indices);
                
                % Export separate STL
                layer_file = fullfile(layer_dir, sprintf('%s_layer_%s.stl', ...
                                     basename, sanitize_filename(layer_name)));
                gds_write_stl(layer_solids, layer_file);
                
                total_separate = total_separate + 1;
            end
        end
        
        fprintf('    ✓ Separate STLs: %d files in %s/\n', ...
                length(layer_names), basename);
        
        elapsed = toc;
        fprintf('    Processing time: %.3f sec\n\n', elapsed);
        
    catch ME
        fprintf('    ❌ FAILED: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('       at %s:%d\n\n', ME.stack(1).name, ME.stack(1).line);
        end
    end
end

% Generate summary
fprintf('========================================\n');
fprintf('Generation Summary\n');
fprintf('========================================\n');
fprintf('Composite files:  %d\n', total_composite);
fprintf('Separate files:   %d\n', total_separate);
fprintf('Total files:      %d\n', total_composite + total_separate);
fprintf('\nOutput locations:\n');
fprintf('  Composite: %s\n', composite_dir);
fprintf('  By Layer:  %s\n', separate_dir);
fprintf('========================================\n');

% Generate index file
create_visualization_index(output_base, test_cases);

fprintf('\n✅ All visualization files generated successfully!\n');
fprintf('📁 Output directory: %s\n', output_base);

end


function field_name = sanitize_field_name(str)
% SANITIZE_FIELD_NAME - Make string valid for struct field name
    field_name = strrep(str, '+', 'plus');
    field_name = strrep(field_name, '-', '_');
    field_name = strrep(field_name, ' ', '_');
    field_name = strrep(field_name, '.', '_');
    % Ensure it starts with a letter
    if ~isempty(field_name) && ~isletter(field_name(1))
        field_name = ['L' field_name];
    end
end


function filename = sanitize_filename(str)
% SANITIZE_FILENAME - Make string valid for filename
    filename = strrep(str, '+', 'plus');
    filename = strrep(filename, '-', '_');
    filename = strrep(filename, ' ', '_');
    filename = strrep(filename, '/', '_');
    filename = strrep(filename, '\', '_');
end


function create_visualization_index(output_base, test_cases)
% CREATE_VISUALIZATION_INDEX - Create HTML/Markdown index of generated files

index_file = fullfile(output_base, 'INDEX.md');
fid = fopen(index_file, 'w');

fprintf(fid, '# 3D Visualization Files Index\n\n');
fprintf(fid, '**Generated**: %s\n\n', datestr(now));
fprintf(fid, '## File Organization\n\n');
fprintf(fid, '### Composite STL Files\n\n');
fprintf(fid, 'Single files containing all layers for each device:\n\n');
fprintf(fid, '| Device | File | Description |\n');
fprintf(fid, '|--------|------|-------------|\n');

for i = 1:length(test_cases)
    [~, basename, ~] = fileparts(test_cases{i}{2});
    description = test_cases{i}{3};
    filename = [basename '_composite.stl'];
    
    filepath = fullfile(output_base, 'composite', filename);
    if exist(filepath, 'file')
        info = dir(filepath);
        fprintf(fid, '| %s | `%s` | %.1f KB |\n', description, filename, info.bytes/1024);
    end
end

fprintf(fid, '\n### Separate Layer Files\n\n');
fprintf(fid, 'Individual STL files for each layer, organized by device:\n\n');

for i = 1:length(test_cases)
    [~, basename, ~] = fileparts(test_cases{i}{2});
    description = test_cases{i}{3};
    
    layer_dir = fullfile(output_base, 'by_layer', basename);
    if exist(layer_dir, 'dir')
        stl_files = dir(fullfile(layer_dir, '*.stl'));
        
        if ~isempty(stl_files)
            fprintf(fid, '#### %s (`%s/`)\n\n', description, basename);
            for j = 1:length(stl_files)
                fprintf(fid, '- `%s` (%.1f KB)\n', stl_files(j).name, stl_files(j).bytes/1024);
            end
            fprintf(fid, '\n');
        end
    end
end

fprintf(fid, '\n## Viewing Recommendations\n\n');
fprintf(fid, '### For Complete Device View\n');
fprintf(fid, 'Use the **composite** files to see the entire device structure.\n\n');
fprintf(fid, '### For Layer-by-Layer Analysis\n');
fprintf(fid, 'Use the **by_layer** files to examine individual layers or selective combinations.\n\n');
fprintf(fid, '### Suggested Viewers\n');
fprintf(fid, '- **FreeCAD**: Open Source, excellent for STL viewing\n');
fprintf(fid, '- **Gmsh**: Mesh visualization and analysis\n');
fprintf(fid, '- **MeshLab**: Advanced mesh processing\n');
fprintf(fid, '- **Online**: https://3dviewer.net/ or https://www.viewstl.com/\n\n');

fprintf(fid, '## Layer Information\n\n');
fprintf(fid, 'All files use accurate Z-heights from IHP SG13G2 LEF data:\n\n');
fprintf(fid, '- Metal1: 0.53-0.93 μm (thickness: 0.40 μm)\n');
fprintf(fid, '- Metal3: 2.43-2.88 μm (thickness: 0.45 μm)\n');
fprintf(fid, '- TopMetal1: 4.16-6.16 μm (thickness: 2.00 μm)\n');
fprintf(fid, '- Active: 0.0-0.40 μm\n');
fprintf(fid, '- GatePoly: 0.40-0.60 μm\n');
fprintf(fid, '- NWell: 0.0-1.5 μm\n\n');

fclose(fid);
fprintf('✓ Created index file: %s\n', index_file);

end