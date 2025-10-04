function layer_config = gds_read_layer_config(config_file)
%function layer_config = gds_read_layer_config(config_file)
%
% gds_read_layer_config: Reads and parses a JSON layer configuration file
%                        for GDSII-to-3D conversion workflows.
%
% This function loads a JSON file that defines the mapping between GDSII
% 2D layers and their 3D physical parameters (z-heights, thicknesses,
% materials, etc.). It validates the structure and returns a MATLAB/Octave
% struct suitable for use in 3D extrusion and STEP export.
%
% INPUT:
%   config_file : String path to the JSON layer configuration file.
%                 Can be absolute or relative to current directory.
%
% OUTPUT:
%   layer_config : MATLAB structure containing:
%       .metadata       - Configuration metadata
%           .project    - Project name (string)
%           .units      - Unit system (string, e.g., 'micrometers')
%           .foundry    - Foundry name (string, optional)
%           .process    - Process name (string, optional)
%           .reference  - Reference/source (string, optional)
%           .date       - Creation date (string, optional)
%           .version    - Configuration version (string, optional)
%           .notes      - Additional notes (string, optional)
%
%       .layers(n)      - Array of layer definitions
%           .gds_layer  - GDSII layer number (integer, 0-255)
%           .gds_datatype - GDSII datatype (integer, 0-255)
%           .name       - Layer name (string)
%           .z_bottom   - Bottom z-coordinate (numeric)
%           .z_top      - Top z-coordinate (numeric)
%           .thickness  - Layer thickness (numeric)
%           .material   - Material name (string, optional)
%           .description - Layer description (string, optional)
%           .color      - Display color [R G B] 0-1 (vector, optional)
%           .opacity    - Display opacity 0-1 (numeric, optional)
%           .enabled    - Enable flag (logical, default true)
%           .fill_type  - Fill type 'solid'/'hatched' (string, optional)
%           .properties - Additional properties (struct, optional)
%
%       .conversion_options - Conversion settings (optional)
%           .substrate_thickness - Substrate thickness (numeric)
%           .passivation_thickness - Passivation thickness (numeric)
%           .merge_vias_with_metals - Merge flag (logical)
%           .simplify_polygons - Simplification tolerance (numeric)
%           .tolerance - General tolerance (numeric)
%
%       .layer_map      - Quick lookup map: layer_map(gds_layer, gds_datatype)
%                         Returns index into .layers array, or 0 if not found
%
% USAGE EXAMPLES:
%   % Load IHP SG13G2 process configuration
%   cfg = gds_read_layer_config('layer_configs/ihp_sg13g2.json');
%
%   % Access metadata
%   fprintf('Project: %s\n', cfg.metadata.project);
%   fprintf('Units: %s\n', cfg.metadata.units);
%
%   % Iterate through layers
%   for k = 1:length(cfg.layers)
%       L = cfg.layers(k);
%       fprintf('Layer %d/%d: %s at z=[%.3f, %.3f] um\n', ...
%               L.gds_layer, L.gds_datatype, L.name, L.z_bottom, L.z_top);
%   end
%
%   % Quick layer lookup
%   idx = cfg.layer_map(10, 0);  % Find Metal1 (layer 10, datatype 0)
%   if idx > 0
%       metal1 = cfg.layers(idx);
%       fprintf('Metal1 thickness: %.3f um\n', metal1.thickness);
%   end
%
% VALIDATION:
%   The function performs basic validation:
%   - File exists and is readable
%   - JSON is valid and parseable
%   - Required top-level fields exist (project, units, layers)
%   - Each layer has required fields (gds_layer, gds_datatype, name, z_bottom, z_top)
%   - Thickness consistency: z_top - z_bottom = thickness (within tolerance)
%
% COMPATIBILITY:
%   - MATLAB R2016b and later (jsondecode introduced in R2016b)
%   - GNU Octave 4.2.0 and later (jsondecode added in 4.2.0)
%   - For older versions, consider using external JSON parsers like JSONlab
%
% NOTES:
%   - Colors in JSON are specified as hex strings (e.g., "#FF5500")
%     and are converted to [R G B] vectors with values 0-1
%   - Boolean values in JSON are converted to MATLAB logical types
%   - Missing optional fields are set to appropriate defaults
%
% SEE ALSO:
%   gds_layer_to_3d, gds_extrude_polygon, gds_to_step
%   Layer configuration specification: Export/LAYER_CONFIG_SPEC.md
%   User guide: layer_configs/README.md
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Part of gdsii-toolbox-146 GDSII-to-STEP implementation
%

