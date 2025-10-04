function gds_write_step(solids, filename, options)
% GDS_WRITE_STEP - Write 3D solids to STEP file
%
% gds_write_step(solids, filename)
% gds_write_step(solids, filename, options)
%
% Writes an array of 3D solids to STEP AP203/AP214 format
% Uses Python pythonOCC bridge for STEP generation
%
% INPUT:
%   solids   : structure array of 3D solids from gds_extrude_polygon()
%              Each solid must have fields:
%                .vertices     - Mx3 matrix of 3D vertices [x y z]
%                .faces        - Cell array or struct defining faces
%                .top_face     - Indices of top face vertices
%                .bottom_face  - Indices of bottom face vertices
%                .side_faces   - Cell array of side face indices
%              Optional fields:
%                .material     - Material name (string)
%                .color        - RGB color [r g b] or hex string
%                .layer_name   - Layer name for metadata
%   filename : output STEP file path
%   options  : (Optional) structure with fields:
%       .format     - 'AP203' or 'AP214' (default: 'AP203')
%       .precision  - Geometric tolerance (default: 1e-6)
%       .materials  - Include material metadata (default: true)
%       .units      - Unit scaling factor (default: 1.0)
%       .python_cmd - Python command to use (default: 'python3')
%       .keep_temp  - Keep temporary JSON file (default: false)
%       .verbose    - Print progress messages (default: false)
%
% OUTPUT:
%   Writes STEP file to disk
%
% REQUIRES:
%   - Python 3.x with pythonOCC installed
%   - System python must be accessible via system() calls
%
% INSTALLATION:
%   To install pythonOCC:
%   $ conda install -c conda-forge pythonocc-core
%   or
%   $ pip install pythonocc-core
%
% EXAMPLE:
%   % Single solid
%   polygon = [0 0; 10 0; 10 10; 0 10; 0 0];
%   solid = gds_extrude_polygon(polygon, 0, 5);
%   solid.material = 'aluminum';
%   solid.layer_name = 'Metal1';
%   gds_write_step(solid, 'output.step');
%
%   % Multiple solids with options
%   opts.format = 'AP214';
%   opts.precision = 1e-9;
%   opts.verbose = true;
%   gds_write_step(solids, 'output.step', opts);
%
% NOTES:
%   - STEP format preserves exact geometry (no triangulation)
%   - Supports material properties and metadata
%   - Industry standard for CAD/CAM interchange
%   - Falls back to STL if Python/pythonOCC not available
%
% SEE ALSO: gds_extrude_polygon, gds_write_stl, gds_to_step

% Parse options
if nargin < 3
    options = struct();
end

if ~isfield(options, 'format')
    options.format = 'AP203';
end

if ~isfield(options, 'precision')
    options.precision = 1e-6;
end

if ~isfield(options, 'materials')
    options.materials = true;
end

if ~isfield(options, 'units')
    options.units = 1.0;
end

if ~isfield(options, 'python_cmd')
    options.python_cmd = 'python3';
end

if ~isfield(options, 'keep_temp')
    options.keep_temp = false;
end

if ~isfield(options, 'verbose')
    options.verbose = false;
end

% Validate format
if ~ismember(options.format, {'AP203', 'AP214'})
    error('gds_write_step: format must be ''AP203'' or ''AP214'' --> %s', options.format);
end

% Ensure solids is a cell array
if ~iscell(solids) && isstruct(solids)
    if length(solids) == 1
        solids = {solids};
    else
        % Convert struct array to cell array
        solids_cell = cell(1, length(solids));
        for i = 1:length(solids)
            solids_cell{i} = solids(i);
        end
        solids = solids_cell;
    end
end

% Validate input
if isempty(solids)
    error('gds_write_step: no solids provided');
end

