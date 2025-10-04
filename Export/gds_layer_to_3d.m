function layer_data = gds_layer_to_3d(gds_input, layer_config, varargin)
%function layer_data = gds_layer_to_3d(gds_input, layer_config, varargin)
%
% gds_layer_to_3d: Extracts GDSII layer data organized for 3D extrusion.
%
% This function extracts polygon geometry from a gds_library or gds_structure
% object and organizes it by layer/datatype according to the provided layer
% configuration. The output is structured for subsequent 3D extrusion and
% STEP file export.
%
% INPUT:
%   gds_input     : Either a gds_library or gds_structure object containing
%                   the layout geometry to extract.
%
%   layer_config  : Layer configuration structure (from gds_read_layer_config)
%                   OR a string path to a JSON configuration file.
%
%   varargin      : Optional parameter/value pairs:
%       'structure_name'  - String name of structure to extract from library.
%                           If not specified and gds_input is a gds_library,
%                           the top-level structure is used.
%       'layers_filter'   - Vector of layer numbers to extract (default: all)
%       'datatypes_filter' - Vector of datatype numbers to extract (default: all)
%       'enabled_only'    - Logical flag to extract only enabled layers (default: true)
%       'flatten'         - Logical flag to flatten structure hierarchy (default: true)
%       'convert_paths'   - Convert path elements to boundaries (default: true)
%       'convert_texts'   - Convert text elements to boundaries (default: false)
%
% OUTPUT:
%   layer_data : Structure containing organized layer data:
%       .metadata          - Copy of configuration metadata
%       .layers(n)         - Array of extracted layer data
%           .config        - Copy of layer configuration (from layer_config.layers)
%           .polygons      - Cell array of polygons {Nx2 matrices}
%           .num_polygons  - Number of polygons extracted
%           .bbox          - Bounding box [xmin ymin xmax ymax]
%           .area          - Total area of polygons (user units^2)
%       .statistics        - Extraction statistics
%           .total_elements - Total elements processed
%           .total_polygons - Total polygons extracted across all layers
%           .extraction_time - Processing time in seconds
%
% USAGE EXAMPLES:
%   % Extract from structure with configuration file
%   glib = read_gds_library('design.gds');
%   layer_data = gds_layer_to_3d(glib, 'layer_configs/ihp_sg13g2.json');
%
%   % Extract from structure with pre-loaded config
%   cfg = gds_read_layer_config('layer_configs/ihp_sg13g2.json');
%   gstruct = glib{'TopCell'};
%   layer_data = gds_layer_to_3d(gstruct, cfg);
%
%   % Extract specific layers only
%   layer_data = gds_layer_to_3d(glib, cfg, ...
%                'layers_filter', [10 11 12], ...  % Metal1, Metal2, Metal3
%                'enabled_only', true);
%
%   % Access extracted data
%   for k = 1:length(layer_data.layers)
%       L = layer_data.layers(k);
%       fprintf('Layer %s: %d polygons, area = %.2f um^2\n', ...
%               L.config.name, L.num_polygons, L.area);
%       
%       % Process each polygon
%       for p = 1:L.num_polygons
%           poly = L.polygons{p};  % Nx2 matrix of vertices
%           % ... extrude to 3D using L.config.z_bottom, L.config.z_top
%       end
%   end
%
% NOTES:
%   - Polygons are returned in user units (as defined in the GDS file)
%   - Reference elements (sref, aref) are flattened by default
%   - Path elements are converted to boundary polygons
%   - Text elements are optionally converted (requires font data)
%   - Only boundary, box, and converted path elements are extracted
%   - Coordinate system: GDSII xy-plane becomes 3D xy-plane, z from config
%
% PERFORMANCE:
%   - For large designs, consider filtering by layers_filter
%   - Flattening deep hierarchies may take significant time
%   - Use enabled_only=true to skip disabled layers
%
% SEE ALSO:
%   gds_read_layer_config, gds_extrude_polygon, gds_to_step
%   read_gds_library, poly_convert (for path-to-boundary conversion)
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Part of gdsii-toolbox-146 GDSII-to-STEP implementation
%