% =========================================================================
% INPUT VALIDATION
% =========================================================================

    % Check number of arguments
    if nargin < 1
        error('gds_read_layer_config:MissingInput', ...
              'Configuration file path is required.');
    end
    
    if ~ischar(config_file) && ~isstring(config_file)
        error('gds_read_layer_config:InvalidInput', ...
              'Configuration file path must be a string.');
    end
    
    % Convert string to char if needed (MATLAB compatibility)
    if isstring(config_file)
        config_file = char(config_file);
    end
    
    % Check if file exists
    if ~exist(config_file, 'file')
        error('gds_read_layer_config:FileNotFound', ...
              'Configuration file not found: %s', config_file);
    end

% =========================================================================
% READ AND PARSE JSON
% =========================================================================

    try
        % Read file content
        fid = fopen(config_file, 'r');
        if fid == -1
            error('gds_read_layer_config:FileOpenError', ...
                  'Cannot open file: %s', config_file);
        end
        json_text = fread(fid, '*char')';
        fclose(fid);
        
        % Parse JSON
        json_data = jsondecode(json_text);
        
    catch ME
        if exist('fid', 'var') && fid ~= -1
            fclose(fid);
        end
        error('gds_read_layer_config:ParseError', ...
              'Failed to parse JSON file: %s\nError: %s', ...
              config_file, ME.message);
    end

% =========================================================================
% VALIDATE REQUIRED FIELDS
% =========================================================================

    % Check required top-level fields
    if ~isfield(json_data, 'project')
        error('gds_read_layer_config:MissingField', ...
              'Required field "project" not found in configuration.');
    end
    
    if ~isfield(json_data, 'units')
        error('gds_read_layer_config:MissingField', ...
              'Required field "units" not found in configuration.');
    end
    
    if ~isfield(json_data, 'layers')
        error('gds_read_layer_config:MissingField', ...
              'Required field "layers" not found in configuration.');
    end
    
    if isempty(json_data.layers)
        error('gds_read_layer_config:EmptyLayers', ...
              'Layer array is empty. At least one layer must be defined.');
    end
    
    % Handle Octave's cell array representation of JSON arrays
    if iscell(json_data.layers)
        layers_json = json_data.layers;
    else
        % MATLAB returns struct array directly
        layers_json = num2cell(json_data.layers);
    end

% =========================================================================
% EXTRACT METADATA
% =========================================================================

    metadata.project = json_data.project;
    metadata.units = json_data.units;
    
    % Optional metadata fields
    optional_meta = {'foundry', 'process', 'reference', 'date', 'version', 'notes'};
    for k = 1:length(optional_meta)
        field = optional_meta{k};
        if isfield(json_data, field)
            metadata.(field) = json_data.(field);
        else
            metadata.(field) = '';
        end
    end

% =========================================================================
% EXTRACT CONVERSION OPTIONS
% =========================================================================

    if isfield(json_data, 'conversion_options')
        conversion_options = json_data.conversion_options;
    else
        conversion_options = struct();
    end
    
    % Set defaults for optional conversion parameters
    if ~isfield(conversion_options, 'substrate_thickness')
        conversion_options.substrate_thickness = 0;
    end
    if ~isfield(conversion_options, 'passivation_thickness')
        conversion_options.passivation_thickness = 0;
    end
    if ~isfield(conversion_options, 'merge_vias_with_metals')
        conversion_options.merge_vias_with_metals = false;
    end
    if ~isfield(conversion_options, 'simplify_polygons')
        conversion_options.simplify_polygons = 0;
    end
    if ~isfield(conversion_options, 'tolerance')
        conversion_options.tolerance = 1e-6;
    end

