function merged_solids = gds_merge_solids_3d(solids, varargin)
% GDS_MERGE_SOLIDS_3D - Perform Boolean operations on 3D solids
%
% merged_solids = gds_merge_solids_3d(solids)
% merged_solids = gds_merge_solids_3d(solids, operation)
% merged_solids = gds_merge_solids_3d(solids, 'option', value, ...)
%
% Merges overlapping 3D solids using Boolean operations via pythonOCC.
% Solids are grouped by layer name and z-coordinates, then merged within
% each group.
%
% INPUT:
%   solids    : Cell array of 3D solid structures from gds_extrude_polygon
%               Each solid must have fields:
%                 .polygon_xy  - Nx2 matrix of base polygon coordinates
%                 .z_bottom    - Bottom Z coordinate
%                 .z_top       - Top Z coordinate
%                 .layer_name  - Layer name (for grouping)
%                 .material    - Material name (optional)
%                 .color       - Color string (optional)
%
%   Optional parameter/value pairs:
%       'operation'   - Boolean operation: 'union', 'intersection', 'difference'
%                       (default: 'union')
%       'precision'   - Geometric tolerance (default: 1e-6)
%       'python_cmd'  - Python command (default: 'python3')
%       'keep_temp'   - Keep temporary files for debugging (default: false)
%       'verbose'     - Verbosity level 0/1/2 (default: 1)
%
% OUTPUT:
%   merged_solids : Cell array of merged 3D solid structures
%                   Same format as input, but with solids merged by layer
%
% NOTES:
%   - This is computationally expensive and optional
%   - Requires Python 3.x with pythonOCC installed
%   - Solids are grouped by (layer_name, z_bottom, z_top) before merging
%   - If merging fails, original solids are returned
%   - Union operation is most commonly used to merge overlapping features
%
% EXAMPLES:
%   % Basic union of overlapping solids
%   merged = gds_merge_solids_3d(solids);
%
%   % Intersection operation
%   merged = gds_merge_solids_3d(solids, 'operation', 'intersection');
%
%   % Difference (subtract subsequent solids from first)
%   merged = gds_merge_solids_3d(solids, 'operation', 'difference', ...
%                                'verbose', 2);
%
%   % Custom precision
%   merged = gds_merge_solids_3d(solids, 'operation', 'union', ...
%                                'precision', 1e-9);
%
% SEE ALSO:
%   gds_extrude_polygon, gds_to_step, gds_write_step
%
% IMPLEMENTATION:
%   This function:
%   1. Validates inputs and creates temp directory
%   2. Converts MATLAB solid structures to JSON format
%   3. Calls Python boolean_ops.py script via system()
%   4. Reads results and converts back to MATLAB structures
%   5. Cleans up temporary files
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Part of gdsii-toolbox-146 Section 4.10 implementation
%

% =========================================================================
% PARSE INPUT ARGUMENTS
% =========================================================================

    if nargin < 1
        error('gds_merge_solids_3d:MissingInput', ...
              'At least one argument (solids) is required');
    end
    
    % Validate solids input
    if ~iscell(solids)
        error('gds_merge_solids_3d:InvalidInput', ...
              'solids must be a cell array of solid structures');
    end
    
    if isempty(solids)
        warning('gds_merge_solids_3d:EmptyInput', ...
                'No solids provided, returning empty result');
        merged_solids = {};
        return;
    end
    
    % Parse optional parameters
    options = parse_options(varargin{:});
    
    if options.verbose >= 1
        fprintf('\n========================================\n');
        fprintf('  3D Boolean Operations\n');
        fprintf('========================================\n');
        fprintf('Operation:     %s\n', upper(options.operation));
        fprintf('Input solids:  %d\n', length(solids));
        fprintf('Precision:     %g\n', options.precision);
        fprintf('========================================\n\n');
    end

