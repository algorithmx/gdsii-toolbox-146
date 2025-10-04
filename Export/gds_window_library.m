function windowed_output = gds_window_library(gds_input, window_bbox, varargin)
% GDS_WINDOW_LIBRARY - Extract elements within bounding box window
%
% windowed_output = gds_window_library(gds_input, window_bbox)
% windowed_output = gds_window_library(gds_input, window_bbox, 'param', value, ...)
%
% Creates new library or structure containing only elements within the
% specified rectangular window. This is useful for extracting regions of
% interest from large chip designs for faster 3D processing.
%
% INPUT:
%   gds_input   : gds_library or gds_structure object to filter
%   window_bbox : [xmin ymin xmax ymax] bounding box in user units
%   
%   Optional parameter/value pairs:
%       'clip'      - Clip polygons at window boundary (default: false)
%                     If false, includes entire polygons that intersect window
%                     If true, clips polygons to window boundary
%       'margin'    - Extend window by margin in all directions (default: 0)
%       'verbose'   - Verbosity level 0/1/2 (default: 1)
%       'structure_name' - Name of specific structure to filter (library only)
%
% OUTPUT:
%   windowed_output : gds_library or gds_structure (same type as input)
%                     containing only filtered elements
%
% EXAMPLES:
%   % Extract 1000x1000 um region from chip
%   glib = read_gds_library('chip.gds');
%   windowed = gds_window_library(glib, [0 0 1000 1000]);
%   
%   % Extract with margin for context
%   windowed = gds_window_library(glib, [0 0 1000 1000], 'margin', 50);
%   
%   % Extract and clip polygons at boundary
%   windowed = gds_window_library(glib, [0 0 1000 1000], ...
%                                 'clip', true, 'verbose', 2);
%   
%   % Extract from specific structure
%   windowed = gds_window_library(glib, [0 0 1000 1000], ...
%                                 'structure_name', 'TopCell');
%
% PERFORMANCE NOTES:
%   - For large designs, windowing significantly reduces processing time
%   - Element filtering is fast (bounding box tests only)
%   - Polygon clipping is slower but more precise
%   - Use margin=0 and clip=false for fastest extraction
%
% USE CASE:
%   Large chip designs often contain millions of polygons. When only
%   a specific region is needed for 3D analysis, windowing extracts
%   just that region, reducing memory usage and processing time.
%
% SEE ALSO:
%   gds_to_step, gds_layer_to_3d, bbox
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Implementation of Section 4.9 from GDS_TO_STEP_IMPLEMENTATION_PLAN.md
%   Part of gdsii-toolbox-146 GDSII-to-STEP implementation
%

% =========================================================================
% INPUT VALIDATION
% =========================================================================

    if nargin < 2
        error('gds_window_library:MissingInput', ...
              'Two arguments required: gds_input and window_bbox');
    end
    
    % Validate input type
    if ~isa(gds_input, 'gds_library') && ~isa(gds_input, 'gds_structure')
        error('gds_window_library:InvalidInput', ...
              'First argument must be gds_library or gds_structure object');
    end
    
    % Validate window bbox
    if ~isnumeric(window_bbox) || length(window_bbox) ~= 4
        error('gds_window_library:InvalidWindow', ...
              'window_bbox must be [xmin ymin xmax ymax]');
    end
    
    window_bbox = window_bbox(:)';  % Ensure row vector
    
    if window_bbox(1) >= window_bbox(3) || window_bbox(2) >= window_bbox(4)
        error('gds_window_library:InvalidWindow', ...
              'Invalid window: xmin < xmax and ymin < ymax required');
    end

