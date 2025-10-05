function gds_to_step(gds_file, layer_config_file, output_file, varargin)
% GDS_TO_STEP - Convert GDSII layout to STEP 3D model
%
% gds_to_step(gds_file, layer_config_file, output_file)
% gds_to_step(gds_file, layer_config_file, output_file, 'option', value, ...)
%
% Main function for GDSII to STEP conversion pipeline. This integrates
% layer configuration parsing, polygon extraction, 3D extrusion, and
% STEP file generation into a single streamlined workflow.
%
% INPUT:
%   gds_file          : Path to input GDSII file
%   layer_config_file : Path to layer configuration JSON file
%   output_file       : Path to output STEP file (or STL if format='stl')
%   
%   Optional parameter/value pairs:
%       'structure_name'  - Name of structure to export (default: top structure)
%       'window'          - [xmin ymin xmax ymax] extract region only
%       'layers_filter'   - Vector of layer numbers to process
%       'datatypes_filter'- Vector of datatype numbers to process
%       'flatten'         - Flatten hierarchy (default: true)
%       'merge'           - Merge overlapping solids (default: false)
%       'format'          - Output format: 'step' or 'stl' (default: 'step')
%       'units'           - Unit scaling factor (default: 1.0)
%       'verbose'         - Verbosity level 0/1/2 (default: 1)
%       'python_cmd'      - Python command for STEP writer (default: 'python3')
%       'precision'       - Geometric tolerance (default: 1e-6)
%       'keep_temp'       - Keep temporary files for debugging (default: false)
%
% OUTPUT:
%   Writes STEP (or STL) file to disk
%
% EXAMPLES:
%   % Basic conversion
%   gds_to_step('chip.gds', 'cmos_config.json', 'chip.step');
%
%   % With windowing to extract specific region
%   gds_to_step('chip.gds', 'config.json', 'chip.step', ...
%               'window', [0 0 1000 1000], ...
%               'layers_filter', [10 11 12], ...  % Metal layers only
%               'verbose', 2);
%
%   % Export to STL format
%   gds_to_step('chip.gds', 'config.json', 'chip.stl', ...
%               'format', 'stl', ...
%               'units', 1e-6);  % Convert to meters
%
%   % Specify structure and flatten hierarchy
%   gds_to_step('design.gds', 'config.json', 'design.step', ...
%               'structure_name', 'TopCell', ...
%               'flatten', true, ...
%               'verbose', 2);
%
% PIPELINE:
%   1. Read GDSII library
%   2. Load layer configuration
%   3. Optional: Apply windowing/filtering
%   4. Flatten hierarchy (if requested)
%   5. Extract polygons by layer
%   6. Extrude polygons to 3D solids
%   7. Optional: Merge overlapping solids
%   8. Write STEP (or STL) file
%
% NOTES:
%   - For large designs, use 'window' to extract regions
%   - STEP format requires Python with pythonOCC installed
%   - STL format works without external dependencies
%   - Automatic fallback to STL if Python/pythonOCC unavailable
%   - All coordinates are in GDS user units unless scaled
%
% SEE ALSO:
%   gds_read_layer_config, gds_layer_to_3d, gds_extrude_polygon
%   gds_write_step, gds_write_stl
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Part of gdsii-toolbox-146 GDSII-to-STEP implementation
%   Implementation of Section 4.5 from GDS_TO_STEP_IMPLEMENTATION_PLAN.md
%