% =========================================================================
% VALIDATE SOLID STRUCTURES
% =========================================================================

    if options.verbose >= 1
        fprintf('[1/5] Validating solid structures...\n');
    end
    
    % Check that each solid has required fields
    required_fields = {'z_bottom', 'z_top'};
    for k = 1:length(solids)
        solid = solids{k};
        
        if ~isstruct(solid)
            error('gds_merge_solids_3d:InvalidSolid', ...
                  'Solid %d is not a structure', k);
        end
        
        for f = 1:length(required_fields)
            field = required_fields{f};
            if ~isfield(solid, field)
                error('gds_merge_solids_3d:MissingField', ...
                      'Solid %d missing required field: %s', k, field);
            end
        end
        
        % Check for polygon data (can be in different fields)
        if ~isfield(solid, 'polygon_xy') && ~isfield(solid, 'vertices')
            error('gds_merge_solids_3d:MissingPolygon', ...
                  'Solid %d missing polygon data (polygon_xy or vertices)', k);
        end
    end
    
    if options.verbose >= 1
        fprintf('      All solids valid\n\n');
    end

% =========================================================================
% CREATE TEMPORARY FILES
% =========================================================================

    if options.verbose >= 1
        fprintf('[2/5] Creating temporary files...\n');
    end
    
    % Create temp directory
    temp_dir = tempname;
    mkdir(temp_dir);
    
    input_json = fullfile(temp_dir, 'input_solids.json');
    output_json = fullfile(temp_dir, 'output_solids.json');
    
    if options.verbose >= 2
        fprintf('      Temp directory: %s\n', temp_dir);
    end

% =========================================================================
% CONVERT SOLIDS TO JSON FORMAT
% =========================================================================

    if options.verbose >= 1
        fprintf('[3/5] Converting solids to JSON format...\n');
    end
    
    % Build JSON structure
    json_data = struct();
    json_data.operation = options.operation;
    json_data.precision = options.precision;
    json_data.solids = cell(1, length(solids));
    
    for k = 1:length(solids)
        solid = solids{k};
        
        % Extract polygon coordinates
        if isfield(solid, 'polygon_xy')
            polygon = solid.polygon_xy;
        elseif isfield(solid, 'vertices')
            % Extract from vertices (take first N points for 2D polygon)
            n_base = size(solid.vertices, 1) / 2;  % Assume extruded solid
            polygon = solid.vertices(1:n_base, 1:2);
        else
            error('gds_merge_solids_3d:NoPolygon', ...
                  'Cannot extract polygon from solid %d', k);
        end
        
        % Convert to cell array of [x,y] pairs for JSON
        polygon_cell = cell(size(polygon, 1), 1);
        for p = 1:size(polygon, 1)
            polygon_cell{p} = [polygon(p,1), polygon(p,2)];
        end
        
        % Build solid data structure
        solid_data = struct();
        solid_data.polygon = polygon_cell;
        solid_data.z_bottom = solid.z_bottom;
        solid_data.z_top = solid.z_top;
        
        % Add optional metadata
        if isfield(solid, 'layer_name')
            solid_data.layer_name = solid.layer_name;
        else
            solid_data.layer_name = sprintf('layer_%d', k);
        end
        
        if isfield(solid, 'material')
            solid_data.material = solid.material;
        else
            solid_data.material = '';
        end
        
        if isfield(solid, 'color')
            solid_data.color = solid.color;
        else
            solid_data.color = '';
        end
        
        if isfield(solid, 'gds_layer')
            solid_data.gds_layer = solid.gds_layer;
        end
        
        if isfield(solid, 'gds_datatype')
            solid_data.gds_datatype = solid.gds_datatype;
        end
        
        json_data.solids{k} = solid_data;
    end
    
    % Write JSON file
    write_json(input_json, json_data);
    
    if options.verbose >= 2
        fprintf('      JSON written: %s\n', input_json);
    end
    
    if options.verbose >= 1
        fprintf('      Conversion complete\n\n');
    end

