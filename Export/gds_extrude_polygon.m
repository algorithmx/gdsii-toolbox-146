function solid3d = gds_extrude_polygon(polygon_xy, z_bottom, z_top, varargin)
% GDS_EXTRUDE_POLYGON - Extrude 2D polygon to 3D solid
%
% solid3d = gds_extrude_polygon(polygon_xy, z_bottom, z_top)
% solid3d = gds_extrude_polygon(polygon_xy, z_bottom, z_top, options)
%
% Creates a 3D solid by extruding a 2D polygon along the Z-axis
%
% INPUT:
%   polygon_xy : Nx2 matrix of polygon vertices [x, y]
%   z_bottom   : Bottom Z coordinate
%   z_top      : Top Z coordinate
%   options    : (Optional) structure with fields:
%       .check_orientation - Ensure CCW orientation (default: true)
%       .simplify - Simplify polygon before extrusion (default: false)
%       .tolerance - Tolerance for point comparison (default: 1e-9)
%
% OUTPUT:
%   solid3d : structure representing 3D solid with fields:
%       .vertices     - Mx3 matrix of 3D vertices [x, y, z]
%       .faces        - Cell array of face definitions (vertex indices)
%       .top_face     - Indices of top face vertices
%       .bottom_face  - Indices of bottom face vertices
%       .side_faces   - Cell array of side face indices
%       .num_vertices - Number of vertices
%       .num_faces    - Number of faces
%       .volume       - Volume of the solid (if computable)
%       .bbox         - Bounding box [xmin ymin zmin xmax ymax zmax]
%
% ALGORITHM:
%   1. Validate and orient polygon (CCW for outer boundary)
%   2. Create bottom face at z_bottom
%   3. Create top face at z_top
%   4. For each edge in polygon:
%      - Create rectangular side face connecting bottom and top vertices
%   5. Return structured 3D representation
%
% EXAMPLE:
%   % Simple rectangle
%   poly = [0 0; 10 0; 10 5; 0 5; 0 0];
%   solid = gds_extrude_polygon(poly, 0, 2);
%   fprintf('Created solid with %d vertices and %d faces\n', ...
%           solid.num_vertices, solid.num_faces);
%
% SEE ALSO: gds_layer_to_3d, gds_write_stl, gds_write_step

    % Parse optional arguments
    if nargin < 4
        options = struct();
    else
        if isstruct(varargin{1})
            options = varargin{1};
        else
            options = struct();
        end
    end
    
    % Set default options
    if ~isfield(options, 'check_orientation')
        options.check_orientation = true;
    end
    if ~isfield(options, 'simplify')
        options.simplify = false;
    end
    if ~isfield(options, 'tolerance')
        options.tolerance = 1e-9;
    end
    
    % Validate inputs
    if ~isnumeric(polygon_xy) || size(polygon_xy, 2) ~= 2
        error('gds_extrude_polygon: polygon_xy must be Nx2 numeric matrix');
    end
    
    if ~isnumeric(z_bottom) || ~isscalar(z_bottom)
        error('gds_extrude_polygon: z_bottom must be a numeric scalar');
    end
    
    if ~isnumeric(z_top) || ~isscalar(z_top)
        error('gds_extrude_polygon: z_top must be a numeric scalar');
    end
    
    if z_top <= z_bottom
        error('gds_extrude_polygon: z_top must be greater than z_bottom');
    end
    
    % Check for minimum number of vertices
    if size(polygon_xy, 1) < 3
        error('gds_extrude_polygon: polygon must have at least 3 vertices');
    end
    
    % Clean polygon: remove duplicate consecutive points
    polygon_xy = remove_duplicate_points(polygon_xy, options.tolerance);
    
    % Ensure polygon is closed (first point = last point)
    if norm(polygon_xy(1,:) - polygon_xy(end,:)) > options.tolerance
        % Not closed, close it
        polygon_xy = [polygon_xy; polygon_xy(1,:)];
    end
    
    % Remove the duplicate closing point for processing
    n_points = size(polygon_xy, 1) - 1;
    polygon_xy = polygon_xy(1:n_points, :);
    
    % Check orientation and reorient if necessary
    if options.check_orientation
        if ~is_ccw(polygon_xy)
            % Reverse to make counter-clockwise
            polygon_xy = flipud(polygon_xy);
        end
    end
    
    % Simplify polygon if requested
    if options.simplify
        polygon_xy = simplify_polygon(polygon_xy, options.tolerance);
        n_points = size(polygon_xy, 1);
    end
    
    % Create 3D vertices
    % Bottom vertices: indices 1 to n_points
    % Top vertices: indices (n_points+1) to 2*n_points
    num_vertices = 2 * n_points;
    vertices = zeros(num_vertices, 3);
    
    % Bottom face vertices at z_bottom
    vertices(1:n_points, 1:2) = polygon_xy;
    vertices(1:n_points, 3) = z_bottom;
    
    % Top face vertices at z_top
    vertices(n_points+1:2*n_points, 1:2) = polygon_xy;
    vertices(n_points+1:2*n_points, 3) = z_top;
    
    % Create faces
    % Bottom face (indices 1 to n_points, ordered CCW when viewed from below)
    bottom_face = 1:n_points;
    
    % Top face (indices n_points+1 to 2*n_points, ordered CCW when viewed from above)
    top_face = n_points + (1:n_points);
    
    % Side faces: one rectangular face for each edge
    side_faces = cell(n_points, 1);
    for i = 1:n_points
        % Current edge: from vertex i to vertex i+1 (wrapping around)
        next_i = mod(i, n_points) + 1;
        
        % Bottom vertices: i and next_i
        % Top vertices: n_points+i and n_points+next_i
        % Face vertices in CCW order (when viewed from outside)
        side_faces{i} = [i, next_i, n_points+next_i, n_points+i];
    end
    
    % Combine all faces
    faces = cell(2 + n_points, 1);
    faces{1} = bottom_face;
    faces{2} = top_face;
    for i = 1:n_points
        faces{2+i} = side_faces{i};
    end
    
    % Calculate volume using the signed volume of tetrahedra method
    % For a closed polyhedron, sum of signed volumes of tetrahedra from origin
    volume = calculate_volume(vertices, faces);
    
    % Calculate bounding box
    bbox = [min(vertices(:,1)), min(vertices(:,2)), min(vertices(:,3)), ...
            max(vertices(:,1)), max(vertices(:,2)), max(vertices(:,3))];
    
    % Create output structure
    solid3d = struct();
    solid3d.vertices = vertices;
    solid3d.faces = faces;
    solid3d.top_face = top_face;
    solid3d.bottom_face = bottom_face;
    solid3d.side_faces = side_faces;
    solid3d.num_vertices = num_vertices;
    solid3d.num_faces = length(faces);
    solid3d.volume = volume;
    solid3d.bbox = bbox;
    
    % Add metadata
    solid3d.z_bottom = z_bottom;
    solid3d.z_top = z_top;
    solid3d.height = z_top - z_bottom;
    solid3d.base_area = polygon_area(polygon_xy);
    