% =========================================================================
% PARSE INPUT ARGUMENTS
% =========================================================================

    % Check minimum arguments
    if nargin < 3
        error('gds_to_step:MissingInput', ...
              'Three arguments required: gds_file, layer_config_file, output_file');
    end
    
    % Validate file paths
    if ~ischar(gds_file) && ~isstring(gds_file)
        error('gds_to_step:InvalidInput', 'gds_file must be a string');
    end
    if ~ischar(layer_config_file) && ~isstring(layer_config_file)
        error('gds_to_step:InvalidInput', 'layer_config_file must be a string');
    end
    if ~ischar(output_file) && ~isstring(output_file)
        error('gds_to_step:InvalidInput', 'output_file must be a string');
    end
    
    % Convert to char if string type
    gds_file = char(gds_file);
    layer_config_file = char(layer_config_file);
    output_file = char(output_file);
    
    % Check if input files exist
    if ~exist(gds_file, 'file')
        error('gds_to_step:FileNotFound', 'GDSII file not found: %s', gds_file);
    end
    if ~exist(layer_config_file, 'file')
        error('gds_to_step:FileNotFound', 'Layer config file not found: %s', layer_config_file);
    end
    
    % Parse optional parameters
    options = parse_options(varargin{:});
    
    % Display banner
    if options.verbose >= 1
        fprintf('\n');
        fprintf('========================================\n');
        fprintf('  GDSII to STEP/STL Conversion\n');
        fprintf('========================================\n');
        fprintf('Input GDS:     %s\n', gds_file);
        fprintf('Layer config:  %s\n', layer_config_file);
        fprintf('Output file:   %s\n', output_file);
        fprintf('Format:        %s\n', upper(options.format));
        fprintf('========================================\n\n');
    end
    
    % Start total timer
    t_total = tic;

% =========================================================================
% STEP 1: READ GDSII LIBRARY
% =========================================================================

    if options.verbose >= 1
        fprintf('[1/8] Reading GDSII library...\n');
    end
    t_step = tic;
    
    try
        glib = read_gds_library(gds_file);
        
        if options.verbose >= 2
            fprintf('      Library name: %s\n', get(glib, 'lname'));
            fprintf('      Number of structures: %d\n', length(glib));
            fprintf('      Database unit: %g\n', get(glib, 'dbunit'));
            fprintf('      User unit: %g\n', get(glib, 'uunit'));
        end
        
        if options.verbose >= 1
            fprintf('      Completed in %.2f seconds\n\n', toc(t_step));
        end
    catch ME
        error('gds_to_step:ReadError', ...
              'Failed to read GDSII file: %s\n%s', gds_file, ME.message);
    end

% =========================================================================
% STEP 2: LOAD LAYER CONFIGURATION
% =========================================================================

    if options.verbose >= 1
        fprintf('[2/8] Loading layer configuration...\n');
    end
    t_step = tic;
    
    try
        layer_config = gds_read_layer_config(layer_config_file);
        
        if options.verbose >= 2
            fprintf('      Project: %s\n', layer_config.metadata.project);
            fprintf('      Units: %s\n', layer_config.metadata.units);
            fprintf('      Number of layers defined: %d\n', length(layer_config.layers));
        end
        
        if options.verbose >= 1
            fprintf('      Completed in %.2f seconds\n\n', toc(t_step));
        end
    catch ME
        error('gds_to_step:ConfigError', ...
              'Failed to load layer config: %s\n%s', layer_config_file, ME.message);
    end

% =========================================================================
% STEP 3: APPLY WINDOWING (OPTIONAL)
% =========================================================================

    if ~isempty(options.window)
        if options.verbose >= 1
            fprintf('[3/8] Applying window filter...\n');
            fprintf('      Window: [%.3f %.3f %.3f %.3f]\n', options.window);
        end
        t_step = tic;
        
        try
            % Apply windowing using existing bbox-based filtering
            % This will be done during layer extraction for efficiency
            if options.verbose >= 1
                fprintf('      Window filter will be applied during extraction\n');
                fprintf('      Completed in %.2f seconds\n\n', toc(t_step));
            end
        catch ME
            warning('gds_to_step:WindowError', ...
                    'Failed to apply window: %s\nProceeding without windowing.', ME.message);
        end
    else
        if options.verbose >= 1
            fprintf('[3/8] Skipping window filter (no window specified)\n\n');
        end
    end