% =========================================================================
% PARSE OPTIONAL PARAMETERS
% =========================================================================

    % Default options
    options.clip = false;
    options.margin = 0;
    options.verbose = 1;
    options.structure_name = '';
    
    % Parse parameter/value pairs
    k = 1;
    while k <= length(varargin)
        if ~ischar(varargin{k}) && ~isstring(varargin{k})
            error('gds_window_library:InvalidParameter', ...
                  'Parameter names must be strings');
        end
        
        param_name = lower(char(varargin{k}));
        
        if k == length(varargin)
            error('gds_window_library:MissingValue', ...
                  'Parameter "%s" has no value', varargin{k});
        end
        
        param_value = varargin{k+1};
        
        switch param_name
            case 'clip'
                options.clip = logical(param_value);
            case 'margin'
                if ~isnumeric(param_value) || ~isscalar(param_value)
                    error('gds_window_library:InvalidMargin', ...
                          'Margin must be a numeric scalar');
                end
                options.margin = double(param_value);
            case 'verbose'
                if ~isnumeric(param_value) || ~isscalar(param_value)
                    error('gds_window_library:InvalidVerbose', ...
                          'Verbose must be 0, 1, or 2');
                end
                options.verbose = round(param_value);
            case 'structure_name'
                options.structure_name = char(param_value);
            otherwise
                warning('gds_window_library:UnknownParameter', ...
                        'Unknown parameter: %s', varargin{k});
        end
        
        k = k + 2;
    end

% =========================================================================
% APPLY MARGIN TO WINDOW
% =========================================================================

    if options.margin ~= 0
        window_bbox(1) = window_bbox(1) - options.margin;
        window_bbox(2) = window_bbox(2) - options.margin;
        window_bbox(3) = window_bbox(3) + options.margin;
        window_bbox(4) = window_bbox(4) + options.margin;
        
        if options.verbose >= 2
            fprintf('Window with margin [%.3f %.3f %.3f %.3f]:\n', window_bbox);
        end
    end

% =========================================================================
% DISPATCH TO LIBRARY OR STRUCTURE HANDLER
% =========================================================================

    t_start = tic;
    
    if options.verbose >= 1
        fprintf('\n=== GDS Window Extraction ===\n');
        fprintf('Window: [%.3f %.3f %.3f %.3f]\n', window_bbox);
        fprintf('Margin: %.3f\n', options.margin);
        fprintf('Clipping: %s\n', bool_str(options.clip));
        fprintf('=============================\n\n');
    end
    
    if isa(gds_input, 'gds_library')
        windowed_output = window_library(gds_input, window_bbox, options);
    else
        windowed_output = window_structure(gds_input, window_bbox, options);
    end
    
    if options.verbose >= 1
        fprintf('\n=== Window Extraction Complete ===\n');
        fprintf('Processing time: %.3f seconds\n', toc(t_start));
        fprintf('==================================\n\n');
    end

end


%% ========================================================================
%% HELPER FUNCTION: WINDOW LIBRARY
%% ========================================================================

function windowed_lib = window_library(glib, window_bbox, options)
% Filter a gds_library by window
%
% Strategy:
%   - Create new library with same metadata
%   - Filter each structure (or specified structure)
%   - Copy structures with filtered elements

    if options.verbose >= 1
        fprintf('Processing gds_library: %s\n', get(glib, 'lname'));
        fprintf('Total structures: %d\n\n', length(glib));
    end
    
    % Get structures to process
    if ~isempty(options.structure_name)
        % Process specific structure
        try
            gstruct_cell = getstruct(glib, options.structure_name);
            structs_to_process = gstruct_cell;
            struct_names = {options.structure_name};
        catch
            error('gds_window_library:StructureNotFound', ...
                  'Structure "%s" not found in library', options.structure_name);
        end
    else
        % Process all structures
        structs_to_process = glib.st;
        struct_names = cell(1, length(structs_to_process));
        for k = 1:length(structs_to_process)
            struct_names{k} = sname(structs_to_process{k});
        end
    end
    
    % Create new library with same metadata
    windowed_lib = gds_library(get(glib, 'lname'), ...
                                'uunit', get(glib, 'uunit'), ...
                                'dbunit', get(glib, 'dbunit'));
    
    % Filter each structure
    for k = 1:length(structs_to_process)
        gstruct = structs_to_process{k};
        struct_name = struct_names{k};
        
        if options.verbose >= 1
            fprintf('Filtering structure %d/%d: %s\n', ...
                    k, length(structs_to_process), struct_name);
        end
        
        % Window the structure
        windowed_struct = window_structure(gstruct, window_bbox, options);
        
        % Only add structure if it has elements
        if numel(windowed_struct) > 0
            windowed_lib = add_struct(windowed_lib, windowed_struct);
            
            if options.verbose >= 2
                fprintf('  Added structure with %d elements\n', numel(windowed_struct));
            end
        else
            if options.verbose >= 2
                fprintf('  Skipped empty structure\n');
            end
        end
    end
    
    if options.verbose >= 1
        fprintf('\nFiltered library contains %d structure(s)\n', length(windowed_lib));
    end

