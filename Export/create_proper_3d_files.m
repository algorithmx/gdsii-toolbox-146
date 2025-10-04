function create_proper_3d_files()
% CREATE_PROPER_3D_FILES - Generate proper 3D files using full pipeline
%
% This uses the complete gds_to_step pipeline which will create STL files
% when STEP is not available. STL files are widely supported and can be
% converted to STEP by external tools if needed.

fprintf('Creating proper 3D files using full conversion pipeline...\n');

% Ensure we are in the Export directory
cd('/home/dabajabaza/Documents/gdsii-toolbox-146/Export');
addpath(genpath('.'));
addpath(genpath('../Basic'));

% Define test sets and files
test_sets = {
    {'basic', {'res_metal1.gds', 'res_metal3.gds', 'res_topmetal1.gds'}};
    {'intermediate', {'sg13_hv_pmos.gds', 'sg13_lv_nmos.gds', 'cap_cmim.gds'}};
};

% Create output directory
output_base = 'tests/proper_3d_output';
if ~exist(output_base, 'dir')
    mkdir(output_base);
end

config_file = 'tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json';
total_generated = 0;

for set_idx = 1:length(test_sets)
    set_name = test_sets{set_idx}{1};
    test_files = test_sets{set_idx}{2};
    
    fprintf('\n=== Processing %s test set ===\n', set_name);
    
    % Create set-specific output directory
    set_output_dir = fullfile(output_base, set_name);
    if ~exist(set_output_dir, 'dir')
        mkdir(set_output_dir);
    end
    
    for file_idx = 1:length(test_files)
        gds_file = test_files{file_idx};
        fprintf('\nProcessing: %s\n', gds_file);
        
        % Full path to GDS file
        gds_path = fullfile('tests/fixtures/ihp_sg13g2/pdk_test_sets', set_name, gds_file);
        
        % Generate output file names (trying STEP first, will fallback to STL)
        [~, basename, ~] = fileparts(gds_file);
        
        % Try STEP format first
        step_file = fullfile(set_output_dir, [basename '.step']);
        stl_file = fullfile(set_output_dir, [basename '.stl']);
        
        try
            tic;
            
            % Use the full gds_to_step pipeline
            % It will automatically fallback to STL if pythonOCC is not available
            gds_to_step(gds_path, config_file, step_file, 'verbose', 1);
            
            process_time = toc;
            
            % Check which file was actually created
            if exist(step_file, 'file')
                file_info = dir(step_file);
                fprintf('  ✓ STEP file created: %s (%.2f KB)\n', step_file, file_info.bytes/1024);
                total_generated = total_generated + 1;
            elseif exist(stl_file, 'file')
                file_info = dir(stl_file);
                fprintf('  ✓ STL file created: %s (%.2f KB)\n', stl_file, file_info.bytes/1024);
                total_generated = total_generated + 1;
            else
                fprintf('  ⚠ No output file found\n');
            end
            
            fprintf('  Processing time: %.3f sec\n', process_time);
            
        catch ME
            fprintf('  ❌ Failed: %s\n', ME.message);
            if ~isempty(ME.stack)
                fprintf('     at %s:%d\n', ME.stack(1).name, ME.stack(1).line);
            end
        end
    end
end

fprintf('\n========================================\n');
fprintf('3D File Generation Complete\n');
fprintf('========================================\n');
fprintf('Total files generated: %d\n', total_generated);
fprintf('Output directory: %s\n', output_base);

% List all generated files
fprintf('\nGenerated files:\n');
all_files = [dir(fullfile(output_base, '**', '*.step')); dir(fullfile(output_base, '**', '*.stl'))];
for i = 1:length(all_files)
    fprintf('  %s (%.1f KB)\n', fullfile(all_files(i).folder, all_files(i).name), all_files(i).bytes/1024);
end

fprintf('========================================\n');

% Also create higher-quality STL files with specific options
fprintf('\nCreating high-quality STL files with custom options...\n');
create_high_quality_stl_files();

end


function create_high_quality_stl_files()
% CREATE_HIGH_QUALITY_STL_FILES - Create STL files with high-quality settings

fprintf('\n--- Creating High-Quality STL Files ---\n');

% Define test files for high-quality export
test_cases = {
    {'tests/fixtures/ihp_sg13g2/pdk_test_sets/basic/res_metal1.gds', 'res_metal1_hq.stl'};
    {'tests/fixtures/ihp_sg13g2/pdk_test_sets/intermediate/sg13_hv_pmos.gds', 'sg13_hv_pmos_hq.stl'};
    {'tests/fixtures/ihp_sg13g2/pdk_test_sets/intermediate/cap_cmim.gds', 'cap_cmim_hq.stl'};
};

config_file = 'tests/fixtures/ihp_sg13g2/layer_config_ihp_sg13g2_accurate.json';
hq_output_dir = 'tests/high_quality_stl';

if ~exist(hq_output_dir, 'dir')
    mkdir(hq_output_dir);
end

for i = 1:length(test_cases)
    gds_path = test_cases{i}{1};
    output_name = test_cases{i}{2};
    stl_path = fullfile(hq_output_dir, output_name);
    
    [~, basename, ~] = fileparts(gds_path);
    fprintf('\nCreating high-quality STL for: %s\n', basename);
    
    try
        % Use gds_to_step with STL format and high precision
        gds_to_step(gds_path, config_file, stl_path, ...
                   'format', 'stl', ...
                   'precision', 1e-9, ...
                   'verbose', 1, ...
                   'units', 1e-6);  % Convert to meters for CAD compatibility
        
        if exist(stl_path, 'file')
            file_info = dir(stl_path);
            fprintf('  ✓ High-quality STL: %s (%.2f KB)\n', stl_path, file_info.bytes/1024);
        end
        
    catch ME
        fprintf('  ❌ Failed: %s\n', ME.message);
    end
end

fprintf('\nHigh-quality STL files created in: %s\n', hq_output_dir);
end