% =========================================================================
% INPUT VALIDATION
% =========================================================================

    % Start timing
    t_start = tic;
    
    % Check number of arguments
    if nargin < 2
        error('gds_layer_to_3d:MissingInput', ...
              'At least two arguments required: gds_input and layer_config.');
    end
    
    % Validate gds_input type
    if ~isa(gds_input, 'gds_library') && ~isa(gds_input, 'gds_structure')
        error('gds_layer_to_3d:InvalidInput', ...
              'First argument must be a gds_library or gds_structure object.');
    end
    
    % Handle layer_config - load if it's a file path
    if ischar(layer_config) || isstring(layer_config)
        layer_config = gds_read_layer_config(char(layer_config));
    elseif ~isstruct(layer_config)
        error('gds_layer_to_3d:InvalidConfig', ...
              'layer_config must be a structure or file path string.');
    end
    
    % Validate layer_config structure
    if ~isfield(layer_config, 'layers') || ~isfield(layer_config, 'metadata')
        error('gds_layer_to_3d:InvalidConfig', ...
              'layer_config must have "layers" and "metadata" fields.');
    end

% =========================================================================
% PARSE OPTIONAL PARAMETERS
% =========================================================================

    % Default parameters
    params.structure_name = '';
    params.layers_filter = [];
    params.datatypes_filter = [];
    params.enabled_only = true;
    params.flatten = true;
    params.convert_paths = true;
    params.convert_texts = false;
    
    % Parse varargin
    k = 1;
    while k <= length(varargin)
        if ~ischar(varargin{k})
            error('gds_layer_to_3d:InvalidParameter', ...
                  'Parameter names must be strings.');
        end
        
        param_name = lower(varargin{k});
        
        if k == length(varargin)
            error('gds_layer_to_3d:MissingValue', ...
                  'Parameter "%s" has no value.', varargin{k});
        end
        
        param_value = varargin{k+1};
        
        switch param_name
            case 'structure_name'
                params.structure_name = param_value;
            case 'layers_filter'
                params.layers_filter = param_value;
            case 'datatypes_filter'
                params.datatypes_filter = param_value;
            case 'enabled_only'
                params.enabled_only = logical(param_value);
            case 'flatten'
                params.flatten = logical(param_value);
            case 'convert_paths'
                params.convert_paths = logical(param_value);
            case 'convert_texts'
                params.convert_texts = logical(param_value);
            otherwise
                warning('gds_layer_to_3d:UnknownParameter', ...
                        'Unknown parameter: %s', varargin{k});
        end
        
        k = k + 2;
    end

% =========================================================================
% GET TARGET STRUCTURE
% =========================================================================

    if isa(gds_input, 'gds_library')
        % Extract structure from library
        if isempty(params.structure_name)
            % Use top-level structure (structure with no references to it)
            try
                top_structs = topstruct(gds_input);
                if isempty(top_structs)
                    error('gds_layer_to_3d:NoTopStruct', ...
                          'Cannot find top-level structure in library.');
                end
                % Use getstruct method to retrieve by name
                gstruct_cell = getstruct(gds_input, top_structs{1});
                gstruct = gstruct_cell{1};
                fprintf('Using top-level structure: %s\n', top_structs{1});
            catch
                % If topstruct fails, use first structure
                if length(gds_input) == 0
                    error('gds_layer_to_3d:EmptyLibrary', ...
                          'Library contains no structures.');
                end
                % Access first structure directly from .st field
                gstruct = gds_input.st{1};
                fprintf('Using first structure: %s\n', sname(gstruct));
            end
        else
            % Use specified structure
            try
                gstruct_cell = getstruct(gds_input, params.structure_name);
                gstruct = gstruct_cell{1};
            catch
                error('gds_layer_to_3d:StructureNotFound', ...
                      'Structure "%s" not found in library.', params.structure_name);
            end
        end
    else
        % Input is already a structure
        gstruct = gds_input;
    end
    
    % Flatten hierarchy if requested
    if params.flatten
        try
            % poly_convert flattens references and converts paths to boundaries
            gstruct_flat = poly_convert(gstruct);
        catch ME
            warning('gds_layer_to_3d:FlattenFailed', ...
                    'Failed to flatten structure: %s\nProceeding with original structure.', ...
                    ME.message);
            gstruct_flat = gstruct;
        end
    else
        gstruct_flat = gstruct;
    end