% =========================================================================
% CALL PYTHON BOOLEAN OPERATIONS SCRIPT
% =========================================================================

    if options.verbose >= 1
        fprintf('[4/5] Executing Boolean operations (this may take a while)...\n');
    end
    
    % Find the boolean_ops.py script
    script_path = fileparts(mfilename('fullpath'));
    boolean_script = fullfile(script_path, 'private', 'boolean_ops.py');
    
    if ~exist(boolean_script, 'file')
        error('gds_merge_solids_3d:ScriptNotFound', ...
              'Python script not found: %s', boolean_script);
    end
    
    % Build Python command
    cmd = sprintf('%s "%s" "%s" "%s" %s', ...
                  options.python_cmd, ...
                  boolean_script, ...
                  input_json, ...
                  output_json, ...
                  options.operation);
    
    if options.verbose >= 2
        fprintf('      Command: %s\n', cmd);
    end
    
    % Execute command
    [status, output] = system(cmd);
    
    if options.verbose >= 2
        fprintf('      Python output:\n');
        fprintf('%s\n', output);
    end
    
    if status ~= 0
        % Clean up and error
        if ~options.keep_temp
            rmdir(temp_dir, 's');
        end
        error('gds_merge_solids_3d:PythonError', ...
              'Python script failed with status %d:\n%s', status, output);
    end
    
    if options.verbose >= 1
        fprintf('      Boolean operations complete\n\n');
    end

% =========================================================================
% READ RESULTS AND CONVERT BACK TO MATLAB
% =========================================================================

    if options.verbose >= 1
        fprintf('[5/5] Reading results...\n');
    end
    
    % Check if output file exists
    if ~exist(output_json, 'file')
        if ~options.keep_temp
            rmdir(temp_dir, 's');
        end
        error('gds_merge_solids_3d:OutputNotFound', ...
              'Output JSON file not created: %s', output_json);
    end
    
    % Read output JSON
    result_data = read_json(output_json);
    
    % Check if operation was successful
    if ~isfield(result_data, 'success') || ~result_data.success
        error_msg = 'Unknown error';
        if isfield(result_data, 'error')
            error_msg = result_data.error;
        end
        
        if ~options.keep_temp
            rmdir(temp_dir, 's');
        end
        
        error('gds_merge_solids_3d:MergeFailed', ...
              'Boolean operation failed: %s', error_msg);
    end
    
    % Extract merged solids
    if ~isfield(result_data, 'merged_solids')
        error('gds_merge_solids_3d:NoResults', ...
              'Output JSON missing merged_solids field');
    end
    
    merged_solid_data = result_data.merged_solids;
    
    if options.verbose >= 2
        stats = result_data.statistics;
        fprintf('      Statistics:\n');
        fprintf('        Input solids:  %d\n', stats.input_count);
        fprintf('        Output solids: %d\n', stats.output_count);
        fprintf('        Layers:        %d\n', stats.layers_processed);
    end
    
    % Convert back to MATLAB solid structures
    % Handle both cell array and struct array from JSON
    num_solids = length(merged_solid_data);
    merged_solids = cell(1, num_solids);
    
    for k = 1:num_solids
        % Access element - works for both cell arrays and struct arrays
        if iscell(merged_solid_data)
            solid_data = merged_solid_data{k};
        else
            solid_data = merged_solid_data(k);
        end
        
        % Extract polygon (convert from cell array or numeric array)
        polygon_cell = solid_data.polygon;
        
        if iscell(polygon_cell)
            % Cell array of [x,y] pairs
            polygon = zeros(length(polygon_cell), 2);
            for p = 1:length(polygon_cell)
                polygon(p, :) = polygon_cell{p};
            end
        elseif isstruct(polygon_cell)
            % Struct array from JSON (Octave)
            polygon = zeros(length(polygon_cell), 2);
            for p = 1:length(polygon_cell)
                % Each element is a 2-element array
                if isfield(polygon_cell, 'x')
                    polygon(p, :) = [polygon_cell(p).x, polygon_cell(p).y];
                else
                    % Access as unnamed array
                    poly_pt = struct2cell(polygon_cell(p));
                    polygon(p, :) = [poly_pt{1}, poly_pt{2}];
                end
            end
        else
            % Already a numeric array
            polygon = polygon_cell;
        end
        
        % Re-extrude to create proper solid structure
        % This ensures we have proper faces, vertices, etc.
        try
            solid = gds_extrude_polygon(polygon, ...
                                       solid_data.z_bottom, ...
                                       solid_data.z_top);
            
            % Add metadata back
            if isfield(solid_data, 'layer_name')
                solid.layer_name = solid_data.layer_name;
            end
            if isfield(solid_data, 'material')
                solid.material = solid_data.material;
            end
            if isfield(solid_data, 'color')
                solid.color = solid_data.color;
            end
            if isfield(solid_data, 'gds_layer')
                solid.gds_layer = solid_data.gds_layer;
            end
            if isfield(solid_data, 'gds_datatype')
                solid.gds_datatype = solid_data.gds_datatype;
            end
            
            % Store original polygon
            solid.polygon_xy = polygon;
            
            merged_solids{k} = solid;
            
        catch ME
            warning('gds_merge_solids_3d:ExtrusionFailed', ...
                    'Failed to re-extrude merged solid %d: %s', k, ME.message);
            
            % Create minimal solid structure
            solid = struct();
            solid.polygon_xy = polygon;
            solid.z_bottom = solid_data.z_bottom;
            solid.z_top = solid_data.z_top;
            
            if isfield(solid_data, 'layer_name')
                solid.layer_name = solid_data.layer_name;
            end
            if isfield(solid_data, 'material')
                solid.material = solid_data.material;
            end
            if isfield(solid_data, 'color')
                solid.color = solid_data.color;
            end
            
            merged_solids{k} = solid;
        end
    end
    
    if options.verbose >= 1
        fprintf('      Converted %d merged solids\n\n', length(merged_solids));
    end

