% TEST_SECTION_4_6_AND_4_7 - Test library method and command-line script
%
% This script tests the implementations from sections 4.6 and 4.7 of the
% GDS_TO_STEP_IMPLEMENTATION_PLAN.md:
%   - Section 4.6: gds_library.to_step() method
%   - Section 4.7: gds2step command-line script
%
% Tests include:
%   1. Library method basic usage
%   2. Library method with options
%   3. Command-line script --help
%   4. Command-line script basic usage
%   5. Command-line script with options
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Part of gdsii-toolbox-146 GDSII-to-STEP implementation

function test_section_4_6_and_4_7()
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('  TEST: Section 4.6 (Library Method) and 4.7 (Command-Line)\n');
    fprintf('================================================================\n');
    fprintf('\n');
    
    % Track test results
    tests_passed = 0;
    tests_failed = 0;
    
    % Add toolbox to path
    script_dir = fileparts(mfilename('fullpath'));
    toolbox_root = fileparts(fileparts(script_dir));  % Go up two levels
    addpath(genpath(toolbox_root));
    
    % Create test directory
    test_dir = fullfile(script_dir, 'test_output_4_6_4_7');
    if ~exist(test_dir, 'dir')
        mkdir(test_dir);
    end
    
    fprintf('Test directory: %s\n\n', test_dir);
    
    %% ====================================================================
    %% TEST 1: Create test GDS file
    %% ====================================================================
    
    fprintf('TEST 1: Create test GDS file and layer config\n');
    fprintf('----------------------------------------------------------------------\n');
    
    try
        % Create simple test structure
        test_gds = fullfile(test_dir, 'test_4_6_4_7.gds');
        test_config = fullfile(test_dir, 'test_config_4_6_4_7.json');
        
        % Create library
        glib = gds_library('TestLib', 'uunit', 1e-6, 'dbunit', 1e-9);
        
        % Create structure with simple rectangle
        gstruct = gds_structure('TopCell');
        
        % Add rectangles on different layers
        rect1 = gds_element('boundary', 'xy', [0 0; 100 0; 100 100; 0 100; 0 0], ...
                           'layer', 1, 'dtype', 0);
        rect2 = gds_element('boundary', 'xy', [20 20; 80 20; 80 80; 20 80; 20 20], ...
                           'layer', 2, 'dtype', 0);
        
        gstruct = add_element(gstruct, rect1);
        gstruct = add_element(gstruct, rect2);
        
        % Add structure to library
        glib = add_struct(glib, gstruct);
        
        % Write GDS file
        write_gds_library(glib, test_gds, 'verbose', 0);
        
        % Create layer config JSON
        config_str = sprintf('{\n');
        config_str = [config_str sprintf('  "project": "Test 4.6 and 4.7",\n')];
        config_str = [config_str sprintf('  "units": "micrometers",\n')];
        config_str = [config_str sprintf('  "layers": [\n')];
        config_str = [config_str sprintf('    {\n')];
        config_str = [config_str sprintf('      "gds_layer": 1,\n')];
        config_str = [config_str sprintf('      "gds_datatype": 0,\n')];
        config_str = [config_str sprintf('      "name": "bottom",\n')];
        config_str = [config_str sprintf('      "z_bottom": 0,\n')];
        config_str = [config_str sprintf('      "z_top": 10,\n')];
        config_str = [config_str sprintf('      "material": "silicon",\n')];
        config_str = [config_str sprintf('      "color": "#808080"\n')];
        config_str = [config_str sprintf('    },\n')];
        config_str = [config_str sprintf('    {\n')];
        config_str = [config_str sprintf('      "gds_layer": 2,\n')];
        config_str = [config_str sprintf('      "gds_datatype": 0,\n')];
        config_str = [config_str sprintf('      "name": "top",\n')];
        config_str = [config_str sprintf('      "z_bottom": 10,\n')];
        config_str = [config_str sprintf('      "z_top": 20,\n')];
        config_str = [config_str sprintf('      "material": "metal",\n')];
        config_str = [config_str sprintf('      "color": "#FFD700"\n')];
        config_str = [config_str sprintf('    }\n')];
        config_str = [config_str sprintf('  ]\n')];
        config_str = [config_str sprintf('}\n')];
        
        fid = fopen(test_config, 'w');
        fprintf(fid, '%s', config_str);
        fclose(fid);
        
        fprintf('  ✓ Test GDS file created: %s\n', test_gds);
        fprintf('  ✓ Test config created: %s\n', test_config);
        tests_passed = tests_passed + 1;
        
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        tests_failed = tests_failed + 1;
        return;
    end
    
    fprintf('\n');
    
    %% ====================================================================
    %% TEST 2: Test library method - basic usage
    %% ====================================================================
    
    fprintf('TEST 2: Library method - basic usage (to_step)\n');
    fprintf('----------------------------------------------------------------------\n');
    
    try
        % Read library
        glib = read_gds_library(test_gds);
        
        % Export using library method
        output_stl = fullfile(test_dir, 'output_method_basic.stl');
        to_step(glib, test_config, output_stl, 'format', 'stl', 'verbose', 0);
        
        % Verify output exists
        if exist(output_stl, 'file')
            file_info = dir(output_stl);
            fprintf('  ✓ Library method executed successfully\n');
            fprintf('  ✓ Output file: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
            tests_passed = tests_passed + 1;
        else
            fprintf('  ✗ FAILED: Output file not created\n');
            tests_failed = tests_failed + 1;
        end
        
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        tests_failed = tests_failed + 1;
    end
    
    fprintf('\n');
    
    %% ====================================================================
    %% TEST 3: Test library method - with options
    %% ====================================================================
    
    fprintf('TEST 3: Library method - with options\n');
    fprintf('----------------------------------------------------------------------\n');
    
    try
        % Read library
        glib = read_gds_library(test_gds);
        
        % Export with options
        output_stl = fullfile(test_dir, 'output_method_options.stl');
        to_step(glib, test_config, output_stl, ...
                'format', 'stl', ...
                'layers_filter', [1], ...  % Only layer 1
                'verbose', 0);
        
        % Verify output exists
        if exist(output_stl, 'file')
            file_info = dir(output_stl);
            fprintf('  ✓ Library method with options executed successfully\n');
            fprintf('  ✓ Output file: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
            tests_passed = tests_passed + 1;
        else
            fprintf('  ✗ FAILED: Output file not created\n');
            tests_failed = tests_failed + 1;
        end
        
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        tests_failed = tests_failed + 1;
    end
    
    fprintf('\n');
    
    %% ====================================================================
    %% TEST 4: Test command-line script - help
    %% ====================================================================
    
    fprintf('TEST 4: Command-line script - --help\n');
    fprintf('----------------------------------------------------------------------\n');
    
    try
        script_path = fullfile(toolbox_root, 'Scripts', 'gds2step');
        
        % Test help command
        cmd = sprintf('octave -q %s --help', script_path);
        [status, output] = system(cmd);
        
        % Help exits with status 1 when nargin < 3, but displays help successfully
        if ~isempty(strfind(output, 'USAGE')) && ~isempty(strfind(output, 'gds2step'))
            fprintf('  ✓ Help message displayed successfully\n');
            fprintf('  ✓ Script is executable and functional\n');
            tests_passed = tests_passed + 1;
        else
            fprintf('  ✗ FAILED: Help command failed (status=%d)\n', status);
            fprintf('  Output: %s\n', output);
            tests_failed = tests_failed + 1;
        end
        
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        tests_failed = tests_failed + 1;
    end
    
    fprintf('\n');
    
    %% ====================================================================
    %% TEST 5: Test command-line script - basic conversion
    %% ====================================================================
    
    fprintf('TEST 5: Command-line script - basic conversion\n');
    fprintf('----------------------------------------------------------------------\n');
    
    try
        script_path = fullfile(toolbox_root, 'Scripts', 'gds2step');
        output_stl = fullfile(test_dir, 'output_cmdline_basic.stl');
        
        % Build command
        cmd = sprintf('octave -q %s %s %s %s --format=stl --verbose=0', ...
                     script_path, test_gds, test_config, output_stl);
        
        % Execute command
        [status, output] = system(cmd);
        
        if status == 0 && exist(output_stl, 'file')
            file_info = dir(output_stl);
            fprintf('  ✓ Command-line script executed successfully\n');
            fprintf('  ✓ Output file: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
            tests_passed = tests_passed + 1;
        else
            fprintf('  ✗ FAILED: Command failed (status=%d)\n', status);
            fprintf('  Output: %s\n', output);
            tests_failed = tests_failed + 1;
        end
        
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        tests_failed = tests_failed + 1;
    end
    
    fprintf('\n');
    
    %% ====================================================================
    %% TEST 6: Test command-line script - with options
    %% ====================================================================
    
    fprintf('TEST 6: Command-line script - with options\n');
    fprintf('----------------------------------------------------------------------\n');
    
    try
        script_path = fullfile(toolbox_root, 'Scripts', 'gds2step');
        output_stl = fullfile(test_dir, 'output_cmdline_options.stl');
        
        % Build command with options
        cmd = sprintf('octave -q %s %s %s %s --format=stl --layers=2 --verbose=0', ...
                     script_path, test_gds, test_config, output_stl);
        
        % Execute command
        [status, output] = system(cmd);
        
        if status == 0 && exist(output_stl, 'file')
            file_info = dir(output_stl);
            fprintf('  ✓ Command-line script with options executed successfully\n');
            fprintf('  ✓ Output file: %s (%.2f KB)\n', output_stl, file_info.bytes/1024);
            tests_passed = tests_passed + 1;
        else
            fprintf('  ✗ FAILED: Command failed (status=%d)\n', status);
            fprintf('  Output: %s\n', output);
            tests_failed = tests_failed + 1;
        end
        
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        tests_failed = tests_failed + 1;
    end
    
    fprintf('\n');
    
    %% ====================================================================
    %% SUMMARY
    %% ====================================================================
    
    fprintf('================================================================\n');
    fprintf('  TEST SUMMARY\n');
    fprintf('================================================================\n');
    fprintf('Tests passed: %d\n', tests_passed);
    fprintf('Tests failed: %d\n', tests_failed);
    fprintf('Total tests:  %d\n', tests_passed + tests_failed);
    fprintf('Success rate: %.1f%%\n', 100*tests_passed/(tests_passed+tests_failed));
    fprintf('================================================================\n');
    
    if tests_failed == 0
        fprintf('\n✓ ALL TESTS PASSED!\n\n');
    else
        fprintf('\n✗ SOME TESTS FAILED!\n\n');
    end
    
    % List output files
    fprintf('Output files created in: %s\n', test_dir);
    files = dir(fullfile(test_dir, '*'));
    for k = 1:length(files)
        if ~files(k).isdir
            fprintf('  - %s (%.2f KB)\n', files(k).name, files(k).bytes/1024);
        end
    end
    fprintf('\n');
    
end
