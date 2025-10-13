% pdk_converter_examples.m - Examples of using the PDK to layer configuration converters
%
% This script demonstrates various ways to use the LYP/LYT and universal PDK
% converters to create layer configuration files for GDSII-to-STEP conversion.

fprintf('=== PDK Converter Examples ===\n\n');

% Add necessary paths
addpath(fileparts(mfilename('fullpath')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

%% Example 1: Basic LYP/LYT conversion
fprintf('Example 1: Basic LYP/LYT conversion\n');
fprintf('--------------------------------\n');

% This example shows how to convert KLayout LYP and LYT files
% to a layer configuration JSON file.

try
    % Note: Replace these paths with your actual files
    lyp_file = 'sg13g2.lyp';    % KLayout layer properties file
    lyt_file = 'sg13g2.lyt';    % KLayout layer technology file

    if exist(lyp_file, 'file') && exist(lyt_file, 'file')
        config = gds_convert_lyp_lyt_to_config(lyp_file, lyt_file, ...
                                              'output_file', 'layer_config_sg13g2.json', ...
                                              'project_name', 'IHP SG13G2 Process', ...
                                              'units', 'micrometers', ...
                                              'foundry', 'IHP', ...
                                              'process', 'SG13G2', ...
                                              'verbose', true);

        fprintf('✓ Successfully converted LYP/LYT files\n');
        fprintf('  Layers processed: %d\n', length(config.layers));
        fprintf('  Output file: layer_config_sg13g2.json\n');
    else
        fprintf('⚠ LYP/LYT files not found, skipping this example\n');
    end
catch ME
    fprintf('✗ Error in Example 1: %s\n', ME.message);
end

fprintf('\n');

%% Example 2: Universal PDK converter with multiple sources
fprintf('Example 2: Universal PDK converter\n');
fprintf('----------------------------------\n');

% This example shows how to use the universal converter with multiple
% input formats from different PDK sources.

try
    % Define input files from various sources
    input_files = struct();
    input_files.lyp_file = 'tech.lyp';      % KLayout layer properties
    input_files.lef_file = 'tech.lef';      % LEF technology file
    input_files.map_file = 'layers.map';    % GDSII layer mapping
    input_files.csv_file = 'layers.csv';    % Tabular layer data
    input_files.xs_file = 'process.xs';     % Cross-section script

    % Count available files
    available_files = 0;
    available_names = {};
    fields = fieldnames(input_files);
    for i = 1:length(fields)
        if exist(input_files.(fields{i}), 'file')
            available_files = available_files + 1;
            available_names{end+1} = fields{i};
        end
    end

    if available_files > 0
        fprintf('Found %d input files: %s\n', available_files, strjoin(available_names, ', '));

        % Prepare arguments for the converter
        args = {};
        for i = 1:length(fields)
            if exist(input_files.(fields{i}), 'file')
                args{end+1} = fields{i};
                args{end+1} = input_files.(fields{i});
            end
        end

        % Add output and project parameters
        args{end+1} = 'output_file';
        args{end+1} = 'layer_config_universal.json';
        args{end+1} = 'project_name';
        args{end+1} = 'Multi-Source PDK';
        args{end+1} = 'verbose';
        args{end+1} = true;

        % Call the converter
        config = gds_convert_pdk_to_config(args{:});

        fprintf('✓ Successfully converted multiple PDK sources\n');
        fprintf('  Layers processed: %d\n', length(config.layers));
        fprintf('  Output file: layer_config_universal.json\n');

        % Display summary of layers
        fprintf('  Layer summary:\n');
        for i = 1:min(5, length(config.layers))
            layer = config.layers(i);
            fprintf('    %s: GDS %d/%d, thickness %.3f μm\n', ...
                    layer.name, layer.gds_layer, layer.gds_datatype, layer.thickness);
        end
        if length(config.layers) > 5
            fprintf('    ... and %d more layers\n', length(config.layers) - 5);
        end
    else
        fprintf('⚠ No input files found, skipping this example\n');
    end
catch ME
    fprintf('✗ Error in Example 2: %s\n', ME.message);
end

fprintf('\n');

%% Example 3: Convert only LEF technology file
fprintf('Example 3: LEF technology file conversion\n');
fprintf('----------------------------------------\n');

try
    lef_file = 'tech.lef';

    if exist(lef_file, 'file')
        config = gds_convert_pdk_to_config('lef_file', lef_file, ...
                                          'output_file', 'layer_config_from_lef.json', ...
                                          'project_name', 'LEF Technology', ...
                                          'verbose', true);

        fprintf('✓ Successfully converted LEF file\n');
        fprintf('  Layers processed: %d\n', length(config.layers));

        % Analyze layer types
        routing_layers = 0;
        cut_layers = 0;
        for i = 1:length(config.layers)
            if contains(lower(config.layers(i).name), 'metal')
                routing_layers = routing_layers + 1;
            elseif contains(lower(config.layers(i).name), 'via')
                cut_layers = cut_layers + 1;
            end
        end
        fprintf('  Routing layers: %d\n', routing_layers);
        fprintf('  Cut layers: %d\n', cut_layers);
    else
        fprintf('⚠ LEF file not found, skipping this example\n');
    end
catch ME
    fprintf('✗ Error in Example 3: %s\n', ME.message);
end

fprintf('\n');

%% Example 4: Create custom layer configuration from CSV
fprintf('Example 4: CSV-based layer configuration\n');
fprintf('---------------------------------------\n');

try
    % Create a sample CSV file if it doesn't exist
    csv_file = 'custom_layers.csv';
    if ~exist(csv_file, 'file')
        fprintf('Creating sample CSV file: %s\n', csv_file);

        fid = fopen(csv_file, 'w');
        fprintf(fid, 'layer_name,gds_layer,gds_datatype,thickness,z_bottom,z_top,material\n');
        fprintf(fid, 'Substrate,40,0,5.0,-5.0,0.0,Silicon\n');
        fprintf(fid, 'Active,1,0,0.3,0.0,0.3,Silicon\n');
        fprintf(fid, 'Poly,5,0,0.2,0.3,0.5,Polysilicon\n');
        fprintf(fid, 'Contact,6,0,0.3,0.5,0.8,Tungsten\n');
        fprintf(fid, 'Metal1,8,0,0.5,0.8,1.3,Aluminum\n');
        fprintf(fid, 'Via1,19,0,0.5,1.3,1.8,Tungsten\n');
        fprintf(fid, 'Metal2,10,0,0.5,1.8,2.3,Aluminum\n');
        fclose(fid);
    end

    config = gds_convert_pdk_to_config('csv_file', csv_file, ...
                                      'output_file', 'layer_config_custom.json', ...
                                      'project_name', 'Custom Process', ...
                                      'units', 'micrometers', ...
                                      'verbose', true);

    fprintf('✓ Successfully created custom layer configuration\n');
    fprintf('  Layers processed: %d\n', length(config.layers));

    % Display material distribution
    materials = {config.layers.material};
    unique_materials = unique(materials);
    fprintf('  Materials used:\n');
    for i = 1:length(unique_materials)
        count = sum(strcmp(materials, unique_materials{i}));
        fprintf('    %s: %d layers\n', unique_materials{i}, count);
    end

catch ME
    fprintf('✗ Error in Example 4: %s\n', ME.message);
end

fprintf('\n');

%% Example 5: Load and validate generated configuration
fprintf('Example 5: Load and validate configuration\n');
fprintf('-----------------------------------------\n');

try
    % Try to load one of the generated configurations
    config_files = {'layer_config_sg13g2.json', 'layer_config_universal.json', ...
                    'layer_config_from_lef.json', 'layer_config_custom.json'};

    loaded_config = [];
    for i = 1:length(config_files)
        if exist(config_files{i}, 'file')
            loaded_config = gds_read_layer_config(config_files{i});
            fprintf('✓ Loaded configuration from: %s\n', config_files{i});
            break;
        end
    end

    if ~isempty(loaded_config)
        % Validate the configuration
        fprintf('  Project: %s\n', loaded_config.metadata.project);
        fprintf('  Units: %s\n', loaded_config.metadata.units);
        fprintf('  Total layers: %d\n', length(loaded_config.layers));

        % Check layer map
        non_zero_entries = sum(loaded_config.layer_map(:) > 0);
        fprintf('  Non-zero layer map entries: %d\n', non_zero_entries);

        % Validate z-height consistency
        inconsistent_layers = 0;
        for i = 1:length(loaded_config.layers)
            layer = loaded_config.layers(i);
            computed_thickness = layer.z_top - layer.z_bottom;
            if abs(computed_thickness - layer.thickness) > 1e-6
                inconsistent_layers = inconsistent_layers + 1;
            end
        end

        if inconsistent_layers == 0
            fprintf('  ✓ All layers have consistent z-heights and thicknesses\n');
        else
            fprintf('  ⚠ %d layers have inconsistent thickness calculations\n', inconsistent_layers);
        end

        % Test layer lookup
        if length(loaded_config.layers) >= 1
            test_layer = loaded_config.layers(1);
            layer_idx = loaded_config.layer_map(test_layer.gds_layer + 1, test_layer.gds_datatype + 1);
            if layer_idx > 0
                found_layer = loaded_config.layers(layer_idx);
                if strcmp(found_layer.name, test_layer.name)
                    fprintf('  ✓ Layer lookup functionality working correctly\n');
                else
                    fprintf('  ✗ Layer lookup returned wrong layer\n');
                end
            else
                fprintf('  ✗ Layer lookup failed for first layer\n');
            end
        end

    else
        fprintf('⚠ No configuration files found to load\n');
    end

catch ME
    fprintf('✗ Error in Example 5: %s\n', ME.message);
end

fprintf('\n');

%% Example 6: Integration with GDSII-to-3D workflow
fprintf('Example 6: GDSII-to-3D workflow integration\n');
fprintf('-------------------------------------------\n');

try
    % Find a configuration file to use
    config_files = {'layer_config_sg13g2.json', 'layer_config_universal.json', ...
                    'layer_config_custom.json'};

    config_file = '';
    for i = 1:length(config_files)
        if exist(config_files{i}, 'file')
            config_file = config_files{i};
            break;
        end
    end

    if ~isempty(config_file)
        fprintf('Using configuration: %s\n', config_file);

        % Load the configuration
        cfg = gds_read_layer_config(config_file);

        % Display summary for 3D conversion
        fprintf('Configuration ready for 3D conversion:\n');
        fprintf('  Process: %s %s\n', cfg.metadata.foundry, cfg.metadata.process);
        fprintf('  Total thickness: %.3f μm\n', ...
                max([cfg.layers.z_top]) - min([cfg.layers.z_bottom]));

        % Show enabled layers
        enabled_layers = cfg.layers([cfg.layers.enabled]);
        fprintf('  Enabled layers: %d/%d\n', length(enabled_layers), length(cfg.layers));

        % Show material stack
        fprintf('  Material stack (bottom to top):\n');
        [~, sort_idx] = sort([cfg.layers.z_bottom]);
        for i = 1:min(5, length(sort_idx))
            layer = cfg.layers(sort_idx(i));
            if layer.enabled
                fprintf('    %.3f-%.3f μm: %s (%s)\n', ...
                        layer.z_bottom, layer.z_top, layer.name, layer.material);
            end
        end

        fprintf('✓ Configuration is ready for gds_layer_to_3d() conversion\n');
        fprintf('  Example usage:\n');
        fprintf('    cfg = gds_read_layer_config(''%s'');\n', config_file);
        fprintf('    glib = read_gds_library(''your_design.gds'');\n');
        fprintf('    layer_data = gds_layer_to_3d(glib, cfg);\n');

    else
        fprintf('⚠ No configuration file found for workflow integration\n');
    end

catch ME
    fprintf('✗ Error in Example 6: %s\n', ME.message);
end

fprintf('\n=== Examples Complete ===\n');
fprintf('See the generated JSON files for the layer configurations.\n');
fprintf('Use gds_read_layer_config() to load them in your workflow.\n');