% =========================================================================
% CLEANUP
% =========================================================================

    if ~options.keep_temp
        rmdir(temp_dir, 's');
        if options.verbose >= 2
            fprintf('      Temporary files cleaned up\n');
        end
    else
        if options.verbose >= 1
            fprintf('      Temporary files kept in: %s\n', temp_dir);
        end
    end
    
    if options.verbose >= 1
        fprintf('========================================\n');
        fprintf('Boolean operations completed!\n');
        fprintf('Input solids:  %d\n', length(solids));
        fprintf('Output solids: %d\n', length(merged_solids));
        fprintf('========================================\n\n');
    end

end


%% ========================================================================
%% HELPER FUNCTION: PARSE OPTIONS
%% ========================================================================

function options = parse_options(varargin)
% Parse optional parameter/value pairs

    % Default options
    options.operation = 'union';
    options.precision = 1e-6;
    options.python_cmd = 'python3';
    options.keep_temp = false;
    options.verbose = 1;
    
    % Parse parameter/value pairs
    k = 1;
    while k <= length(varargin)
        if ~ischar(varargin{k}) && ~isstring(varargin{k})
            error('gds_merge_solids_3d:InvalidParameter', ...
                  'Parameter names must be strings');
        end
        
        param_name = lower(char(varargin{k}));
        
        if k == length(varargin)
            error('gds_merge_solids_3d:MissingValue', ...
                  'Parameter "%s" has no value', varargin{k});
        end
        
        param_value = varargin{k+1};
        
        switch param_name
            case 'operation'
                options.operation = lower(char(param_value));
                if ~ismember(options.operation, {'union', 'intersection', 'difference'})
                    error('gds_merge_solids_3d:InvalidOperation', ...
                          'Operation must be ''union'', ''intersection'', or ''difference''');
                end
                
            case 'precision'
                if ~isnumeric(param_value) || ~isscalar(param_value)
                    error('gds_merge_solids_3d:InvalidPrecision', ...
                          'Precision must be a numeric scalar');
                end
                options.precision = double(param_value);
                
            case 'python_cmd'
                options.python_cmd = char(param_value);
                
            case 'keep_temp'
                options.keep_temp = logical(param_value);
                
            case 'verbose'
                if ~isnumeric(param_value) || ~isscalar(param_value)
                    error('gds_merge_solids_3d:InvalidVerbose', ...
                          'Verbose must be 0, 1, or 2');
                end
                options.verbose = round(param_value);
                
            otherwise
                warning('gds_merge_solids_3d:UnknownParameter', ...
                        'Unknown parameter: %s', varargin{k});
        end
        
        k = k + 2;
    end