end

%% Helper Functions

function clean_poly = remove_duplicate_points(poly, tolerance)
    % Remove consecutive duplicate points
    if size(poly, 1) < 2
        clean_poly = poly;
        return;
    end
    
    keep = true(size(poly, 1), 1);
    for i = 2:size(poly, 1)
        if norm(poly(i,:) - poly(i-1,:)) < tolerance
            keep(i) = false;
        end
    end
    
    clean_poly = poly(keep, :);
end

function ccw = is_ccw(poly)
    % Determine if polygon is counter-clockwise using signed area
    % Positive area = CCW, negative area = CW
    area = polygon_area(poly);
    ccw = (area > 0);
end

function area = polygon_area(poly)
    % Calculate signed area of polygon using shoelace formula
    % Positive = CCW, negative = CW
    n = size(poly, 1);
    area = 0;
    for i = 1:n
        next_i = mod(i, n) + 1;
        area = area + (poly(i,1) * poly(next_i,2) - poly(next_i,1) * poly(i,2));
    end
    area = area / 2;
end

function simple_poly = simplify_polygon(poly, tolerance)
    % Simplify polygon by removing collinear points
    % Uses Douglas-Peucker style simplification
    
    if size(poly, 1) <= 3
        simple_poly = poly;
        return;
    end
    
    keep = false(size(poly, 1), 1);
    keep(1) = true;  % Always keep first point
    keep(end) = true;  % Always keep last point
    
    for i = 2:size(poly, 1)-1
        prev = poly(i-1, :);
        curr = poly(i, :);
        next = poly(i+1, :);
        
        % Check if current point is collinear with neighbors
        % Two approaches:
        % 1. Check if the three points are collinear using cross product
        % 2. Also check if point lies exactly on the line segment
        
        v1 = curr - prev;
        v2 = next - prev;
        
        % Normalize for better numerical stability
        len_v1 = norm(v1);
        len_v2 = norm(v2);
        
        if len_v1 < tolerance || len_v2 < tolerance
            % Point is too close to neighbors, skip it
            continue;
        end
        
        % Cross product test
        cross_prod = v1(1)*v2(2) - v1(2)*v2(1);
        
        % Keep point if not collinear
        if abs(cross_prod) > tolerance * len_v1 * len_v2
            keep(i) = true;
        end
    end
    
    simple_poly = poly(keep, :);
end

function volume = calculate_volume(vertices, faces)
    % Calculate volume of closed polyhedron using divergence theorem
    % Volume = (1/6) * sum over faces of (face_area * face_normal dot face_centroid)
    
    volume = 0;
    
    % Skip first two faces (bottom and top) and process side faces
    % For an extruded polygon, we can use a simpler formula:
    % Volume = base_area * height
    
    % Get bottom face vertices
    bottom_face_idx = faces{1};
    bottom_vertices = vertices(bottom_face_idx, :);
    
    % Calculate base area (all z-coordinates should be the same)
    base_area = abs(polygon_area(bottom_vertices(:, 1:2)));
    
    % Calculate height
    z_bottom = vertices(bottom_face_idx(1), 3);
    top_face_idx = faces{2};
    z_top = vertices(top_face_idx(1), 3);
    height = z_top - z_bottom;
    
    % Volume
    volume = base_area * height;
end