end


%% ========================================================================
%% HELPER FUNCTION: WINDOW STRUCTURE
%% ========================================================================

function windowed_struct = window_structure(gstruct, window_bbox, options)
% Filter a gds_structure by window
%
% Strategy:
%   - Iterate through all elements
%   - Check if element bbox intersects window
%   - If clip=true, clip polygon elements to window boundary
%   - Create new structure with filtered elements

    xmin = window_bbox(1);
    ymin = window_bbox(2);
    xmax = window_bbox(3);
    ymax = window_bbox(4);
    
    % Get all elements
    el_cell = gstruct(:);
    num_elements = length(el_cell);
    
    if options.verbose >= 2
        fprintf('  Processing %d elements...\n', num_elements);
    end
    
    % Collect filtered elements
    filtered_elements = {};
    elements_kept = 0;
    elements_clipped = 0;
    elements_discarded = 0;
    
    for k = 1:num_elements
        gel = el_cell{k};
        
        % Get element bounding box
        try
            el_bbox = bbox(gel);
        catch
            % Element has no bbox (e.g., text, node) - keep it if requested
            if options.verbose >= 2
                fprintf('  Element %d: no bbox (type=%s), keeping\n', k, etype(gel));
            end
            filtered_elements{end+1} = gel;
            elements_kept = elements_kept + 1;
            continue;
        end
        
        % Check if element bbox is valid
        if any(isinf(el_bbox))
            % Invalid bbox (e.g., reference elements)
            % Keep reference elements - they'll be resolved during flattening
            if is_ref(gel)
                filtered_elements{end+1} = gel;
                elements_kept = elements_kept + 1;
            else
                elements_discarded = elements_discarded + 1;
            end
            continue;
        end
        
        % Test for overlap with window
        el_xmin = el_bbox(1);
        el_ymin = el_bbox(2);
        el_xmax = el_bbox(3);
        el_ymax = el_bbox(4);
        
        % Check if bounding boxes overlap
        overlaps = (el_xmax >= xmin && el_xmin <= xmax && ...
                    el_ymax >= ymin && el_ymin <= ymax);
        
        if ~overlaps
            % Element completely outside window
            elements_discarded = elements_discarded + 1;
            continue;
        end
        
        % Element overlaps window - process it
        if options.clip && is_boundary_like(gel)
            % Clip polygon to window boundary
            try
                clipped_el = clip_element_to_window(gel, window_bbox);
                % Check if result is empty (for arrays/matrices, empty means [])
                if isempty(clipped_el)
                    % Clipping produced no valid polygon
                    if options.verbose >= 2
                        fprintf('  Element %d: clipping produced empty result\n', k);
                    end
                    elements_discarded = elements_discarded + 1;
                else
                    % Valid clipped element
                    filtered_elements{end+1} = clipped_el;
                    elements_clipped = elements_clipped + 1;
                end
            catch ME
                % Clipping failed - keep original element
                if options.verbose >= 2
                    fprintf('  Element %d: clipping failed (%s), keeping original\n', ...
                            k, ME.message);
                end
                filtered_elements{end+1} = gel;
                elements_kept = elements_kept + 1;
            end
        else
            % Keep entire element (no clipping)
            filtered_elements{end+1} = gel;
            elements_kept = elements_kept + 1;
        end
    end
    
    % Create new structure with filtered elements
    windowed_struct = gds_structure(sname(gstruct));
    
    for k = 1:length(filtered_elements)
        windowed_struct = add_element(windowed_struct, filtered_elements{k});
    end
    
    if options.verbose >= 2
        fprintf('  Elements kept: %d, clipped: %d, discarded: %d\n', ...
                elements_kept, elements_clipped, elements_discarded);
    end