% =========================================================================
% STEP 4: EXTRACT POLYGONS BY LAYER
% =========================================================================

    if options.verbose >= 1
        fprintf('[4/8] Extracting polygons by layer...\n');
        if options.flatten
            fprintf('      Hierarchy flattening: enabled\n');
        else
            fprintf('      Hierarchy flattening: disabled\n');
        end
    end
    t_step = tic;
    
    try
        % Build parameter list for gds_layer_to_3d
        extract_params = {};
        
        if ~isempty(options.structure_name)
            extract_params = [extract_params, {'structure_name', options.structure_name}];
        end
        
        if ~isempty(options.layers_filter)
            extract_params = [extract_params, {'layers_filter', options.layers_filter}];
        end
        
        if ~isempty(options.datatypes_filter)
            extract_params = [extract_params, {'datatypes_filter', options.datatypes_filter}];
        end
        
        extract_params = [extract_params, {'flatten', options.flatten}];
        
        % Extract layer data
        layer_data = gds_layer_to_3d(glib, layer_config, extract_params{:});
        
        if options.verbose >= 2
            fprintf('      Total polygons extracted: %d\n', layer_data.statistics.total_polygons);
            fprintf('      Layers with data: %d\n', length(layer_data.layers));
            for k = 1:length(layer_data.layers)
                L = layer_data.layers(k);
                fprintf('        Layer %s: %d polygons\n', ...
                        L.config.name, L.num_polygons);
            end
        end
        
        if options.verbose >= 1
            fprintf('      Completed in %.2f seconds\n\n', toc(t_step));
        end
    catch ME
        error('gds_to_step:ExtractionError', ...
              'Failed to extract polygons: %s', ME.message);
    end

% =========================================================================
% STEP 5: APPLY WINDOW FILTERING TO EXTRACTED POLYGONS (OPTIONAL)
% =========================================================================

    if ~isempty(options.window)
        if options.verbose >= 1
            fprintf('[5/8] Filtering polygons by window...\n');
        end
        t_step = tic;
        
        try
            layer_data = apply_window_filter(layer_data, options.window);
            
            if options.verbose >= 2
                total_after = 0;
                for k = 1:length(layer_data.layers)
                    total_after = total_after + layer_data.layers(k).num_polygons;
                end
                fprintf('      Polygons after filtering: %d\n', total_after);
            end
            
            if options.verbose >= 1
                fprintf('      Completed in %.2f seconds\n\n', toc(t_step));
            end
        catch ME
            warning('gds_to_step:WindowFilterError', ...
                    'Failed to filter by window: %s\nProceeding with all polygons.', ME.message);
        end
    else
        if options.verbose >= 1
            fprintf('[5/8] Skipping window filtering\n\n');
        end
    end

% =========================================================================
% STEP 6: EXTRUDE POLYGONS TO 3D SOLIDS
% =========================================================================

    if options.verbose >= 1
        fprintf('[6/8] Extruding polygons to 3D solids...\n');
    end
    t_step = tic;
    
    try
        all_solids = {};
        extrusion_options = struct();
        extrusion_options.check_orientation = true;
        extrusion_options.tolerance = options.precision;
        
        total_polygons = 0;
        for k = 1:length(layer_data.layers)
            total_polygons = total_polygons + layer_data.layers(k).num_polygons;
        end
        
        solid_count = 0;
        for k = 1:length(layer_data.layers)
            layer = layer_data.layers(k);
            
            if options.verbose >= 2
                fprintf('      Processing layer %s (%d polygons)...\n', ...
                        layer.config.name, layer.num_polygons);
            end
            
            for p = 1:layer.num_polygons
                poly = layer.polygons{p};
                
                % Extrude polygon to 3D
                solid = gds_extrude_polygon(poly, ...
                                           layer.config.z_bottom, ...
                                           layer.config.z_top, ...
                                           extrusion_options);
                
                % Add metadata
                solid.material = layer.config.material;
                solid.color = layer.config.color;
                solid.layer_name = layer.config.name;
                solid.gds_layer = layer.config.gds_layer;
                solid.gds_datatype = layer.config.gds_datatype;
                solid.polygon_xy = poly;  % Store original 2D polygon
                
                all_solids{end+1} = solid;
                solid_count = solid_count + 1;
                
                % Progress indicator for verbose mode
                if options.verbose >= 2 && mod(solid_count, 100) == 0
                    fprintf('      Progress: %d/%d solids (%.1f%%)\n', ...
                            solid_count, total_polygons, 100*solid_count/total_polygons);
                end
            end
        end
        
        if options.verbose >= 1
            fprintf('      Created %d 3D solids\n', length(all_solids));
            fprintf('      Completed in %.2f seconds\n\n', toc(t_step));
        end
    catch ME
        error('gds_to_step:ExtrusionError', ...
              'Failed to extrude polygons: %s', ME.message);
    end

