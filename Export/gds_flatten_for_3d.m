function gstruct_flat = gds_flatten_for_3d(gds_input, varargin)
%function gstruct_flat = gds_flatten_for_3d(gds_input, varargin)
%
% GDS_FLATTEN_FOR_3D - Flatten GDSII hierarchy for 3D conversion
%
% Recursively resolves structure hierarchy by replacing sref (structure
% reference) and aref (array reference) elements with transformed copies
% of the referenced structures. All transformations (rotation, reflection,
% magnification, translation) are applied correctly according to GDSII
% specification.
%
% INPUT:
%   gds_input : Either a gds_library or gds_structure object
%               - If gds_library: flattens specified or top-level structure
%               - If gds_structure: flattens that structure
%
%   Optional parameter/value pairs:
%       'structure_name'  - Name of structure to flatten (for gds_library input)
%                           If not specified, uses top-level structure
%       'max_depth'       - Maximum recursion depth (default: unlimited = -1)
%       'verbose'         - Verbosity level 0/1/2 (default: 0)
%
% OUTPUT:
%   gstruct_flat : gds_structure object with all references resolved
%                  Contains only boundary, path, box, text, and node elements
%                  All sref and aref elements are replaced with transformed
%                  copies of their referenced structures
%
% ALGORITHM:
%   1. Build structure lookup table from library
%   2. For each structure, recursively flatten references bottom-up
%   3. For each sref element:
%      - Retrieve referenced structure
%      - Apply strans transformation (reflection, rotation, magnification)
%      - Translate to reference position
%      - Replace sref with transformed elements
%   4. For each aref element:
%      - Retrieve referenced structure
%      - Apply strans to individual instances
%      - Replicate across array with proper spacing
%      - Replace aref with all array instances
%
% TRANSFORMATION ORDER (per GDSII spec):
%   1. Reflection about x-axis (if strans.reflect = 1)
%   2. Rotation by strans.angle degrees
%   3. Magnification by strans.mag factor
%   4. Translation to reference xy position
%
% EXAMPLES:
%   % Flatten a library's top structure
%   glib = read_gds_library('design.gds');
%   gstruct_flat = gds_flatten_for_3d(glib);
%
%   % Flatten specific structure with verbose output
%   gstruct_flat = gds_flatten_for_3d(glib, ...
%                      'structure_name', 'TopCell', ...
%                      'verbose', 2);
%
%   % Flatten with depth limit
%   gstruct_flat = gds_flatten_for_3d(glib, 'max_depth', 5);
%
%   % Flatten a structure directly
%   gstruct = glib{'CellName'};
%   gstruct_flat = gds_flatten_for_3d(gstruct);
%
% NOTES:
%   - This function does NOT convert paths to boundaries (use poly_convert)
%   - Text and node elements are preserved but not transformed
%   - Handles nested references (references within references)
%   - Preserves layer/datatype information
%   - Absolute magnification/angle (strans.absmag, strans.absang) not supported
%   - Very deep hierarchies may cause stack overflow or long processing times
%
% PERFORMANCE:
%   - Complexity: O(N * D) where N = elements, D = hierarchy depth
%   - Memory: Proportional to flattened element count
%   - For large designs with deep hierarchies, consider max_depth limit
%
% SEE ALSO:
%   poly_convert, gds_layer_to_3d, gds_to_step, adjmatrix, topstruct
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Part of gdsii-toolbox-146 GDSII-to-STEP implementation
%   Implementation of Section 4.8 from GDS_TO_STEP_IMPLEMENTATION_PLAN.md
%

% =========================================================================
% INPUT VALIDATION AND PARAMETER PARSING
% =========================================================================

    % Check minimum arguments
    if nargin < 1
        error('gds_flatten_for_3d:MissingInput', ...
              'At least one argument required: gds_input');
    end
    
    % Validate input type
    if ~isa(gds_input, 'gds_library') && ~isa(gds_input, 'gds_structure')
        error('gds_flatten_for_3d:InvalidInput', ...
              'Input must be a gds_library or gds_structure object');
    end
    
    % Parse optional parameters
    params = parse_parameters(varargin{:});
    
    % Start timing
    if params.verbose >= 1
        fprintf('\n');
        fprintf('========================================\n');
        fprintf('  Flattening GDSII Hierarchy for 3D\n');
        fprintf('========================================\n');
        t_start = tic;
    end