end


%% ========================================================================
%% HELPER FUNCTION: CLIP ELEMENT TO WINDOW
%% ========================================================================

function clipped_el = clip_element_to_window(gel, window_bbox)
% Clip a boundary/box element to window using polygon clipping
%
% This uses the Sutherland-Hodgman polygon clipping algorithm
% to clip polygons at the window boundary.

    el_type = etype(gel);
    
    if ~ismember(el_type, {'boundary', 'box'})
        % Not a polygon element - return as-is
        clipped_el = gel;
        return;
    end
    
    % Get polygon data
    xy_data = xy(gel);
    
    if ~iscell(xy_data)
        xy_data = {xy_data};
    end
    
    % Clip each polygon
    clipped_polys = {};
    for k = 1:length(xy_data)
        poly = xy_data{k};
        clipped_poly = clip_polygon_to_rect(poly, window_bbox);
        
        if ~isempty(clipped_poly) && size(clipped_poly, 1) >= 3
            clipped_polys{end+1} = clipped_poly;
        end
    end
    
    if isempty(clipped_polys)
        % No polygons remain after clipping
        clipped_el = [];
        return;
    end
    
    % Create new element with clipped polygons
    % Preserve layer, datatype, and other properties
    el_layer = get(gel, 'layer');
    el_dtype = get(gel, 'dtype');
    
    % Ensure polygons are properly closed for GDSII format
    for k = 1:length(clipped_polys)
        poly = clipped_polys{k};
        if size(poly, 1) > 0 && ~isequal(poly(1,:), poly(end,:))
            clipped_polys{k} = [poly; poly(1,:)];
        end
    end
    
    if length(clipped_polys) == 1
        xy_out = clipped_polys{1};
    else
        xy_out = clipped_polys;
    end
    
    clipped_el = gds_element('boundary', 'xy', xy_out, ...
                             'layer', el_layer, 'dtype', el_dtype);

end


%% ========================================================================
%% HELPER FUNCTION: CLIP POLYGON TO RECTANGLE
%% ========================================================================

function clipped = clip_polygon_to_rect(poly, rect)
% Sutherland-Hodgman polygon clipping algorithm
%
% INPUT:
%   poly : Nx2 matrix of polygon vertices
%   rect : [xmin ymin xmax ymax] clipping rectangle
%
% OUTPUT:
%   clipped : Mx2 matrix of clipped polygon vertices (M may be 0)

    xmin = rect(1);
    ymin = rect(2);
    xmax = rect(3);
    ymax = rect(4);
    
    % Ensure polygon is not closed (remove duplicate last point if present)
    if size(poly, 1) > 1 && isequal(poly(1,:), poly(end,:))
        poly = poly(1:end-1, :);
    end
    
    if size(poly, 1) < 3
        clipped = [];
        return;
    end
    
    % Clip against each edge in sequence
    % Left edge (x = xmin)
    poly = clip_against_edge(poly, [xmin ymin], [xmin ymax]);
    if isempty(poly) || size(poly, 1) < 3, clipped = []; return; end
    
    % Right edge (x = xmax)
    poly = clip_against_edge(poly, [xmax ymax], [xmax ymin]);
    if isempty(poly) || size(poly, 1) < 3, clipped = []; return; end
    
    % Bottom edge (y = ymin)
    poly = clip_against_edge(poly, [xmax ymin], [xmin ymin]);
    if isempty(poly) || size(poly, 1) < 3, clipped = []; return; end
    
    % Top edge (y = ymax)
    poly = clip_against_edge(poly, [xmin ymax], [xmax ymax]);
    if isempty(poly) || size(poly, 1) < 3, clipped = []; return; end
    
    clipped = poly;