% =========================================================================
% INITIALIZE OUTPUT STRUCTURE
% =========================================================================

    num_config_layers = length(layer_config.layers);
    layers_out = repmat(struct('config', [], 'polygons', {{}}, ...
                               'num_polygons', 0, 'bbox', [], 'area', 0), ...
                        1, num_config_layers);
    
    % Copy configuration to each output layer
    for k = 1:num_config_layers
        layers_out(k).config = layer_config.layers(k);
        layers_out(k).polygons = {};
        layers_out(k).num_polygons = 0;
        layers_out(k).bbox = [inf inf -inf -inf];
        layers_out(k).area = 0;
    end
    
    % Statistics
    stats.total_elements = 0;
    stats.total_polygons = 0;

% =========================================================================
% EXTRACT POLYGONS FROM ELEMENTS
% =========================================================================

    % Get all elements from the structure
    % Use (:) indexing to get cell array of all elements
    el_cell = gstruct_flat(:);
    num_elements = length(el_cell);
    
    for elem_idx = 1:num_elements
        gel = el_cell{elem_idx};
        stats.total_elements = stats.total_elements + 1;
        
        % Skip reference elements (should be flattened already)
        if is_ref(gel)
            continue;
        end
        
        % Get element layer and datatype using get method
        el_layer = get(gel, 'layer');
        el_dtype = get(gel, 'dtype');
        
        % Apply layer filters
        if ~isempty(params.layers_filter) && ~ismember(el_layer, params.layers_filter)
            continue;
        end
        if ~isempty(params.datatypes_filter) && ~ismember(el_dtype, params.datatypes_filter)
            continue;
        end
        
        % Look up layer in configuration
        layer_idx = el_layer + 1;  % MATLAB 1-based indexing
        dtype_idx = el_dtype + 1;
        
        if layer_idx > 256 || dtype_idx > 256
            continue;  % Invalid layer/datatype
        end
        
        config_idx = layer_config.layer_map(layer_idx, dtype_idx);
        
        if config_idx == 0
            % Layer not in configuration - skip
            continue;
        end
        
        % Check if layer is enabled
        if params.enabled_only && ~layer_config.layers(config_idx).enabled
            continue;
        end
        
        % Extract polygon(s) from element
        polys = extract_element_polygons(gel, params.convert_paths);
        
        if isempty(polys)
            continue;
        end
        
        % Add polygons to layer
        for p = 1:length(polys)
            poly = polys{p};
            
            if size(poly, 1) < 3
                continue;  % Invalid polygon
            end
            
            % Add to layer data
            layers_out(config_idx).polygons{end+1} = poly;
            layers_out(config_idx).num_polygons = layers_out(config_idx).num_polygons + 1;
            
            % Update bounding box
            bbox_cur = layers_out(config_idx).bbox;
            bbox_cur(1) = min(bbox_cur(1), min(poly(:,1)));
            bbox_cur(2) = min(bbox_cur(2), min(poly(:,2)));
            bbox_cur(3) = max(bbox_cur(3), max(poly(:,1)));
            bbox_cur(4) = max(bbox_cur(4), max(poly(:,2)));
            layers_out(config_idx).bbox = bbox_cur;
            
            % Update area (using shoelace formula)
            area_poly = polygon_area(poly);
            layers_out(config_idx).area = layers_out(config_idx).area + area_poly;
            
            stats.total_polygons = stats.total_polygons + 1;
        end
    end

% =========================================================================
% CLEAN UP EMPTY LAYERS
% =========================================================================

    % Remove layers with no polygons
    non_empty = false(1, num_config_layers);
    for k = 1:num_config_layers
        if layers_out(k).num_polygons > 0
            non_empty(k) = true;
        end
    end
    
    layers_out = layers_out(non_empty);

% =========================================================================
% ASSEMBLE OUTPUT
% =========================================================================

    stats.extraction_time = toc(t_start);
    
    layer_data.metadata = layer_config.metadata;
    layer_data.layers = layers_out;
    layer_data.statistics = stats;
    
    % Summary output
    fprintf('\n=== Layer Extraction Summary ===\n');
    fprintf('Total elements processed: %d\n', stats.total_elements);
    fprintf('Total polygons extracted: %d\n', stats.total_polygons);
    fprintf('Number of layers with data: %d\n', length(layers_out));
    fprintf('Extraction time: %.3f seconds\n', stats.extraction_time);
    fprintf('================================\n\n');