% =========================================================================
% PROCESS LAYERS
% =========================================================================

    num_layers = length(layers_json);
    layers = repmat(struct(), 1, num_layers);
    
    % Initialize layer lookup map (256 x 256 for all possible layer/datatype combinations)
    layer_map = zeros(256, 256);
    
    for k = 1:num_layers
        if iscell(layers_json)
            layer_json = layers_json{k};
        else
            layer_json = layers_json(k);
        end
        
        % Check required layer fields
        required_fields = {'gds_layer', 'gds_datatype', 'name', 'z_bottom', 'z_top'};
        for j = 1:length(required_fields)
            field = required_fields{j};
            if ~isfield(layer_json, field)
                error('gds_read_layer_config:MissingLayerField', ...
                      'Layer %d is missing required field: %s', k, field);
            end
        end
        
        % Extract required fields
        layers(k).gds_layer = double(layer_json.gds_layer);
        layers(k).gds_datatype = double(layer_json.gds_datatype);
        layers(k).name = layer_json.name;
        layers(k).z_bottom = double(layer_json.z_bottom);
        layers(k).z_top = double(layer_json.z_top);
        
        % Validate layer/datatype range
        if layers(k).gds_layer < 0 || layers(k).gds_layer > 255
            error('gds_read_layer_config:InvalidLayer', ...
                  'Layer %d: gds_layer must be in range [0, 255], got %d', ...
                  k, layers(k).gds_layer);
        end
        if layers(k).gds_datatype < 0 || layers(k).gds_datatype > 255
            error('gds_read_layer_config:InvalidDatatype', ...
                  'Layer %d: gds_datatype must be in range [0, 255], got %d', ...
                  k, layers(k).gds_datatype);
        end
        
        % Calculate and validate thickness
        if isfield(layer_json, 'thickness')
            layers(k).thickness = double(layer_json.thickness);
            % Validate consistency: z_top - z_bottom = thickness
            computed_thickness = layers(k).z_top - layers(k).z_bottom;
            tol = conversion_options.tolerance;
            if abs(computed_thickness - layers(k).thickness) > tol
                warning('gds_read_layer_config:ThicknessInconsistent', ...
                        'Layer %d (%s): thickness=%.6f but z_top-z_bottom=%.6f', ...
                        k, layers(k).name, layers(k).thickness, computed_thickness);
            end
        else
            % Compute from z coordinates
            layers(k).thickness = layers(k).z_top - layers(k).z_bottom;
        end
        
        % Extract optional fields with defaults
        if isfield(layer_json, 'material')
            layers(k).material = layer_json.material;
        else
            layers(k).material = '';
        end
        
        if isfield(layer_json, 'description')
            layers(k).description = layer_json.description;
        else
            layers(k).description = '';
        end
        
        if isfield(layer_json, 'color')
            layers(k).color = parse_color(layer_json.color);
        else
            layers(k).color = [0.5, 0.5, 0.5];  % default gray
        end
        
        if isfield(layer_json, 'opacity')
            layers(k).opacity = double(layer_json.opacity);
        else
            layers(k).opacity = 1.0;
        end
        
        if isfield(layer_json, 'enabled')
            layers(k).enabled = logical(layer_json.enabled);
        else
            layers(k).enabled = true;
        end
        
        if isfield(layer_json, 'fill_type')
            layers(k).fill_type = layer_json.fill_type;
        else
            layers(k).fill_type = 'solid';
        end
        
        if isfield(layer_json, 'properties')
            layers(k).properties = layer_json.properties;
        else
            layers(k).properties = struct();
        end
        
        % Build layer lookup map (add 1 because MATLAB uses 1-based indexing)
        layer_idx = layers(k).gds_layer + 1;
        dtype_idx = layers(k).gds_datatype + 1;
        
        if layer_map(layer_idx, dtype_idx) ~= 0
            warning('gds_read_layer_config:DuplicateLayer', ...
                    'Duplicate layer/datatype found: %d/%d. Using last definition.', ...
                    layers(k).gds_layer, layers(k).gds_datatype);
        end
        
        layer_map(layer_idx, dtype_idx) = k;
    end