% =========================================================================
% GET TARGET STRUCTURE AND BUILD STRUCTURE LOOKUP
% =========================================================================

    % Determine if input is library or structure
    if isa(gds_input, 'gds_library')
        glib = gds_input;
        
        % Get target structure
        if isempty(params.structure_name)
            % Use top-level structure
            try
                top_structs = topstruct(glib);
                if isempty(top_structs)
                    error('gds_flatten_for_3d:NoTopStruct', ...
                          'Cannot find top-level structure in library');
                end
                target_name = top_structs{1};
                if params.verbose >= 1
                    fprintf('Target structure: %s (top-level)\n', target_name);
                end
            catch ME
                error('gds_flatten_for_3d:TopStructError', ...
                      'Failed to identify top structure: %s', ME.message);
            end
        else
            target_name = params.structure_name;
            if params.verbose >= 1
                fprintf('Target structure: %s (user-specified)\n', target_name);
            end
        end
        
        % Build structure lookup table from library
        struct_map = build_structure_map(glib);
        
        % Get target structure
        if ~isKey(struct_map, target_name)
            error('gds_flatten_for_3d:StructureNotFound', ...
                  'Structure "%s" not found in library', target_name);
        end
        gstruct = struct_map(target_name);
        
    else
        % Input is already a structure
        gstruct = gds_input;
        target_name = get(gstruct, 'sname');
        
        if params.verbose >= 1
            fprintf('Target structure: %s\n', target_name);
        end
        
        % Build structure map with just this structure (limited flattening)
        % This will only work if all referenced structures are available
        % For now, create a minimal map with just this structure
        struct_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
        struct_map(target_name) = gstruct;
        
        % Note: If gstruct references other structures not in map,
        % those references will be skipped with a warning
    end

% =========================================================================
% FLATTEN STRUCTURE HIERARCHY
% =========================================================================

    if params.verbose >= 1
        fprintf('Max depth: %s\n', ...
                iif(params.max_depth < 0, 'unlimited', num2str(params.max_depth)));
        fprintf('========================================\n\n');
        fprintf('Flattening structure hierarchy...\n');
    end
    
    % Flatten recursively
    [gstruct_flat, stats] = flatten_structure(gstruct, struct_map, params, 0);
    
    % Report results
    if params.verbose >= 1
        elapsed = toc(t_start);
        fprintf('\n');
        fprintf('========================================\n');
        fprintf('  Flattening Summary\n');
        fprintf('========================================\n');
        fprintf('References resolved:  %d\n', stats.refs_resolved);
        fprintf('Array refs resolved:  %d\n', stats.arefs_resolved);
        fprintf('Elements created:     %d\n', stats.elements_created);
        fprintf('Max depth reached:    %d\n', stats.max_depth_reached);
        fprintf('Processing time:      %.3f seconds\n', elapsed);
        fprintf('========================================\n\n');
    end

end


%% ========================================================================
%% HELPER FUNCTION: PARSE PARAMETERS
%% ========================================================================

function params = parse_parameters(varargin)
% Parse optional parameter/value pairs

    % Default parameters
    params.structure_name = '';
    params.max_depth = -1;  % Unlimited
    params.verbose = 0;
    
    % Parse varargin
    k = 1;
    while k <= length(varargin)
        if ~ischar(varargin{k}) && ~isstring(varargin{k})
            error('gds_flatten_for_3d:InvalidParameter', ...
                  'Parameter names must be strings');
        end
        
        param_name = lower(char(varargin{k}));
        
        if k == length(varargin)
            error('gds_flatten_for_3d:MissingValue', ...
                  'Parameter "%s" has no value', varargin{k});
        end
        
        param_value = varargin{k+1};
        
        switch param_name
            case 'structure_name'
                params.structure_name = char(param_value);
                
            case 'max_depth'
                if ~isnumeric(param_value) || ~isscalar(param_value)
                    error('gds_flatten_for_3d:InvalidMaxDepth', ...
                          'max_depth must be a numeric scalar');
                end
                params.max_depth = round(param_value);
                
            case 'verbose'
                if ~isnumeric(param_value) || ~isscalar(param_value)
                    error('gds_flatten_for_3d:InvalidVerbose', ...
                          'verbose must be 0, 1, or 2');
                end
                params.verbose = round(param_value);
                
            otherwise
                warning('gds_flatten_for_3d:UnknownParameter', ...
                        'Unknown parameter: %s', varargin{k});
        end
        
        k = k + 2;
    end