end

% =========================================================================
% HELPER FUNCTION: EXTRACT POLYGONS FROM ELEMENT
% =========================================================================

function polys = extract_element_polygons(gel, convert_paths)
% extract_element_polygons: Extract polygon data from a gds_element
%
% Returns a cell array of Nx2 polygon matrices

    polys = {};
    el_type = etype(gel);
    
    switch el_type
        case 'boundary'
            % Boundary elements already contain polygons
            xy_data = xy(gel);
            if iscell(xy_data)
                polys = xy_data;
            else
                polys = {xy_data};
            end
            
        case 'box'
            % Box is a rectangular boundary
            xy_data = xy(gel);
            if iscell(xy_data)
                polys = xy_data;
            else
                polys = {xy_data};
            end
            
        case 'path'
            if convert_paths
                % Convert path to boundary polygon
                try
                    % Get path data
                    xy_data = xy(gel);
                    if ~iscell(xy_data)
                        xy_data = {xy_data};
                    end
                    
                    % Get path width
                    try
                        path_width = get(gel, 'width');
                    catch
                        path_width = 1;  % default width
                    end
                    
                    % Convert each path segment
                    for k = 1:length(xy_data)
                        path_xy = xy_data{k};
                        if size(path_xy, 1) >= 2
                            % Convert path to polygon using width
                            poly = path_to_polygon(path_xy, path_width);
                            polys{end+1} = poly;
                        end
                    end
                catch ME
                    warning('gds_layer_to_3d:PathConversionFailed', ...
                            'Failed to convert path element: %s', ME.message);
                end
            end
            
        case 'text'
            % Text conversion not implemented in this basic version
            % Would require font data and rendering
            
        otherwise
            % Unknown or unsupported element type
    end
end

% =========================================================================
% HELPER FUNCTION: PATH TO POLYGON CONVERSION
% =========================================================================

function poly = path_to_polygon(path_xy, width)
% path_to_polygon: Convert a path with width to a closed polygon
%
% Simple rectangular offset implementation

    if size(path_xy, 1) < 2
        poly = [];
        return;
    end
    
    % For simplicity, create rectangular caps
    % More sophisticated version would use proper offsetting
    
    n = size(path_xy, 1);
    half_width = abs(width) / 2;
    
    % Calculate perpendicular offsets
    left_side = zeros(n, 2);
    right_side = zeros(n, 2);
    
    for k = 1:n
        if k == 1
            % First segment - use direction to next point
            dx = path_xy(2,1) - path_xy(1,1);
            dy = path_xy(2,2) - path_xy(1,2);
        elseif k == n
            % Last segment - use direction from previous point
            dx = path_xy(n,1) - path_xy(n-1,1);
            dy = path_xy(n,2) - path_xy(n-1,2);
        else
            % Middle segments - average of incoming and outgoing directions
            dx = (path_xy(k+1,1) - path_xy(k-1,1));
            dy = (path_xy(k+1,2) - path_xy(k-1,2));
        end
        
        % Normalize
        len = sqrt(dx^2 + dy^2);
        if len > 0
            dx = dx / len;
            dy = dy / len;
        end
        
        % Perpendicular offset
        left_side(k,:) = path_xy(k,:) + half_width * [-dy, dx];
        right_side(k,:) = path_xy(k,:) + half_width * [dy, -dx];
    end
    
    % Combine into closed polygon: left side forward + right side backward
    poly = [left_side; flipud(right_side); left_side(1,:)];
end

% =========================================================================
% HELPER FUNCTION: POLYGON AREA
% =========================================================================

function area = polygon_area(poly)
% polygon_area: Calculate polygon area using shoelace formula
%
% INPUT: poly - Nx2 matrix of vertices
% OUTPUT: area - Signed area (absolute value returned)

    if size(poly, 1) < 3
        area = 0;
        return;
    end
    
    % Ensure polygon is closed
    if ~isequal(poly(1,:), poly(end,:))
        poly = [poly; poly(1,:)];
    end
    
    n = size(poly, 1) - 1;
    
    % Shoelace formula
    area = 0;
    for k = 1:n
        area = area + (poly(k,1) * poly(k+1,2) - poly(k+1,1) * poly(k,2));
    end
    
    area = abs(area) / 2;
end