% =========================================================================
% ASSEMBLE OUTPUT STRUCTURE
% =========================================================================

    layer_config.metadata = metadata;
    layer_config.layers = layers;
    layer_config.conversion_options = conversion_options;
    layer_config.layer_map = layer_map;
    
    % Store original file path for reference
    layer_config.config_file = config_file;

end

% =========================================================================
% HELPER FUNCTION: PARSE COLOR
% =========================================================================

function rgb = parse_color(color_spec)
% parse_color: Convert color specification to RGB vector
%
% Supports:
%   - Hex string: "#FF5500" or "#F50"
%   - RGB array: [255, 85, 0] (0-255) or [1.0, 0.33, 0.0] (0-1)
%   - Named colors: 'red', 'green', 'blue', etc.

    if ischar(color_spec) || isstring(color_spec)
        color_spec = char(color_spec);
        
        % Hex color: #RRGGBB or #RGB
        if color_spec(1) == '#'
            hex = color_spec(2:end);
            
            if length(hex) == 3
                % Short form: #RGB -> #RRGGBB
                hex = [hex(1) hex(1) hex(2) hex(2) hex(3) hex(3)];
            end
            
            if length(hex) == 6
                r = hex2dec(hex(1:2)) / 255.0;
                g = hex2dec(hex(3:4)) / 255.0;
                b = hex2dec(hex(5:6)) / 255.0;
                rgb = [r, g, b];
            else
                warning('gds_read_layer_config:InvalidColor', ...
                        'Invalid hex color format: %s. Using gray.', color_spec);
                rgb = [0.5, 0.5, 0.5];
            end
            
        % Named color
        else
            rgb = name_to_rgb(color_spec);
        end
        
    elseif isnumeric(color_spec) && length(color_spec) == 3
        % Numeric RGB
        rgb = double(color_spec);
        
        % If values > 1, assume 0-255 range
        if max(rgb) > 1.0
            rgb = rgb / 255.0;
        end
        
        % Clamp to [0, 1]
        rgb = max(0, min(1, rgb));
        
    else
        warning('gds_read_layer_config:InvalidColor', ...
                'Unrecognized color format. Using gray.');
        rgb = [0.5, 0.5, 0.5];
    end
end

% =========================================================================
% HELPER FUNCTION: NAMED COLORS
% =========================================================================

function rgb = name_to_rgb(name)
% name_to_rgb: Convert common color names to RGB

    name = lower(name);
    
    switch name
        case 'red',       rgb = [1.0, 0.0, 0.0];
        case 'green',     rgb = [0.0, 1.0, 0.0];
        case 'blue',      rgb = [0.0, 0.0, 1.0];
        case 'yellow',    rgb = [1.0, 1.0, 0.0];
        case 'cyan',      rgb = [0.0, 1.0, 1.0];
        case 'magenta',   rgb = [1.0, 0.0, 1.0];
        case 'white',     rgb = [1.0, 1.0, 1.0];
        case 'black',     rgb = [0.0, 0.0, 0.0];
        case 'gray',      rgb = [0.5, 0.5, 0.5];
        case 'grey',      rgb = [0.5, 0.5, 0.5];
        case 'orange',    rgb = [1.0, 0.65, 0.0];
        case 'purple',    rgb = [0.5, 0.0, 0.5];
        case 'brown',     rgb = [0.65, 0.16, 0.16];
        otherwise
            warning('gds_read_layer_config:UnknownColor', ...
                    'Unknown color name: %s. Using gray.', name);
            rgb = [0.5, 0.5, 0.5];
    end
end