end


%% ========================================================================
%% HELPER FUNCTION: BUILD STRUCTURE MAP
%% ========================================================================

function struct_map = build_structure_map(glib)
% Build a map from structure names to gds_structure objects

    num_structs = length(glib);
    struct_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    for k = 1:num_structs
        gstruct = glib.st{k};
        sname_str = get(gstruct, 'sname');
        struct_map(sname_str) = gstruct;
    end
end


%% ========================================================================
%% CORE FUNCTION: FLATTEN STRUCTURE RECURSIVELY
%% ========================================================================

function [gstruct_out, stats] = flatten_structure(gstruct, struct_map, params, depth)
% Recursively flatten a structure by resolving all references
%
% INPUT:
%   gstruct    : gds_structure to flatten
%   struct_map : Map of structure names to gds_structure objects
%   params     : Parameter structure
%   depth      : Current recursion depth
%
% OUTPUT:
%   gstruct_out : Flattened gds_structure
%   stats       : Statistics structure

    % Initialize statistics
    stats.refs_resolved = 0;
    stats.arefs_resolved = 0;
    stats.elements_created = 0;
    stats.max_depth_reached = depth;
    
    % Check depth limit
    if params.max_depth >= 0 && depth > params.max_depth
        if params.verbose >= 2
            fprintf('  [Depth %d] Max depth reached, stopping recursion\n', depth);
        end
        gstruct_out = gstruct;
        return;
    end
    
    % Get structure name and elements
    struct_name = get(gstruct, 'sname');
    el_cell = gstruct(:);  % Get all elements as cell array
    num_elements = length(el_cell);
    
    if params.verbose >= 2
        fprintf('  [Depth %d] Flattening structure: %s (%d elements)\n', ...
                depth, struct_name, num_elements);
    end
    
    % Create output structure - we'll rebuild it from scratch
    new_elements = {};
    
    % Process each element
    for k = 1:num_elements
        gel = el_cell{k};
        
        % Check if element is a reference
        if is_ref(gel)
            % Get reference name
            ref_name = sname(gel);
            
            % Check if referenced structure exists in map
            if ~isKey(struct_map, ref_name)
                if params.verbose >= 1
                    warning('gds_flatten_for_3d:MissingReference', ...
                            'Referenced structure "%s" not found, skipping', ref_name);
                end
                continue;
            end
            
            % Get referenced structure
            ref_struct = struct_map(ref_name);
            
            % Recursively flatten referenced structure first
            [ref_struct_flat, ref_stats] = flatten_structure(ref_struct, struct_map, params, depth + 1);
            
            % Accumulate statistics
            stats.refs_resolved = stats.refs_resolved + ref_stats.refs_resolved;
            stats.arefs_resolved = stats.arefs_resolved + ref_stats.arefs_resolved;
            stats.elements_created = stats.elements_created + ref_stats.elements_created;
            stats.max_depth_reached = max(stats.max_depth_reached, ref_stats.max_depth_reached);
            
            % Determine if sref or aref
            gel_type = etype(gel);
            
            if strcmp(gel_type, 'sref')
                % Handle structure reference
                transformed_elements = flatten_sref(gel, ref_struct_flat, params, depth);
                stats.refs_resolved = stats.refs_resolved + 1;
                stats.elements_created = stats.elements_created + length(transformed_elements);
                
            elseif strcmp(gel_type, 'aref')
                % Handle array reference
                transformed_elements = flatten_aref(gel, ref_struct_flat, params, depth);
                stats.arefs_resolved = stats.arefs_resolved + 1;
                stats.elements_created = stats.elements_created + length(transformed_elements);
                
            else
                % Should not reach here
                warning('gds_flatten_for_3d:UnexpectedRefType', ...
                        'Unexpected reference type: %s', gel_type);
                transformed_elements = {};
            end
            
            % Add transformed elements to output
            new_elements = [new_elements, transformed_elements];
            
        else
            % Not a reference, keep element as-is
            new_elements{end+1} = gel;
        end
    end
    
    % Create new structure with flattened elements
    % We need to create a new gds_structure from scratch
    gstruct_out = gds_structure(struct_name, new_elements);
    
    if params.verbose >= 2
        fprintf('  [Depth %d] Flattened %s: %d -> %d elements\n', ...
                depth, struct_name, num_elements, length(new_elements));
    end