end


%% ========================================================================
%% HELPER FUNCTION: WRITE JSON
%% ========================================================================

function write_json(filename, data)
% Write MATLAB structure to JSON file
% Uses jsonencode if available (MATLAB R2016b+), otherwise custom writer

    try
        % Try built-in JSON encoder (MATLAB R2016b+)
        json_str = jsonencode(data);
        
        % Write to file
        fid = fopen(filename, 'w');
        if fid == -1
            error('Cannot open file for writing: %s', filename);
        end
        fprintf(fid, '%s', json_str);
        fclose(fid);
        
    catch
        % Fallback: simple custom JSON writer
        fid = fopen(filename, 'w');
        if fid == -1
            error('Cannot open file for writing: %s', filename);
        end
        
        write_json_value(fid, data, 0);
        fclose(fid);
    end
end


function write_json_value(fid, value, indent_level)
% Recursively write JSON value

    indent = repmat('  ', 1, indent_level);
    
    if isstruct(value)
        % Write struct as object
        fprintf(fid, '{\n');
        fields = fieldnames(value);
        for k = 1:length(fields)
            field = fields{k};
            fprintf(fid, '%s  "%s": ', indent, field);
            write_json_value(fid, value.(field), indent_level + 1);
            if k < length(fields)
                fprintf(fid, ',');
            end
            fprintf(fid, '\n');
        end
        fprintf(fid, '%s}', indent);
        
    elseif iscell(value)
        % Write cell array as array
        fprintf(fid, '[');
        if ~isempty(value)
            fprintf(fid, '\n');
            for k = 1:length(value)
                fprintf(fid, '%s  ', indent);
                write_json_value(fid, value{k}, indent_level + 1);
                if k < length(value)
                    fprintf(fid, ',');
                end
                fprintf(fid, '\n');
            end
            fprintf(fid, '%s', indent);
        end
        fprintf(fid, ']');
        
    elseif isnumeric(value)
        % Write numeric value
        if isscalar(value)
            if isnan(value)
                fprintf(fid, 'null');
            elseif isinf(value)
                if value > 0
                    fprintf(fid, '1e308');
                else
                    fprintf(fid, '-1e308');
                end
            else
                fprintf(fid, '%.15g', value);
            end
        else
            % Array of numbers
            fprintf(fid, '[');
            for k = 1:length(value)
                fprintf(fid, '%.15g', value(k));
                if k < length(value)
                    fprintf(fid, ', ');
                end
            end
            fprintf(fid, ']');
        end
        
    elseif ischar(value) || isstring(value)
        % Write string
        str = char(value);
        % Escape special characters
        str = strrep(str, '\', '\\');
        str = strrep(str, '"', '\"');
        str = strrep(str, sprintf('\n'), '\n');
        str = strrep(str, sprintf('\r'), '\r');
        str = strrep(str, sprintf('\t'), '\t');
        fprintf(fid, '"%s"', str);
        
    elseif islogical(value)
        % Write boolean
        if value
            fprintf(fid, 'true');
        else
            fprintf(fid, 'false');
        end
        
    else
        % Unknown type, write null
        fprintf(fid, 'null');
    end
end


%% ========================================================================
%% HELPER FUNCTION: READ JSON
%% ========================================================================

function data = read_json(filename)
% Read JSON file to MATLAB structure
% Uses jsondecode if available (MATLAB R2016b+), otherwise fallback

    try
        % Try built-in JSON decoder (MATLAB R2016b+)
        fid = fopen(filename, 'r');
        if fid == -1
            error('Cannot open file for reading: %s', filename);
        end
        json_str = fread(fid, '*char')';
        fclose(fid);
        
        data = jsondecode(json_str);
        
    catch
        % Fallback: try external JSON parser or error
        error('gds_merge_solids_3d:JSONReadError', ...
              'Cannot read JSON file. MATLAB R2016b+ required or install external JSON parser.');
    end
end
