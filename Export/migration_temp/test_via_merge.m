%% Test VIA STEP file generation with merging enabled
% This script tests the material-based merging functionality
% to create continuous VIA tubes from segmented layers

function test_via_merge()
    fprintf('================================================================\n');
    fprintf('  VIA STEP MERGE TEST - Material-based Vertical Continuity\n');
    fprintf('================================================================\n');
    fprintf('\n');
    
    % Add parent directory to path
    parent_dir = fileparts(fileparts(mfilename('fullpath')));
    root_dir = fileparts(parent_dir);  % gdsii-toolbox-146 root
    addpath(parent_dir);
    addpath(fullfile(root_dir, 'Basic'));
    addpath(fullfile(root_dir, 'Basic', 'gdsio'));
    addpath(fullfile(root_dir, 'Structures'));
    
    % Test directory
    test_dir = fileparts(mfilename('fullpath'));
    
    %% Test N=3 with merging
    fprintf('TEST 1: VIA N=3 with material-based merging\n');
    fprintf('----------------------------------------------------------------------\n');
    
    N = 3;
    gds_file = fullfile(test_dir, sprintf('test_output_via_N%d', N), ...
                        sprintf('via_penetration_N%d.gds', N));
    config_file = fullfile(test_dir, sprintf('test_output_via_N%d', N), ...
                          sprintf('via_config_N%d.json', N));
    output_step_merged = fullfile(test_dir, sprintf('test_output_via_N%d', N), ...
                                  sprintf('via_penetration_N%d_merged.step', N));
    
    if ~exist(gds_file, 'file')
        fprintf('  ✗ GDS file not found: %s\n', gds_file);
        fprintf('  Please run test_via_penetration.m first\n');
        return;
    end
    
    if ~exist(config_file, 'file')
        fprintf('  ✗ Config file not found: %s\n', config_file);
        return;
    end
    
    fprintf('  Input GDS:    %s\n', gds_file);
    fprintf('  Config:       %s\n', config_file);
    fprintf('  Output STEP:  %s\n', output_step_merged);
    fprintf('\n');
    
    try
        fprintf('  Converting with merge=true...\n');
        
        % Call gds_to_step with merge enabled
        gds_to_step(gds_file, config_file, output_step_merged, ...
                    'format', 'step', ...
                    'merge', true, ...
                    'verbose', 2);
        
        % Verify output
        if exist(output_step_merged, 'file')
            file_info = dir(output_step_merged);
            fprintf('\n  ✓ MERGED STEP file created successfully!\n');
            fprintf('  ✓ File size: %.2f KB\n', file_info.bytes/1024);
            fprintf('  ✓ Location: %s\n', output_step_merged);
            
            % Count solids in STEP file
            fprintf('\n  Analyzing STEP file structure...\n');
            [status, result] = system(sprintf('grep -c "MANIFOLD_SOLID_BREP" "%s"', output_step_merged));
            if status == 0
                num_solids = str2double(strtrim(result));
                fprintf('  Number of solids: %d (expected: 5 for merged N=3)\n', num_solids);
                
                if num_solids == 5
                    fprintf('  ✓ CORRECT: VIA segments merged into continuous tube!\n');
                    fprintf('    Expected breakdown:\n');
                    fprintf('      1. VIA_starter_1 (z: 0-1) - Tungsten_starter\n');
                    fprintf('      2. Tower_layer_2 (z: 1-2) - Silicon_tower\n');
                    fprintf('      3. Tower_layer_3 (z: 2-3) - Silicon_tower\n');
                    fprintf('      4. Tungsten_via_continuous (z: 1-3) - MERGED! ✓\n');
                    fprintf('      5. VIA_landing_pad_4 (z: 3-4) - Copper_pad\n');
                elseif num_solids == 6
                    fprintf('  ⚠ No merging occurred (still 6 separate solids)\n');
                    fprintf('    This may indicate the merge function did not run\n');
                else
                    fprintf('  ℹ Unexpected solid count: %d\n', num_solids);
                end
            end
            
        else
            fprintf('\n  ✗ FAILED: STEP file was not created\n');
            fprintf('  This may indicate an error in the MATLAB result parsing\n');
        end
        
    catch ME
        fprintf('\n  ✗ FAILED: %s\n', ME.message);
        fprintf('\n  Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
    
    fprintf('\n');
    
    %% Test N=5 with merging
    fprintf('TEST 2: VIA N=5 with material-based merging\n');
    fprintf('----------------------------------------------------------------------\n');
    
    N = 5;
    gds_file = fullfile(test_dir, sprintf('test_output_via_N%d', N), ...
                        sprintf('via_penetration_N%d.gds', N));
    config_file = fullfile(test_dir, sprintf('test_output_via_N%d', N), ...
                          sprintf('via_config_N%d.json', N));
    output_step_merged = fullfile(test_dir, sprintf('test_output_via_N%d', N), ...
                                  sprintf('via_penetration_N%d_merged.step', N));
    
    if ~exist(gds_file, 'file')
        fprintf('  ⚠ GDS file not found: %s\n', gds_file);
        fprintf('  Skipping N=5 test\n');
        return;
    end
    
    if ~exist(config_file, 'file')
        fprintf('  ⚠ Config file not found: %s\n', config_file);
        return;
    end
    
    fprintf('  Input GDS:    %s\n', gds_file);
    fprintf('  Config:       %s\n', config_file);
    fprintf('  Output STEP:  %s\n', output_step_merged);
    fprintf('\n');
    
    try
        fprintf('  Converting with merge=true...\n');
        
        % Call gds_to_step with merge enabled
        gds_to_step(gds_file, config_file, output_step_merged, ...
                    'format', 'step', ...
                    'merge', true, ...
                    'verbose', 2);
        
        % Verify output
        if exist(output_step_merged, 'file')
            file_info = dir(output_step_merged);
            fprintf('\n  ✓ MERGED STEP file created successfully!\n');
            fprintf('  ✓ File size: %.2f KB\n', file_info.bytes/1024);
            fprintf('  ✓ Location: %s\n', output_step_merged);
            
            % Count solids in STEP file
            fprintf('\n  Analyzing STEP file structure...\n');
            [status, result] = system(sprintf('grep -c "MANIFOLD_SOLID_BREP" "%s"', output_step_merged));
            if status == 0
                num_solids = str2double(strtrim(result));
                fprintf('  Number of solids: %d (expected: 7 for merged N=5)\n', num_solids);
                
                if num_solids == 7
                    fprintf('  ✓ CORRECT: VIA segments merged into continuous tube!\n');
                    fprintf('    Expected: 4 VIA segments (layers 2-5) merged into 1 solid\n');
                    fprintf('    Reduction: 10 → 7 solids (30%% improvement)\n');
                elseif num_solids == 10
                    fprintf('  ⚠ No merging occurred (still 10 separate solids)\n');
                else
                    fprintf('  ℹ Unexpected solid count: %d\n', num_solids);
                end
            end
            
        else
            fprintf('\n  ✗ FAILED: STEP file was not created\n');
        end
        
    catch ME
        fprintf('\n  ✗ FAILED: %s\n', ME.message);
        fprintf('\n  Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
    
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('  MERGE TEST COMPLETE\n');
    fprintf('================================================================\n');
    fprintf('\n');
    fprintf('Note: If STEP files were created, you can view them in FreeCAD\n');
    fprintf('or any CAD software that supports STEP format.\n');
    fprintf('\n');
    
end
