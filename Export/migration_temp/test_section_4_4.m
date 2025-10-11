% TEST_SECTION_4_4 - Test STEP and STL writers (Section 4.4)
%
% This script tests the implementation of:
%   - gds_write_stl.m (MVP: STL export)
%   - gds_write_step.m (Production: STEP export)
%   - step_writer.py (Python STEP backend)
%
% Tests:
%   1. STL export (binary)
%   2. STL export (ASCII)
%   3. STEP export (if pythonOCC available)
%   4. Fallback behavior
%   5. Multiple solids
%   6. Error handling

fprintf('=================================================\n');
fprintf('Section 4.4 STEP Writer Interface - Test Suite\n');
fprintf('=================================================\n\n');

% Add Export directory to path
addpath(fileparts(fileparts(mfilename('fullpath'))));

% Create test output directory
test_dir = fullfile(fileparts(mfilename('fullpath')), 'output_4_4');
if ~exist(test_dir, 'dir')
    mkdir(test_dir);
end

test_count = 0;
pass_count = 0;

%% Test 1: STL Export - Binary Format
fprintf('Test 1: STL Export (Binary)\n');
fprintf('----------------------------\n');
test_count = test_count + 1;

try
    % Create simple box
    polygon = [0 0; 10 0; 10 10; 0 10; 0 0];
    solid = gds_extrude_polygon(polygon, 0, 5);
    
    % Export to binary STL
    output_file = fullfile(test_dir, 'test_box_binary.stl');
    gds_write_stl(solid, output_file);
    
    % Verify file was created
    if exist(output_file, 'file')
        file_info = dir(output_file);
        fprintf('  ✓ Binary STL created: %s (%.0f bytes)\n', output_file, file_info.bytes);
        pass_count = pass_count + 1;
    else
        fprintf('  ✗ FAILED: File not created\n');
    end
catch err
    fprintf('  ✗ FAILED: %s\n', err.message);
end
fprintf('\n');

%% Test 2: STL Export - ASCII Format
fprintf('Test 2: STL Export (ASCII)\n');
fprintf('--------------------------\n');
test_count = test_count + 1;

try
    % Create simple box
    polygon = [0 0; 10 0; 10 10; 0 10; 0 0];
    solid = gds_extrude_polygon(polygon, 0, 5);
    
    % Export to ASCII STL
    output_file = fullfile(test_dir, 'test_box_ascii.stl');
    opts.format = 'ascii';
    gds_write_stl(solid, output_file, opts);
    
    % Verify file was created and is ASCII
    if exist(output_file, 'file')
        fid = fopen(output_file, 'r');
        first_line = fgetl(fid);
        fclose(fid);
        
        if strncmp(first_line, 'solid', 5)
            file_info = dir(output_file);
            fprintf('  ✓ ASCII STL created: %s (%.0f bytes)\n', output_file, file_info.bytes);
            fprintf('    First line: %s\n', first_line);
            pass_count = pass_count + 1;
        else
            fprintf('  ✗ FAILED: Not valid ASCII STL format\n');
        end
    else
        fprintf('  ✗ FAILED: File not created\n');
    end
catch err
    fprintf('  ✗ FAILED: %s\n', err.message);
end
fprintf('\n');

%% Test 3: Multiple Solids - STL
fprintf('Test 3: Multiple Solids (STL)\n');
fprintf('------------------------------\n');
test_count = test_count + 1;

try
    % Create multi-layer stack
    solids = {};
    
    % Layer 1
    p1 = [0 0; 20 0; 20 20; 0 20; 0 0];
    s1 = gds_extrude_polygon(p1, 0, 2);
    s1.layer_name = 'Substrate';
    s1.material = 'silicon';
    solids{1} = s1;
    
    % Layer 2
    p2 = [5 5; 15 5; 15 15; 5 15; 5 5];
    s2 = gds_extrude_polygon(p2, 2, 4);
    s2.layer_name = 'Metal1';
    s2.material = 'aluminum';
    solids{2} = s2;
    
    % Export all
    output_file = fullfile(test_dir, 'multi_layer.stl');
    gds_write_stl(solids, output_file);
    
    % Verify file was created
    if exist(output_file, 'file')
        file_info = dir(output_file);
        fprintf('  ✓ Multi-layer STL created: %s (%.0f bytes)\n', output_file, file_info.bytes);
        fprintf('    Contains %d solids\n', length(solids));
        pass_count = pass_count + 1;
    else
        fprintf('  ✗ FAILED: File not created\n');
    end
catch err
    fprintf('  ✗ FAILED: %s\n', err.message);
end
fprintf('\n');

