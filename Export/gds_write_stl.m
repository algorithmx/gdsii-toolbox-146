function gds_write_stl(solids, filename, options)
% GDS_WRITE_STL - Write 3D solids to STL file
%
% gds_write_stl(solids, filename)
% gds_write_stl(solids, filename, options)
%
% Writes an array of 3D solids to STL format (ASCII or binary)
% This is the MVP implementation - simpler than STEP format
%
% INPUT:
%   solids   : structure array of 3D solids from gds_extrude_polygon()
%              Each solid must have fields:
%                .vertices     - Mx3 matrix of 3D vertices [x y z]
%                .faces        - Cell array or struct defining faces
%                .top_face     - Indices of top face vertices
%                .bottom_face  - Indices of bottom face vertices
%                .side_faces   - Cell array of side face indices
%   filename : output STL file path
%   options  : (Optional) structure with fields:
%       .format - 'ascii' or 'binary' (default: 'binary')
%       .units  - Unit scaling factor (default: 1.0)
%       .solid_name - Name for STL solid (default: 'gds_solid')
%       .merge_solids - Merge all solids into one STL (default: false)
%
% OUTPUT:
%   Writes STL file to disk
%
% EXAMPLE:
%   % Single solid
%   polygon = [0 0; 10 0; 10 10; 0 10; 0 0];
%   solid = gds_extrude_polygon(polygon, 0, 5);
%   gds_write_stl(solid, 'output.stl');
%
%   % Multiple solids with options
%   opts.format = 'ascii';
%   opts.units = 1e-6;  % Convert nm to m
%   gds_write_stl(solids, 'output.stl', opts);
%
% NOTES:
%   - STL format stores triangulated surfaces only
%   - All faces are automatically triangulated
%   - Binary format is more compact and faster
%   - ASCII format is human-readable and debuggable
%
% SEE ALSO: gds_extrude_polygon, gds_write_step, gds_to_step

% Parse options
if nargin < 3
    options = struct();
end

if ~isfield(options, 'format')
    options.format = 'binary';
end

if ~isfield(options, 'units')
    options.units = 1.0;
end

if ~isfield(options, 'solid_name')
    options.solid_name = 'gds_solid';
end

if ~isfield(options, 'merge_solids')
    options.merge_solids = false;
end

% Validate format
if ~ismember(options.format, {'ascii', 'binary'})
    error('gds_write_stl: format must be ''ascii'' or ''binary'' --> %s', options.format);
end

% Ensure solids is an array
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
    error('gds_write_stl: no solids provided');
end

% Write STL file
try
    if strcmp(options.format, 'ascii')
        write_stl_ascii(solids, filename, options);
    else
        write_stl_binary(solids, filename, options);
    end
catch err
    error('gds_write_stl: failed to write STL file --> %s: %s', ...
          filename, err.message);
end

end


%% ASCII STL Writer
function write_stl_ascii(solids, filename, options)
% Write ASCII STL format
%
% ASCII STL format:
% solid name
%   facet normal nx ny nz
%     outer loop
%       vertex x1 y1 z1
%       vertex x2 y2 z2
%       vertex x3 y3 z3
%     endloop
%   endfacet
% endsolid name

fid = fopen(filename, 'w');
if fid == -1
    error('Cannot open file for writing: %s', filename);
end

try
    % Write header
    fprintf(fid, 'solid %s\n', options.solid_name);
    
    % Process each solid
    for solid_idx = 1:length(solids)
        solid = solids{solid_idx};
        
        % Get triangulated faces
        triangles = triangulate_solid(solid, options.units);
        
        % Write each triangle
        for i = 1:size(triangles, 1)
            % Extract triangle vertices
            v1 = triangles(i, 1:3);
            v2 = triangles(i, 4:6);
            v3 = triangles(i, 7:9);
            
            % Calculate normal (right-hand rule)
            edge1 = v2 - v1;
            edge2 = v3 - v1;
            normal = cross(edge1, edge2);
            normal_len = norm(normal);
            if normal_len > eps
                normal = normal / normal_len;
            else
                normal = [0 0 1];  % Degenerate triangle
            end
            
            % Write facet
            fprintf(fid, '  facet normal %e %e %e\n', normal(1), normal(2), normal(3));
            fprintf(fid, '    outer loop\n');
            fprintf(fid, '      vertex %e %e %e\n', v1(1), v1(2), v1(3));
            fprintf(fid, '      vertex %e %e %e\n', v2(1), v2(2), v2(3));
            fprintf(fid, '      vertex %e %e %e\n', v3(1), v3(2), v3(3));
            fprintf(fid, '    endloop\n');
            fprintf(fid, '  endfacet\n');
        end
    end
    
    % Write footer
    fprintf(fid, 'endsolid %s\n', options.solid_name);
    
    fclose(fid);
catch err
    fclose(fid);
    rethrow(err);
end

end


