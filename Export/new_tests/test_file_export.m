function results = test_file_export()
% TEST_FILE_EXPORT - Test STL file generation
%
% Tests the gds_write_stl function which exports 3D solids to STL format.
% Focuses on STL only (no STEP) to avoid Python dependencies.
%
% COVERAGE:
%   - Binary STL export
%   - ASCII STL export
%   - Error handling for invalid inputs
%
% USAGE:
%   results = test_file_export()
%
% RETURNS:
%   results - Structure with test results and statistics
%
% Author: WARP AI Agent, October 2025
% Part of essential GDS-STL-STEP test suite

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('Testing File Export (STL)\n');
    fprintf('========================================\n\n');
    
    % Standardized path setup
    script_dir = fileparts(mfilename('fullpath'));
    export_dir = fileparts(script_dir);
    toolbox_root = fileparts(export_dir);
    
    % Add required paths (only if not already in path)
    if isempty(strfind(path, export_dir))
        addpath(export_dir);
    end
    basic_path = fullfile(toolbox_root, 'Basic');
    if isempty(strfind(path, basic_path)) && exist(basic_path, 'dir')
        addpath(genpath(basic_path));
    end
    
    % Create temporary output directory
    output_dir = fullfile(script_dir, 'test_output');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Initialize results
    results = struct();
    results.total = 0;
    results.passed = 0;
    results.failed = 0;
    results.test_names = {};
    results.test_status = {};
    
    % Run tests
    results = run_test(results, 'Binary STL export', ...
                       @() test_binary_stl(output_dir));
    
    results = run_test(results, 'ASCII STL export', ...
                       @() test_ascii_stl(output_dir));
    
    results = run_test(results, 'Error handling - empty input', ...
                       @() test_error_handling(output_dir));
    
    % Print summary
    fprintf('\n========================================\n');
    fprintf('File Export Test Summary\n');
    fprintf('========================================\n');
    fprintf('Total tests:  %d\n', results.total);
    fprintf('Passed:       %d\n', results.passed);
    fprintf('Failed:       %d\n', results.failed);
    fprintf('Success rate: %.1f%%\n', 100 * results.passed / results.total);
    fprintf('========================================\n\n');
    
    if results.failed == 0
        fprintf('✓ ALL TESTS PASSED\n\n');
    else
        fprintf('✗ SOME TESTS FAILED\n\n');
    end
end

%% ========================================================================
%% Helper Functions
%% ========================================================================

function results = run_test(results, test_name, test_func)
    fprintf('TEST %d: %s\n', results.total + 1, test_name);
    fprintf('----------------------------------------\n');
    results.total = results.total + 1;
    results.test_names{end+1} = test_name;
    
    try
        test_func();
        fprintf('✓ PASSED\n\n');
        results.passed = results.passed + 1;
        results.test_status{end+1} = 'PASS';
    catch ME
        fprintf('✗ FAILED: %s\n\n', ME.message);
        results.failed = results.failed + 1;
        results.test_status{end+1} = 'FAIL';
    end
end

%% ========================================================================
%% Individual Test Functions
%% ========================================================================

function test_binary_stl(output_dir)
    % Test binary STL export
    
    % Create simple box
    polygon = [0 0; 10 0; 10 10; 0 10];
    solid = gds_extrude_polygon(polygon, 0, 5);
    
    % Export to binary STL (default format)
    output_file = fullfile(output_dir, 'test_binary.stl');
    gds_write_stl(solid, output_file);
    
    % Verify file was created
    assert(exist(output_file, 'file') ~= 0, 'Binary STL file not created');
    
    % Check file size (should be non-zero)
    file_info = dir(output_file);
    assert(file_info.bytes > 0, 'Binary STL file is empty');
    
    fprintf('  File created: %s\n', output_file);
    fprintf('  File size: %.2f KB\n', file_info.bytes / 1024);
end

function test_ascii_stl(output_dir)
    % Test ASCII STL export
    
    % Create simple box
    polygon = [0 0; 10 0; 10 10; 0 10];
    solid = gds_extrude_polygon(polygon, 0, 5);
    
    % Export to ASCII STL
    output_file = fullfile(output_dir, 'test_ascii.stl');
    opts.format = 'ascii';
    gds_write_stl(solid, output_file, opts);
    
    % Verify file was created
    assert(exist(output_file, 'file') ~= 0, 'ASCII STL file not created');
    
    % Verify it's ASCII format (should start with "solid")
    fid = fopen(output_file, 'r');
    first_line = fgetl(fid);
    fclose(fid);
    
    assert(strncmp(first_line, 'solid', 5), ...
           'ASCII STL should start with "solid"');
    
    fprintf('  File created: %s\n', output_file);
    fprintf('  Format: ASCII (verified)\n');
    fprintf('  First line: %s\n', first_line);
end

function test_error_handling(output_dir)
    % Test error handling for invalid inputs
    
    % Test: Empty solids array should error
    error_caught = false;
    output_file = fullfile(output_dir, 'test_error.stl');
    
    try
        gds_write_stl({}, output_file);
    catch
        error_caught = true;
    end
    
    assert(error_caught, 'Should reject empty solids array');
    fprintf('  ✓ Empty input correctly rejected\n');
end