end


%% ========================================================================
%% HELPER FUNCTION: CLIP AGAINST EDGE
%% ========================================================================

function output = clip_against_edge(input_poly, edge_p1, edge_p2)
% Clip polygon against a single edge (Sutherland-Hodgman step)
%
% INPUT:
%   input_poly : Nx2 matrix of polygon vertices
%   edge_p1    : First point of edge [x y]
%   edge_p2    : Second point of edge [x y]
%
% OUTPUT:
%   output : Mx2 matrix of clipped vertices

    if size(input_poly, 1) < 3
        output = [];
        return;
    end
    
    output = [];
    n = size(input_poly, 1);
    
    % Close the polygon for edge processing
    S = input_poly(end, :);  % Start with last vertex
    
    for k = 1:n
        E = input_poly(k, :);  % Current vertex
        
        if inside(E, edge_p1, edge_p2)
            if ~inside(S, edge_p1, edge_p2)
                % Crossing from outside to inside
                I = intersect_point(S, E, edge_p1, edge_p2);
                output = [output; I];
            end
            % End point is inside
            output = [output; E];
        elseif inside(S, edge_p1, edge_p2)
            % Crossing from inside to outside
            I = intersect_point(S, E, edge_p1, edge_p2);
            output = [output; I];
        end
        % else both outside - add nothing
        
        S = E;  % Move to next edge
    end

end


%% ========================================================================
%% HELPER FUNCTION: INSIDE TEST
%% ========================================================================

function result = inside(point, edge_p1, edge_p2)
% Test if point is on the inside of an edge
%
% "Inside" is defined as the left side when traveling from edge_p1 to edge_p2
% Uses cross product sign

    % Cross product: (edge_p2 - edge_p1) x (point - edge_p1)
    cross = (edge_p2(1) - edge_p1(1)) * (point(2) - edge_p1(2)) - ...
            (edge_p2(2) - edge_p1(2)) * (point(1) - edge_p1(1));
    
    result = (cross >= 0);

end


%% ========================================================================
%% HELPER FUNCTION: LINE INTERSECTION
%% ========================================================================

function I = intersect_point(p1, p2, edge_p1, edge_p2)
% Find intersection point between line segment (p1,p2) and edge (edge_p1,edge_p2)
%
% Uses parametric line intersection

    x1 = p1(1); y1 = p1(2);
    x2 = p2(1); y2 = p2(2);
    x3 = edge_p1(1); y3 = edge_p1(2);
    x4 = edge_p2(1); y4 = edge_p2(2);
    
    denom = (x1-x2)*(y3-y4) - (y1-y2)*(x3-x4);
    
    if abs(denom) < 1e-10
        % Lines are parallel - return midpoint
        I = (p1 + p2) / 2;
        return;
    end
    
    t = ((x1-x3)*(y3-y4) - (y1-y3)*(x3-x4)) / denom;
    
    I = [x1 + t*(x2-x1), y1 + t*(y2-y1)];

end


%% ========================================================================
%% HELPER FUNCTION: IS BOUNDARY-LIKE
%% ========================================================================

function result = is_boundary_like(gel)
% Check if element is a boundary or box (polygon element)

    el_type = etype(gel);
    result = ismember(el_type, {'boundary', 'box'});

end


%% ========================================================================
%% HELPER FUNCTION: BOOL TO STRING
%% ========================================================================

function str = bool_str(val)
% Convert boolean to 'true'/'false' string

    if val
        str = 'true';
    else
        str = 'false';
    end

end
