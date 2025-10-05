% VIEW_VIA_STRUCTURE - Display VIA penetration GDS structure details
%
% Usage: view_via_structure(N)
%   N: Tower size (3, 5, etc.)

function view_via_structure(N)
    if nargin < 1
        N = 3;
    end
    
    % Add paths
    script_dir = fileparts(mfilename('fullpath'));
    toolbox_root = fileparts(fileparts(script_dir));
    addpath(genpath(toolbox_root));
    
    % Load GDS file
    gds_file = fullfile(script_dir, sprintf('test_output_via_N%d/via_penetration_N%d.gds', N, N));
    
    if ~exist(gds_file, 'file')
        fprintf('Error: GDS file not found: %s\n', gds_file);
        fprintf('Run test_via_penetration(%d) first.\n', N);
        return;
    end
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('VIA Structure Analysis (N=%d)\n', N);
    fprintf('========================================\n');
    fprintf('File: %s\n\n', gds_file);
    
    % Read GDS library
    glib = read_gds_library(gds_file);
    
    % Get first structure
    struct_names = snames(glib);
    gstruct_cell = getstruct(glib, struct_names{1});
    gstruct = gstruct_cell{1};
    struct_name = struct_names{1};
    
    fprintf('Structure: %s\n', struct_name);
    
    elem_list = get(gstruct, 'el');
    fprintf('Total elements: %d\n\n', length(elem_list));
    
    % Analyze each element
    fprintf('Layer-by-Layer Analysis:\n');
    fprintf('%-8s %-10s %-15s %-15s %-20s\n', 'GDS Layer', 'Datatype', 'Element Type', 'Size (WxH)', 'Center (X,Y)');
    fprintf('%s\n', repmat('-', 1, 80));
    
    % Group elements by layer
    layer_data = struct();
    
    for i = 1:length(elem_list)
        el = elem_list{i};
        layer_num = get(el, 'layer');
        dtype = get(el, 'dtype');
        
        % Get element type
        if is_etype(el, 'boundary')
            elem_type = 'boundary';
        elseif is_etype(el, 'path')
            elem_type = 'path';
        else
            elem_type = 'other';
        end
        
        % Get xy coordinates
        xy = get(el, 'xy');
        
        % Handle cell array case
        if iscell(xy)
            xy = xy{1};
        end
        
        % Calculate size and center
        x_min = min(xy(:,1));
        x_max = max(xy(:,1));
        y_min = min(xy(:,2));
        y_max = max(xy(:,2));
        
        width = x_max - x_min;
        height = y_max - y_min;
        center_x = (x_min + x_max) / 2;
        center_y = (y_min + y_max) / 2;
        
        % Store in layer data
        if ~isfield(layer_data, sprintf('L%d', layer_num))
            layer_data.(sprintf('L%d', layer_num)) = [];
        end
        
        elem_info = struct();
        elem_info.dtype = dtype;
        elem_info.type = elem_type;
        elem_info.width = width;
        elem_info.height = height;
        elem_info.center_x = center_x;
        elem_info.center_y = center_y;
        
        layer_data.(sprintf('L%d', layer_num)) = [layer_data.(sprintf('L%d', layer_num)), elem_info];
        
        % Print element info
        fprintf('%-8d %-10d %-15s %-15s (%.1f,%.1f)\n', ...
                layer_num, dtype, elem_type, ...
                sprintf('%.1fx%.1f', width, height), ...
                center_x, center_y);
    end
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('Summary by Layer:\n');
    fprintf('========================================\n\n');
    
    for layer = 1:(N+1)
        field_name = sprintf('L%d', layer);
        if isfield(layer_data, field_name)
            elems = layer_data.(field_name);
            fprintf('Layer %d:\n', layer);
            
            for j = 1:length(elems)
                e = elems(j);
                if e.dtype == 0
                    fprintf('  - BOUNDARY (dtype=0): %.1f x %.1f\n', e.width, e.height);
                else
                    fprintf('  - VIA (dtype=1):      %.1f x %.1f\n', e.width, e.height);
                end
            end
            fprintf('\n');
        end
    end
    
    % Verify expected structure
    fprintf('========================================\n');
    fprintf('Verification:\n');
    fprintf('========================================\n\n');
    
    correct = true;
    
    % Check layer 1 - should be size N
    if isfield(layer_data, 'L1')
        if layer_data.L1(1).width == N && layer_data.L1(1).height == N
            fprintf('✓ Layer 1: VIA starter %dx%d (correct)\n', N, N);
        else
            fprintf('✗ Layer 1: Expected %dx%d, got %.1fx%.1f\n', ...
                    N, N, layer_data.L1(1).width, layer_data.L1(1).height);
            correct = false;
        end
    end
    
    % Check layers 2 to N - should have tower (size k) + VIA (size 1)
    for k = 2:N
        field_name = sprintf('L%d', k);
        if isfield(layer_data, field_name)
            elems = layer_data.(field_name);
            
            % Find tower and VIA
            tower_elem = [];
            via_elem = [];
            for j = 1:length(elems)
                if elems(j).dtype == 0
                    tower_elem = elems(j);
                else
                    via_elem = elems(j);
                end
            end
            
            if ~isempty(tower_elem) && tower_elem.width == k
                fprintf('✓ Layer %d: Tower %dx%d (correct)\n', k, k, k);
            else
                fprintf('✗ Layer %d: Expected tower %dx%d\n', k, k, k);
                correct = false;
            end
            
            if ~isempty(via_elem) && via_elem.width == 1
                fprintf('✓ Layer %d: VIA 1x1 (correct)\n', k);
            else
                fprintf('✗ Layer %d: Expected VIA 1x1\n', k);
                correct = false;
            end
        end
    end
    
    % Check layer N+1 - should be size N+1
    field_name = sprintf('L%d', N+1);
    if isfield(layer_data, field_name)
        if layer_data.(field_name)(1).width == (N+1)
            fprintf('✓ Layer %d: VIA landing pad %dx%d (correct)\n', N+1, N+1, N+1);
        else
            fprintf('✗ Layer %d: Expected %dx%d\n', N+1, N+1, N+1);
            correct = false;
        end
    end
    
    fprintf('\n');
    if correct
        fprintf('✓✓✓ ALL STRUCTURE CHECKS PASSED ✓✓✓\n');
    else
        fprintf('✗✗✗ STRUCTURE VERIFICATION FAILED ✗✗✗\n');
    end
    fprintf('\n');
    
end