% Check if Python and pythonOCC are available
if ~check_python_available(options.python_cmd)
    warning('gds_write_step: Python not available, falling back to STL format');
    % Fallback to STL
    stl_filename = strrep(filename, '.step', '.stl');
    stl_filename = strrep(stl_filename, '.stp', '.stl');
    if strcmp(stl_filename, filename)
        stl_filename = [filename '.stl'];
    end
    fprintf('Writing STL instead: %s\n', stl_filename);
    gds_write_stl(solids, stl_filename, struct('units', options.units));
    return;
end

if ~check_pythonocc_available(options.python_cmd)
    warning('gds_write_step: pythonOCC not available, falling back to STL format');
    % Fallback to STL
    stl_filename = strrep(filename, '.step', '.stl');
    stl_filename = strrep(stl_filename, '.stp', '.stl');
    if strcmp(stl_filename, filename)
        stl_filename = [filename '.stl'];
    end
    fprintf('Writing STL instead: %s\n', stl_filename);
    gds_write_stl(solids, stl_filename, struct('units', options.units));
    return;
end

% Prepare data for export
if options.verbose
    fprintf('Preparing %d solids for STEP export...\n', length(solids));
end

solid_data = prepare_solid_data(solids, options);

% Create temporary JSON file
temp_json = [tempname '.json'];
try
    write_json_file(solid_data, temp_json);
    
    % Get path to Python script
    script_path = get_python_script_path();
    
    % Call Python script
    if options.verbose
        fprintf('Calling Python STEP writer...\n');
    end
    
    cmd = sprintf('%s "%s" "%s" "%s"', ...
                  options.python_cmd, script_path, temp_json, filename);
    
    [status, output] = system(cmd);
    
    if status ~= 0
        error('gds_write_step: Python script failed --> %s', output);
    end
    
    if options.verbose
        fprintf('STEP file written successfully: %s\n', filename);
        fprintf('Python output: %s\n', output);
    end
    
    % Clean up temporary file
    if ~options.keep_temp && exist(temp_json, 'file')
        delete(temp_json);
    end
    
catch err
    % Clean up on error
    if exist(temp_json, 'file') && ~options.keep_temp
        delete(temp_json);
    end
    rethrow(err);
end

end


%% Helper: Check if Python is available
function available = check_python_available(python_cmd)
% Check if Python command works

[status, ~] = system(sprintf('%s --version', python_cmd));
available = (status == 0);

end


%% Helper: Check if pythonOCC is available
function available = check_pythonocc_available(python_cmd)
% Check if pythonOCC can be imported

test_cmd = sprintf('%s -c "import OCC.Core.BRepPrimAPI"', python_cmd);
[status, ~] = system(test_cmd);
available = (status == 0);

end


%% Helper: Prepare solid data for JSON export
function solid_data = prepare_solid_data(solids, options)
% Convert MATLAB solid structures to JSON-friendly format

solid_data = struct();
solid_data.format = options.format;
solid_data.precision = options.precision;
solid_data.units = options.units;
solid_data.solids = cell(1, length(solids));

for i = 1:length(solids)
    solid = solids{i};
    
    % Required fields
    solid_export = struct();
    solid_export.vertices = solid.vertices * options.units;
    
    % Extract polygon from top face (for extrusion representation)
    if isfield(solid, 'polygon_xy')
        solid_export.polygon = solid.polygon_xy * options.units;
    elseif isfield(solid, 'top_face') && ~isempty(solid.top_face)
        % Extract XY coordinates from top face vertices
        n = length(solid.top_face);
        solid_export.polygon = zeros(n, 2);
        for j = 1:n
            idx = solid.top_face(j);
            solid_export.polygon(j, :) = solid.vertices(idx, 1:2) * options.units;
        end
    else
        error('Cannot extract polygon from solid %d', i);
    end
    
    % Z heights
    if isfield(solid, 'z_bottom')
        solid_export.z_bottom = solid.z_bottom * options.units;
    else
        solid_export.z_bottom = min(solid.vertices(:, 3)) * options.units;
    end
    
    if isfield(solid, 'z_top')
        solid_export.z_top = solid.z_top * options.units;
    else
        solid_export.z_top = max(solid.vertices(:, 3)) * options.units;
    end
    
    % Optional metadata
    if options.materials && isfield(solid, 'material')
        solid_export.material = solid.material;
    end
    
    if isfield(solid, 'color')
        if ischar(solid.color)
            % Hex color string
            solid_export.color = solid.color;
        elseif isnumeric(solid.color) && length(solid.color) == 3
            % RGB triplet
            solid_export.color = sprintf('#%02X%02X%02X', ...
                round(solid.color(1)*255), ...
                round(solid.color(2)*255), ...
                round(solid.color(3)*255));
        end
    end
    
    if isfield(solid, 'layer_name')
        solid_export.layer_name = solid.layer_name;
    end
    
    solid_data.solids{i} = solid_export;