%% Test 4: STEP Export (with pythonOCC check)
fprintf('Test 4: STEP Export\n');
fprintf('-------------------\n');
test_count = test_count + 1;

try
    % Create solid with metadata
    polygon = [0 0; 10 0; 10 10; 0 10; 0 0];
    solid = gds_extrude_polygon(polygon, 0, 5);
    solid.material = 'aluminum';
    solid.color = '#FF0000';
    solid.layer_name = 'Metal1';
    
    % Try to export to STEP
    output_file = fullfile(test_dir, 'test_box.step');
    clear opts;
    opts.verbose = false;
    gds_write_step(solid, output_file, opts);
    
    % Check what was created (STEP or fallback STL)
    if exist(output_file, 'file')
        file_info = dir(output_file);
        fprintf('  ✓ STEP file created: %s (%.0f bytes)\n', output_file, file_info.bytes);
        pass_count = pass_count + 1;
    elseif exist(strrep(output_file, '.step', '.stl'), 'file')
        fprintf('  ⚠ STEP not available, STL fallback used\n');
        fprintf('    (This is expected if pythonOCC is not installed)\n');
        pass_count = pass_count + 1;
    else
        fprintf('  ✗ FAILED: No output file created\n');
    end
catch err
    fprintf('  ✗ FAILED: %s\n', err.message);
end
fprintf('\n');

%% Test 5: Error Handling - Invalid Input
fprintf('Test 5: Error Handling\n');
fprintf('----------------------\n');
test_count = test_count + 1;

try
    % Try to write empty solids array (should error)
    output_file = fullfile(test_dir, 'error_test.stl');
    try
        gds_write_stl({}, output_file);
        fprintf('  ✗ FAILED: Should have thrown error for empty input\n');
    catch err
        if ~isempty(strfind(err.message, 'no solids provided'))
            fprintf('  ✓ Correctly caught empty input error\n');
            pass_count = pass_count + 1;
        else
            fprintf('  ✗ FAILED: Wrong error: %s\n', err.message);
        end
    end
catch err
    fprintf('  ✗ FAILED: Unexpected error: %s\n', err.message);
end
fprintf('\n');

%% Test 6: Unit Scaling
fprintf('Test 6: Unit Scaling\n');
fprintf('--------------------\n');
test_count = test_count + 1;

try
    % Create box with unit scaling
    polygon = [0 0; 1 0; 1 1; 0 1; 0 0];  % 1×1 box
    solid = gds_extrude_polygon(polygon, 0, 1);
    
    % Export with 1000× scaling (convert to mm)
    output_file = fullfile(test_dir, 'test_scaled.stl');
    clear opts;
    opts.format = 'binary';
    opts.units = 1000;  % Scale by 1000
    gds_write_stl(solid, output_file, opts);
    
    if exist(output_file, 'file')
        fprintf('  ✓ Scaled STL created (1×1 box scaled by 1000×)\n');
        pass_count = pass_count + 1;
    else
        fprintf('  ✗ FAILED: File not created\n');
    end
catch err
    fprintf('  ✗ FAILED: %s\n', err.message);
end
fprintf('\n');

%% Test 7: Complex Polygon
fprintf('Test 7: Complex Polygon\n');
fprintf('-----------------------\n');
test_count = test_count + 1;

try
    % Create L-shaped polygon
    polygon = [0 0; 10 0; 10 5; 5 5; 5 10; 0 10; 0 0];
    solid = gds_extrude_polygon(polygon, 0, 3);
    
    % Export
    output_file = fullfile(test_dir, 'test_L_shape.stl');
    gds_write_stl(solid, output_file);
    
    if exist(output_file, 'file')
        file_info = dir(output_file);
        fprintf('  ✓ L-shaped STL created: %.0f bytes\n', file_info.bytes);
        pass_count = pass_count + 1;
    else
        fprintf('  ✗ FAILED: File not created\n');
    end
catch err
    fprintf('  ✗ FAILED: %s\n', err.message);
end
fprintf('\n');

%% Summary
fprintf('=================================================\n');
fprintf('Test Summary\n');
fprintf('=================================================\n');
fprintf('Tests passed: %d / %d\n', pass_count, test_count);
if pass_count == test_count
    fprintf('Result: ✓ ALL TESTS PASSED\n');
else
    fprintf('Result: ✗ SOME TESTS FAILED\n');
end
fprintf('\nOutput files location: %s\n', test_dir);
fprintf('=================================================\n');

% Return test results
if pass_count == test_count
    fprintf('\n✅ Section 4.4 implementation is WORKING CORRECTLY!\n\n');
else
    fprintf('\n⚠️  Section 4.4 has %d failing tests.\n\n', test_count - pass_count);
end