% =========================================================================
% STEP 7: MERGE OVERLAPPING SOLIDS (OPTIONAL)
% =========================================================================

    if options.merge
        if options.verbose >= 1
            fprintf('[7/8] Merging overlapping solids...\n');
        end
        t_step = tic;
        
        try
            % Perform 3D Boolean union operations
            merge_options = struct();
            merge_options.operation = 'union';
            merge_options.precision = options.precision;
            merge_options.python_cmd = options.python_cmd;
            merge_options.keep_temp = options.keep_temp;
            merge_options.verbose = options.verbose;
            
            % Call gds_merge_solids_3d
            all_solids = gds_merge_solids_3d(all_solids, ...
                                             'operation', merge_options.operation, ...
                                             'precision', merge_options.precision, ...
                                             'python_cmd', merge_options.python_cmd, ...
                                             'keep_temp', merge_options.keep_temp, ...
                                             'verbose', merge_options.verbose);
            
            if options.verbose >= 1
                fprintf('      Merge operation completed\n');
                fprintf('      Completed in %.2f seconds\n\n', toc(t_step));
            end
        catch ME
            warning('gds_to_step:MergeError', ...
                    'Failed to merge solids: %s\nProceeding with unmerged solids.', ME.message);
            if options.verbose >= 2 && ~isempty(ME.stack)
                fprintf('      Error location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
            end
        end
    else
        if options.verbose >= 1
            fprintf('[7/8] Skipping solid merging\n\n');
        end
    end

% =========================================================================
% STEP 8: WRITE OUTPUT FILE
% =========================================================================

    if options.verbose >= 1
        fprintf('[8/8] Writing %s file...\n', upper(options.format));
    end
    t_step = tic;
    
    try
        % Prepare output options
        write_options = struct();
        write_options.units = options.units;
        write_options.precision = options.precision;
        write_options.verbose = (options.verbose >= 2);
        write_options.keep_temp = options.keep_temp;
        
        if strcmp(options.format, 'stl')
            % Write STL file
            write_options.format = 'binary';  % Default to binary STL
            write_options.solid_name = 'gds_solid';
            gds_write_stl(all_solids, output_file, write_options);
        else
            % Write STEP file
            write_options.format = 'AP203';
            write_options.materials = true;
            write_options.python_cmd = options.python_cmd;
            gds_write_step(all_solids, output_file, write_options);
        end
        
        if options.verbose >= 1
            fprintf('      Output file: %s\n', output_file);
            fprintf('      Completed in %.2f seconds\n\n', toc(t_step));
        end
    catch ME
        error('gds_to_step:WriteError', ...
              'Failed to write output file: %s\n%s', output_file, ME.message);
    end

% =========================================================================
% SUMMARY
% =========================================================================

    total_time = toc(t_total);
    
    if options.verbose >= 1
        fprintf('========================================\n');
        fprintf('  Conversion Summary\n');
        fprintf('========================================\n');
        fprintf('Total polygons: %d\n', total_polygons);
        fprintf('Total solids:   %d\n', length(all_solids));
        fprintf('Output format:  %s\n', upper(options.format));
        fprintf('Total time:     %.2f seconds\n', total_time);
        fprintf('========================================\n');
        fprintf('Conversion completed successfully!\n\n');
    end

end


%% ========================================================================
%% HELPER FUNCTION: PARSE OPTIONS
%% ========================================================================

function options = parse_options(varargin)
% Parse optional parameter/value pairs

    % Default options
    options.structure_name = '';
    options.window = [];
    options.layers_filter = [];
    options.datatypes_filter = [];
    options.flatten = true;
    options.merge = false;
    options.format = 'step';
    options.units = 1.0;
    options.verbose = 1;
    options.python_cmd = 'python3';
    options.precision = 1e-6;
    options.keep_temp = false;
    
    % Parse parameter/value pairs
    k = 1;
    while k <= length(varargin)
        if ~ischar(varargin{k}) && ~isstring(varargin{k})
            error('gds_to_step:InvalidParameter', ...
                  'Parameter names must be strings');
        end
        
        param_name = lower(char(varargin{k}));
        
        if k == length(varargin)
            error('gds_to_step:MissingValue', ...
                  'Parameter "%s" has no value', varargin{k});
        end
        
        param_value = varargin{k+1};
        
        switch param_name
            case 'structure_name'
                options.structure_name = char(param_value);
                
            case 'window'
                if isnumeric(param_value) && length(param_value) == 4
                    options.window = param_value(:)';
                else
                    error('gds_to_step:InvalidWindow', ...
                          'Window must be [xmin ymin xmax ymax]');
                end
                
            case 'layers_filter'
                options.layers_filter = param_value;
                
            case 'datatypes_filter'
                options.datatypes_filter = param_value;
                
            case 'flatten'
                options.flatten = logical(param_value);
                
            case 'merge'
                options.merge = logical(param_value);
                
            case 'format'
                options.format = lower(char(param_value));
                if ~ismember(options.format, {'step', 'stl'})
                    error('gds_to_step:InvalidFormat', ...
                          'Format must be ''step'' or ''stl''');
                end
                
            case 'units'
                if ~isnumeric(param_value) || ~isscalar(param_value)
                    error('gds_to_step:InvalidUnits', ...
                          'Units must be a numeric scalar');
                end
                options.units = double(param_value);
                
            case 'verbose'
                if ~isnumeric(param_value) || ~isscalar(param_value)
                    error('gds_to_step:InvalidVerbose', ...
                          'Verbose must be 0, 1, or 2');
                end
                options.verbose = round(param_value);
                
            case 'python_cmd'
                options.python_cmd = char(param_value);
                
            case 'precision'
                if ~isnumeric(param_value) || ~isscalar(param_value)
                    error('gds_to_step:InvalidPrecision', ...
                          'Precision must be a numeric scalar');
                end
                options.precision = double(param_value);
                
            case 'keep_temp'
                options.keep_temp = logical(param_value);
                
            otherwise
                warning('gds_to_step:UnknownParameter', ...
                        'Unknown parameter: %s', varargin{k});
        end
        
        k = k + 2;
    end
end


%% ========================================================================
%% HELPER FUNCTION: APPLY WINDOW FILTER
%% ========================================================================

function layer_data = apply_window_filter(layer_data, window)
% Filter polygons by bounding box window
% window = [xmin ymin xmax ymax]

    xmin = window(1);
    ymin = window(2);
    xmax = window(3);
    ymax = window(4);
    
    for k = 1:length(layer_data.layers)
        layer = layer_data.layers(k);
        filtered_polygons = {};
        
        for p = 1:layer.num_polygons
            poly = layer.polygons{p};
            
            % Check if polygon intersects window
            poly_xmin = min(poly(:,1));
            poly_xmax = max(poly(:,1));
            poly_ymin = min(poly(:,2));
            poly_ymax = max(poly(:,2));
            
            % Test for overlap
            if poly_xmax >= xmin && poly_xmin <= xmax && ...
               poly_ymax >= ymin && poly_ymin <= ymax
                % Polygon overlaps window, keep it
                filtered_polygons{end+1} = poly;
            end
        end
        
        % Update layer data
        layer_data.layers(k).polygons = filtered_polygons;
        layer_data.layers(k).num_polygons = length(filtered_polygons);
        
        % Recalculate bounding box and area
        if ~isempty(filtered_polygons)
            bbox = [inf inf -inf -inf];
            total_area = 0;
            for p = 1:length(filtered_polygons)
                poly = filtered_polygons{p};
                bbox(1) = min(bbox(1), min(poly(:,1)));
                bbox(2) = min(bbox(2), min(poly(:,2)));
                bbox(3) = max(bbox(3), max(poly(:,1)));
                bbox(4) = max(bbox(4), max(poly(:,2)));
                total_area = total_area + abs(polyarea(poly(:,1), poly(:,2)));
            end
            layer_data.layers(k).bbox = bbox;
            layer_data.layers(k).area = total_area;
        else
            layer_data.layers(k).bbox = [inf inf -inf -inf];
            layer_data.layers(k).area = 0;
        end
    end
    
    % Remove empty layers
    non_empty = false(1, length(layer_data.layers));
    for k = 1:length(layer_data.layers)
        if layer_data.layers(k).num_polygons > 0
            non_empty(k) = true;
        end
    end
    layer_data.layers = layer_data.layers(non_empty);
    
end
