function to_step(glib, layer_config_file, output_file, varargin)
%function to_step(glib, layer_config_file, output_file, varargin)
%
% TO_STEP - Export gds_library object to STEP 3D model
%
% glib.to_step(layer_config_file, output_file)
% glib.to_step(layer_config_file, output_file, 'option', value, ...)
%
% Method for gds_library class to export the library to STEP or STL format.
% This is a convenience wrapper around the gds_to_step() function that
% works directly with a library object already in memory.
%
% INPUT:
%   glib              : gds_library object (implicit self parameter)
%   layer_config_file : Path to layer configuration JSON file
%   output_file       : Path to output STEP file (or STL if format='stl')
%   varargin          : Optional parameter/value pairs (same as gds_to_step)
%
% OPTIONAL PARAMETERS (passed to gds_to_step):
%   'structure_name'  - Name of structure to export (default: top structure)
%   'window'          - [xmin ymin xmax ymax] extract region only
%   'layers_filter'   - Vector of layer numbers to process
%   'datatypes_filter'- Vector of datatype numbers to process
%   'flatten'         - Flatten hierarchy (default: true)
%   'merge'           - Merge overlapping solids (default: false)
%   'format'          - Output format: 'step' or 'stl' (default: 'step')
%   'units'           - Unit scaling factor (default: 1.0)
%   'verbose'         - Verbosity level 0/1/2 (default: 1)
%   'python_cmd'      - Python command for STEP writer (default: 'python3')
%   'precision'       - Geometric tolerance (default: 1e-6)
%   'keep_temp'       - Keep temporary files for debugging (default: false)
%
% EXAMPLES:
%   % Basic usage
%   glib = read_gds_library('design.gds');
%   glib.to_step('layer_config.json', 'design.step');
%
%   % With options
%   glib = read_gds_library('chip.gds');
%   glib.to_step('cmos_config.json', 'chip.step', ...
%                'structure_name', 'TopCell', ...
%                'window', [0 0 1000 1000], ...
%                'layers_filter', [10 11 12], ...
%                'verbose', 2);
%
%   % Export to STL
%   glib = read_gds_library('design.gds');
%   glib.to_step('config.json', 'design.stl', ...
%                'format', 'stl', ...
%                'units', 1e-6);
%
% NOTES:
%   - This method is a wrapper that saves the library to a temporary file
%     and then calls gds_to_step() to perform the conversion
%   - For large libraries, consider using windowing to extract only the
%     region of interest
%   - STEP format requires Python with pythonOCC installed
%   - STL format works without external dependencies
%
% SEE ALSO:
%   gds_to_step, write_gds_library, gds_read_layer_config
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Part of gdsii-toolbox-146 GDSII-to-STEP implementation
%   Implementation of Section 4.6 from GDS_TO_STEP_IMPLEMENTATION_PLAN.md

% =========================================================================
% VALIDATE INPUT ARGUMENTS
% =========================================================================

    % Check minimum arguments
    if nargin < 3
        error('gds_library.to_step: requires at least 3 arguments');
    end
    
    % Validate that glib is a gds_library object
    if ~isa(glib, 'gds_library')
        error('gds_library.to_step: first argument must be a gds_library object');
    end
    
    % Validate file paths
    if ~ischar(layer_config_file) && ~isstring(layer_config_file)
        error('gds_library.to_step: layer_config_file must be a string');
    end
    if ~ischar(output_file) && ~isstring(output_file)
        error('gds_library.to_step: output_file must be a string');
    end
    
    % Convert to char if string type
    layer_config_file = char(layer_config_file);
    output_file = char(output_file);
    
    % Check if layer config file exists
    if ~exist(layer_config_file, 'file')
        error('gds_library.to_step: layer config file not found --> %s', ...
              layer_config_file);
    end

% =========================================================================
% PARSE OPTIONS
% =========================================================================

    % Parse optional arguments to extract verbose flag for our messages
    verbose = 1;  % Default
    format = 'step';  % Default
    
    % Quick scan for verbose and format options
    k = 1;
    while k <= length(varargin)
        if ischar(varargin{k}) || isstring(varargin{k})
            param_name = lower(char(varargin{k}));
            if k < length(varargin)
                if strcmp(param_name, 'verbose')
                    verbose = varargin{k+1};
                elseif strcmp(param_name, 'format')
                    format = lower(char(varargin{k+1}));
                end
            end
            k = k + 2;
        else
            k = k + 1;
        end
    end

% =========================================================================
% CREATE TEMPORARY GDS FILE
% =========================================================================

    if verbose >= 1
        fprintf('\n========================================\n');
        fprintf('  Export gds_library to %s\n', upper(format));
        fprintf('========================================\n');
        fprintf('Library name:  %s\n', get(glib, 'lname'));
        fprintf('Structures:    %d\n', length(glib));
        fprintf('Output file:   %s\n', output_file);
        fprintf('========================================\n\n');
    end
    
    % Create temporary GDS file
    temp_gds = tempname();
    temp_gds = [temp_gds '.gds'];
    
    if verbose >= 2
        fprintf('Creating temporary GDS file: %s\n', temp_gds);
    end
    
    try
        % Write library to temporary file
        % Use verbose=0 to avoid cluttering output
        write_gds_library(glib, temp_gds, 'verbose', 0);
        
        if verbose >= 2
            fprintf('Temporary GDS file created successfully\n\n');
        end
    catch ME
        error('gds_library.to_step: failed to write temporary GDS file\n%s', ...
              ME.message);
    end

% =========================================================================
% CALL GDS_TO_STEP CONVERSION
% =========================================================================

    try
        % Call the main conversion function
        % Pass all optional parameters through
        gds_to_step(temp_gds, layer_config_file, output_file, varargin{:});
        
    catch ME
        % Clean up temporary file before re-throwing error
        if exist(temp_gds, 'file')
            delete(temp_gds);
        end
        rethrow(ME);
    end

% =========================================================================
% CLEANUP
% =========================================================================

    % Remove temporary GDS file
    if exist(temp_gds, 'file')
        delete(temp_gds);
        if verbose >= 2
            fprintf('Temporary GDS file removed\n');
        end
    end
    
    if verbose >= 1
        fprintf('Export completed successfully!\n\n');
    end

end
