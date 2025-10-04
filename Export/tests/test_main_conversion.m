% test_main_conversion.m
% Simple test for gds_to_step main conversion function
% Tests Section 4.5 implementation

fprintf('\n===========================================\n');
fprintf('Testing gds_to_step Main Conversion (4.5)\n');
fprintf('===========================================\n\n');

% Setup paths
test_dir = fileparts(mfilename('fullpath'));
export_dir = fileparts(test_dir);
toolbox_root = fileparts(export_dir);

addpath(export_dir);
addpath(genpath(fullfile(toolbox_root, 'Basic')));
addpath(fullfile(toolbox_root, 'Elements'));
addpath(fullfile(toolbox_root, 'Structures'));

output_dir = fullfile(test_dir, 'output');

% Test files already exist from previous setup
gds_file = fullfile(output_dir, 'test_simple.gds');
config_file = fullfile(output_dir, 'test_simple_config.json');
output_stl = fullfile(output_dir, 'test_main_simple.stl');

fprintf('Test 1: Basic Conversion\n');
fprintf('------------------------\n');
fprintf('GDS file:    %s\n', gds_file);
fprintf('Config file: %s\n', config_file);
fprintf('Output STL:  %s\n\n', output_stl);

try
    % Run the main conversion function
    gds_to_step(gds_file, config_file, output_stl, ...
                'format', 'stl', ...
                'verbose', 2);
    
    % Check result
    if exist(output_stl, 'file')
        info = dir(output_stl);
        fprintf('\n✓ SUCCESS: Output file created (%.1f KB)\n\n', info.bytes/1024);
    else
        fprintf('\n✗ FAILED: Output file not created\n\n');
    end
    
catch ME
    fprintf('\n✗ FAILED with error:\n');
    fprintf('   %s\n\n', ME.message);
    fprintf('Stack trace:\n');
    for k = 1:length(ME.stack)
        fprintf('  %s at line %d\n', ME.stack(k).name, ME.stack(k).line);
    end
    fprintf('\n');
end

fprintf('===========================================\n');
fprintf('Test complete\n');
fprintf('===========================================\n\n');