end


%% ========================================================================
%% HELPER FUNCTION: FLATTEN SREF
%% ========================================================================

function transformed_elements = flatten_sref(sref_element, ref_struct, params, depth)
% Flatten a single structure reference (sref)
%
% Applies transformation according to GDSII spec:
%   1. Reflect about x-axis (if strans.reflect = 1)
%   2. Rotate by strans.angle degrees
%   3. Magnify by strans.mag
%   4. Translate to sref xy position

    transformed_elements = {};
    
    % Get sref properties
    ref_xy = get(sref_element, 'xy');
    if iscell(ref_xy)
        ref_xy = ref_xy{1};  % Extract from cell if needed
    end
    ref_pos = ref_xy(1, :);  % Reference position
    
    % Get strans (may be empty)
    try
        ref_strans = strans(sref_element);
    catch
        ref_strans = [];
    end
    
    if params.verbose >= 2
        fprintf('    [Depth %d] Resolving sref: %s at [%.2f, %.2f]\n', ...
                depth, sname(sref_element), ref_pos(1), ref_pos(2));
    end
    
    % Get all elements from referenced structure
    ref_elements = ref_struct(:);
    
    % Transform each element
    for k = 1:length(ref_elements)
        gel = ref_elements{k};
        
        % Skip reference elements (should already be flattened)
        if is_ref(gel)
            continue;
        end
        
        % Transform element
        gel_transformed = apply_transformation_to_element(gel, ref_strans, ref_pos);
        
        if ~isempty(gel_transformed)
            transformed_elements{end+1} = gel_transformed;
        end
    end
end


%% ========================================================================
%% HELPER FUNCTION: FLATTEN AREF
%% ========================================================================

function transformed_elements = flatten_aref(aref_element, ref_struct, params, depth)
% Flatten an array reference (aref)
%
% For each instance in the array:
%   1. Apply strans to individual instance
%   2. Calculate array position
%   3. Translate to array position

    transformed_elements = {};
    
    % Get aref properties
    ref_xy = get(aref_element, 'xy');
    if iscell(ref_xy)
        ref_xy = ref_xy{1};
    end
    
    % aref xy contains 3 points:
    %   xy(1,:) = origin (reference point)
    %   xy(2,:) = column_spacing * num_columns + origin
    %   xy(3,:) = row_spacing * num_rows + origin
    origin = ref_xy(1, :);
    col_vec = ref_xy(2, :);
    row_vec = ref_xy(3, :);
    
    % Get array dimensions
    ref_adim = adim(aref_element);
    num_cols = ref_adim.col;
    num_rows = ref_adim.row;
    
    % Calculate spacing vectors
    col_spacing = (col_vec - origin) / num_cols;
    row_spacing = (row_vec - origin) / num_rows;
    
    % Get strans (may be empty)
    try
        ref_strans = strans(aref_element);
    catch
        ref_strans = [];
    end
    
    if params.verbose >= 2
        fprintf('    [Depth %d] Resolving aref: %s [%d x %d array]\n', ...
                depth, sname(aref_element), num_rows, num_cols);
    end
    
    % Get all elements from referenced structure
    ref_elements = ref_struct(:);
    
    % Replicate across array
    for row = 0:(num_rows-1)
        for col = 0:(num_cols-1)
            % Calculate position for this instance
            instance_pos = origin + col * col_spacing + row * row_spacing;
            
            % Transform each element for this instance
            for k = 1:length(ref_elements)
                gel = ref_elements{k};
                
                % Skip reference elements
                if is_ref(gel)
                    continue;
                end
                
                % Transform element
                gel_transformed = apply_transformation_to_element(gel, ref_strans, instance_pos);
                
                if ~isempty(gel_transformed)
                    transformed_elements{end+1} = gel_transformed;
                end
            end
        end
    end