end

end


%% Helper: Write JSON file
function write_json_file(data, filename)
% Write data structure to JSON file
% Uses built-in jsonencode if available, otherwise manual

% Try using built-in JSON encoder (MATLAB R2016b+)
if exist('jsonencode', 'builtin') || exist('jsonencode', 'file')
    json_str = jsonencode(data);
    fid = fopen(filename, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', filename);
    end
    fprintf(fid, '%s', json_str);
    fclose(fid);
else
    % Manual JSON encoding (for older MATLAB/Octave)
    write_json_manual(data, filename);
end

end


%% Helper: Manual JSON writer (fallback)
function write_json_manual(data, filename)
% Manual JSON encoding for older versions

fid = fopen(filename, 'w');
if fid == -1
    error('Cannot open file for writing: %s', filename);
end

try
    fprintf(fid, '{\n');
    fprintf(fid, '  "format": "%s",\n', data.format);
    fprintf(fid, '  "precision": %g,\n', data.precision);
    fprintf(fid, '  "units": %g,\n', data.units);
    fprintf(fid, '  "solids": [\n');
    
    for i = 1:length(data.solids)
        solid = data.solids{i};
        fprintf(fid, '    {\n');
        
        % Polygon
        fprintf(fid, '      "polygon": [\n');
        for j = 1:size(solid.polygon, 1)
            if j < size(solid.polygon, 1)
                fprintf(fid, '        [%g, %g],\n', solid.polygon(j, 1), solid.polygon(j, 2));
            else
                fprintf(fid, '        [%g, %g]\n', solid.polygon(j, 1), solid.polygon(j, 2));
            end
        end
        fprintf(fid, '      ],\n');
        
        % Z heights
        fprintf(fid, '      "z_bottom": %g,\n', solid.z_bottom);
        fprintf(fid, '      "z_top": %g', solid.z_top);
        
        % Optional fields
        if isfield(solid, 'material')
            fprintf(fid, ',\n      "material": "%s"', solid.material);
        end
        if isfield(solid, 'color')
            fprintf(fid, ',\n      "color": "%s"', solid.color);
        end
        if isfield(solid, 'layer_name')
            fprintf(fid, ',\n      "layer_name": "%s"', solid.layer_name);
        end
        
        fprintf(fid, '\n    }');
        if i < length(data.solids)
            fprintf(fid, ',\n');
        else
            fprintf(fid, '\n');
        end
    end
    
    fprintf(fid, '  ]\n');
    fprintf(fid, '}\n');
    
    fclose(fid);
catch err
    fclose(fid);
    rethrow(err);
end

end


%% Helper: Get path to Python script
function script_path = get_python_script_path()
% Get absolute path to step_writer.py

% Get path of this file
this_file = mfilename('fullpath');
this_dir = fileparts(this_file);

% Python script should be in private/ subdirectory
script_path = fullfile(this_dir, 'private', 'step_writer.py');

if ~exist(script_path, 'file')
    error('gds_write_step: Cannot find step_writer.py --> %s', script_path);
end

end