%% Binary STL Writer
function write_stl_binary(solids, filename, options)
% Write binary STL format
%
% Binary STL format:
% UINT8[80]    – Header
% UINT32       – Number of triangles
% For each triangle:
%   REAL32[3]  – Normal vector
%   REAL32[3]  – Vertex 1
%   REAL32[3]  – Vertex 2
%   REAL32[3]  – Vertex 3
%   UINT16     – Attribute byte count (usually 0)

% Collect all triangles first to count them
all_triangles = [];
for solid_idx = 1:length(solids)
    solid = solids{solid_idx};
    triangles = triangulate_solid(solid, options.units);
    all_triangles = [all_triangles; triangles];
end

num_triangles = size(all_triangles, 1);

% Open file for binary writing
fid = fopen(filename, 'wb');
if fid == -1
    error('Cannot open file for writing: %s', filename);
end

try
    % Write header (80 bytes)
    header = sprintf('Binary STL file created by gdsii-toolbox-146 (gds_write_stl)');
    header = [header repmat(' ', 1, 80 - length(header))];
    fwrite(fid, header(1:80), 'char');
    
    % Write number of triangles
    fwrite(fid, num_triangles, 'uint32');
    
    % Write each triangle
    for i = 1:num_triangles
        % Extract triangle vertices
        v1 = all_triangles(i, 1:3);
        v2 = all_triangles(i, 4:6);
        v3 = all_triangles(i, 7:9);
        
        % Calculate normal (right-hand rule)
        edge1 = v2 - v1;
        edge2 = v3 - v1;
        normal = cross(edge1, edge2);
        normal_len = norm(normal);
        if normal_len > eps
            normal = normal / normal_len;
        else
            normal = [0 0 1];  % Degenerate triangle
        end
        
        % Write normal
        fwrite(fid, normal(1), 'float32');
        fwrite(fid, normal(2), 'float32');
        fwrite(fid, normal(3), 'float32');
        
        % Write vertices
        fwrite(fid, v1(1), 'float32');
        fwrite(fid, v1(2), 'float32');
        fwrite(fid, v1(3), 'float32');
        
        fwrite(fid, v2(1), 'float32');
        fwrite(fid, v2(2), 'float32');
        fwrite(fid, v2(3), 'float32');
        
        fwrite(fid, v3(1), 'float32');
        fwrite(fid, v3(2), 'float32');
        fwrite(fid, v3(3), 'float32');
        
        % Write attribute byte count (0)
        fwrite(fid, 0, 'uint16');
    end
    
    fclose(fid);
catch err
    fclose(fid);
    rethrow(err);
end

end


%% Helper: Triangulate solid faces
function triangles = triangulate_solid(solid, unit_scale)
% Convert solid faces to triangle list
% Returns Nx9 matrix where each row is [v1_x v1_y v1_z v2_x v2_y v2_z v3_x v3_y v3_z]

triangles = [];

% Validate solid structure
if ~isfield(solid, 'vertices')
    error('Solid missing vertices field');
end

vertices = solid.vertices * unit_scale;

% Process top face
if isfield(solid, 'top_face') && ~isempty(solid.top_face)
    face_triangles = triangulate_polygon_face(vertices, solid.top_face);
    triangles = [triangles; face_triangles];
end

% Process bottom face
if isfield(solid, 'bottom_face') && ~isempty(solid.bottom_face)
    face_triangles = triangulate_polygon_face(vertices, solid.bottom_face);
    triangles = [triangles; face_triangles];
end

% Process side faces (should already be quads or triangles)
if isfield(solid, 'side_faces') && ~isempty(solid.side_faces)
    for i = 1:length(solid.side_faces)
        face_indices = solid.side_faces{i};
        if length(face_indices) == 3
            % Already a triangle
            v1 = vertices(face_indices(1), :);
            v2 = vertices(face_indices(2), :);
            v3 = vertices(face_indices(3), :);
            triangles = [triangles; [v1 v2 v3]];
        elseif length(face_indices) == 4
            % Quad - split into two triangles
            v1 = vertices(face_indices(1), :);
            v2 = vertices(face_indices(2), :);
            v3 = vertices(face_indices(3), :);
            v4 = vertices(face_indices(4), :);
            triangles = [triangles; [v1 v2 v3]];
            triangles = [triangles; [v1 v3 v4]];
        else
            % General polygon
            face_triangles = triangulate_polygon_face(vertices, face_indices);
            triangles = [triangles; face_triangles];
        end
    end
end

end


%% Helper: Triangulate a single polygon face
function triangles = triangulate_polygon_face(vertices, face_indices)
% Triangulate a polygon face using fan triangulation
% Simple ear-clipping approach from first vertex

triangles = [];
n = length(face_indices);

if n < 3
    return;  % Degenerate face
end

if n == 3
    % Already a triangle
    v1 = vertices(face_indices(1), :);
    v2 = vertices(face_indices(2), :);
    v3 = vertices(face_indices(3), :);
    triangles = [v1 v2 v3];
    return;
end

% Fan triangulation: connect all vertices to first vertex
v1 = vertices(face_indices(1), :);
for i = 2:(n-1)
    v2 = vertices(face_indices(i), :);
    v3 = vertices(face_indices(i+1), :);
    triangles = [triangles; [v1 v2 v3]];
end

end