end


%% ========================================================================
%% HELPER FUNCTION: APPLY TRANSFORMATION TO ELEMENT
%% ========================================================================

function gel_transformed = apply_transformation_to_element(gel, strans_record, translation)
% Apply strans transformation and translation to a gds_element
%
% Transformation order (GDSII spec):
%   1. Reflection about x-axis (if strans.reflect = 1)
%   2. Rotation by strans.angle degrees
%   3. Magnification by strans.mag
%   4. Translation to reference position
%
% INPUT:
%   gel            : gds_element to transform
%   strans_record  : strans structure (may be empty)
%   translation    : [x, y] translation vector
%
% OUTPUT:
%   gel_transformed : transformed gds_element

    gel_transformed = [];
    
    % Get element type
    gel_type = etype(gel);
    
    % Only transform elements with xy coordinates
    if ~ismember(gel_type, {'boundary', 'path', 'box'})
        % For text, node, and other elements, just translate position
        if ismember(gel_type, {'text', 'node'})
            gel_transformed = gel;
            xy_orig = get(gel, 'xy');
            if iscell(xy_orig)
                xy_orig = xy_orig{1};
            end
            xy_new = apply_strans_to_coords(xy_orig, strans_record, translation);
            gel_transformed = set(gel_transformed, 'xy', xy_new);
        end
        return;
    end
    
    % Get original xy coordinates
    xy_orig = get(gel, 'xy');
    
    % Handle cell array of polygons (boundary, path)
    if iscell(xy_orig)
        xy_new = cell(size(xy_orig));
        for k = 1:length(xy_orig)
            xy_new{k} = apply_strans_to_coords(xy_orig{k}, strans_record, translation);
        end
    else
        % Single matrix (box)
        xy_new = apply_strans_to_coords(xy_orig, strans_record, translation);
    end
    
    % Create transformed element with new coordinates
    gel_transformed = gel;
    gel_transformed = set(gel_transformed, 'xy', xy_new);
end


%% ========================================================================
%% HELPER FUNCTION: APPLY STRANS TO COORDINATES
%% ========================================================================

function xy_transformed = apply_strans_to_coords(xy, strans_record, translation)
% Apply strans transformation and translation to coordinate matrix
%
% INPUT:
%   xy             : Nx2 matrix of coordinates
%   strans_record  : strans structure (may be empty)
%   translation    : [x, y] translation vector
%
% OUTPUT:
%   xy_transformed : Nx2 matrix of transformed coordinates

    xy_transformed = xy;
    
    % Apply transformations in order (per GDSII spec)
    
    % 1. Reflection about x-axis (do this FIRST, before rotation)
    if ~isempty(strans_record) && isfield(strans_record, 'reflect') && strans_record.reflect
        xy_transformed(:, 2) = -xy_transformed(:, 2);
    end
    
    % 2. Rotation
    if ~isempty(strans_record) && isfield(strans_record, 'angle') && ...
       ~isempty(strans_record.angle) && strans_record.angle ~= 0
        % Use existing poly_rotzd function for rotation
        xy_transformed = poly_rotzd(xy_transformed, strans_record.angle);
    end
    
    % 3. Magnification
    if ~isempty(strans_record) && isfield(strans_record, 'mag') && ...
       ~isempty(strans_record.mag) && strans_record.mag ~= 1
        xy_transformed = xy_transformed * strans_record.mag;
    end
    
    % 4. Translation
    xy_transformed = bsxfun(@plus, xy_transformed, translation);
    
    % Check for unsupported features
    if ~isempty(strans_record)
        if isfield(strans_record, 'absmag') && strans_record.absmag
            warning('gds_flatten_for_3d:UnsupportedAbsMag', ...
                    'Absolute magnification (strans.absmag) not supported');
        end
        if isfield(strans_record, 'absang') && strans_record.absang
            warning('gds_flatten_for_3d:UnsupportedAbsAng', ...
                    'Absolute angle (strans.absang) not supported');
        end
    end
end


%% ========================================================================
%% UTILITY FUNCTION: IIF (inline if)
%% ========================================================================

function result = iif(condition, true_val, false_val)
% Inline if-else function
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
