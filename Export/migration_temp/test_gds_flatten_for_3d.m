function test_gds_flatten_for_3d()
% TEST_GDS_FLATTEN_FOR_3D - Test suite for hierarchy flattening
%
% Tests gds_flatten_for_3d.m with various hierarchy configurations including:
%   - Simple sref (structure reference)
%   - sref with rotation
%   - sref with reflection
%   - sref with magnification
%   - aref (array reference)
%   - Nested references (hierarchy depth)
%   - Multiple transformations combined
%
% USAGE:
%   test_gds_flatten_for_3d()
%
% AUTHOR:
%   WARP AI Agent, October 2025
%   Part of Section 4.8 implementation testing

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  Testing gds_flatten_for_3d\n');
    fprintf('========================================\n\n');
    
    % Track test results
    total_tests = 0;
    passed_tests = 0;
    
    % Test 1: Simple sref with no transformation
    fprintf('Test 1: Simple sref with no transformation...\n');
    [pass, msg] = test_simple_sref();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('  PASSED: %s\n\n', msg);
    else
        fprintf('  FAILED: %s\n\n', msg);
    end
    
    % Test 2: sref with rotation
    fprintf('Test 2: sref with 90-degree rotation...\n');
    [pass, msg] = test_sref_rotation();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('  PASSED: %s\n\n', msg);
    else
        fprintf('  FAILED: %s\n\n', msg);
    end
    
    % Test 3: sref with reflection
    fprintf('Test 3: sref with x-axis reflection...\n');
    [pass, msg] = test_sref_reflection();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('  PASSED: %s\n\n', msg);
    else
        fprintf('  FAILED: %s\n\n', msg);
    end
    
    % Test 4: sref with magnification
    fprintf('Test 4: sref with 2x magnification...\n');
    [pass, msg] = test_sref_magnification();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('  PASSED: %s\n\n', msg);
    else
        fprintf('  FAILED: %s\n\n', msg);
    end
    
    % Test 5: Simple aref (2x2 array)
    fprintf('Test 5: Simple 2x2 array reference...\n');
    [pass, msg] = test_simple_aref();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('  PASSED: %s\n\n', msg);
    else
        fprintf('  FAILED: %s\n\n', msg);
    end
    
    % Test 6: Nested references (2-level hierarchy)
    fprintf('Test 6: Nested references (2-level)...\n');
    [pass, msg] = test_nested_refs();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('  PASSED: %s\n\n', msg);
    else
        fprintf('  FAILED: %s\n\n', msg);
    end
    
    % Test 7: Combined transformations
    fprintf('Test 7: Combined transformations (rotate + mag + translate)...\n');
    [pass, msg] = test_combined_transforms();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('  PASSED: %s\n\n', msg);
    else
        fprintf('  FAILED: %s\n\n', msg);
    end
    
    % Summary
    fprintf('========================================\n');
    fprintf('  Test Summary\n');
    fprintf('========================================\n');
    fprintf('Total tests:  %d\n', total_tests);
    fprintf('Passed:       %d\n', passed_tests);
    fprintf('Failed:       %d\n', total_tests - passed_tests);
    fprintf('Pass rate:    %.1f%%\n', 100 * passed_tests / total_tests);
    fprintf('========================================\n\n');
    
    if passed_tests == total_tests
        fprintf('All tests PASSED!\n\n');
    else
        fprintf('Some tests FAILED - review output above\n\n');
    end
end


%% ========================================================================
%% TEST 1: SIMPLE SREF WITH NO TRANSFORMATION
%% ========================================================================

function [pass, msg] = test_simple_sref()
    try
        % Create a simple structure with a rectangle
        rect = gds_element('boundary', 'xy', [0 0; 10 0; 10 5; 0 5; 0 0], 'layer', 1);
        child_struct = gds_structure('CHILD');
        child_struct = add_element(child_struct, rect);
        
        % Create parent structure with sref at (100, 50)
        sref = gds_element('sref', 'sname', 'CHILD', 'xy', [100 50]);
        parent_struct = gds_structure('PARENT');
        parent_struct = add_element(parent_struct, sref);
        
        % Create library - add structures properly
        glib = gds_library('TEST_LIB', 'uunit', 1e-6, 'dbunit', 1e-9);
        glib = add_struct(glib, child_struct);
        glib = add_struct(glib, parent_struct);
        
        % Flatten
        flat_struct = gds_flatten_for_3d(glib, 'structure_name', 'PARENT', 'verbose', 0);
        
        % Verify: should have 1 boundary element at translated position
        elements = flat_struct(:);
        if length(elements) ~= 1
            pass = false;
            msg = sprintf('Expected 1 element, got %d', length(elements));
            return;
        end
        
        % Check coordinates
        xy = get(elements{1}, 'xy');
        if iscell(xy)
            xy = xy{1};
        end
        expected = [100 50; 110 50; 110 55; 100 55; 100 50];
        
        if max(max(abs(xy - expected))) > 1e-10
            pass = false;
            msg = 'Coordinates do not match expected values';
            return;
        end
        
        pass = true;
        msg = 'Simple sref correctly translated';
        
    catch ME
        pass = false;
        msg = sprintf('Exception: %s', ME.message);
    end
end


%% ========================================================================
%% TEST 2: SREF WITH ROTATION
%% ========================================================================

function [pass, msg] = test_sref_rotation()
    try
        % Create a simple structure with a rectangle
        rect = gds_element('boundary', 'xy', [0 0; 10 0; 10 5; 0 5; 0 0], 'layer', 1);
        child_struct = gds_structure('CHILD');
        child_struct = add_element(child_struct, rect);
        
        % Create parent structure with rotated sref (90 degrees)
        strans_rec = struct('angle', 90, 'reflect', 0, 'mag', 1);
        sref = gds_element('sref', 'sname', 'CHILD', 'xy', [0 0], 'strans', strans_rec);
        parent_struct = gds_structure('PARENT');
        parent_struct = add_element(parent_struct, sref);
        
        % Create library
        glib = gds_library('TEST_LIB', 'uunit', 1e-6, 'dbunit', 1e-9);
        glib = add_struct(glib, child_struct); glib = add_struct(glib, parent_struct);
        
        % Flatten
        flat_struct = gds_flatten_for_3d(glib, 'structure_name', 'PARENT', 'verbose', 0);
        
        % Verify rotation: [10,0] should become [0,10] after 90° rotation
        elements = flat_struct(:);
        xy = get(elements{1}, 'xy');
        if iscell(xy)
            xy = xy{1};
        end
        
        % After 90° rotation: (x,y) -> (-y,x)
        % [0,0] -> [0,0]
        % [10,0] -> [0,10]
        % [10,5] -> [-5,10]
        % [0,5] -> [-5,0]
        expected = [0 0; 0 10; -5 10; -5 0; 0 0];
        
        if max(max(abs(xy - expected))) > 1e-10
            pass = false;
            msg = sprintf('Rotation incorrect. Max error: %.2e', max(max(abs(xy - expected))));
            return;
        end
        
        pass = true;
        msg = '90-degree rotation applied correctly';
        
    catch ME
        pass = false;
        msg = sprintf('Exception: %s', ME.message);
    end
end


%% ========================================================================
%% TEST 3: SREF WITH REFLECTION
%% ========================================================================

function [pass, msg] = test_sref_reflection()
    try
        % Create a simple structure with a rectangle
        rect = gds_element('boundary', 'xy', [0 0; 10 0; 10 5; 0 5; 0 0], 'layer', 1);
        child_struct = gds_structure('CHILD');
        child_struct = add_element(child_struct, rect);
        
        % Create parent structure with reflected sref
        strans_rec = struct('angle', 0, 'reflect', 1, 'mag', 1);
        sref = gds_element('sref', 'sname', 'CHILD', 'xy', [0 0], 'strans', strans_rec);
        parent_struct = gds_structure('PARENT');
        parent_struct = add_element(parent_struct, sref);
        
        % Create library
        glib = gds_library('TEST_LIB', 'uunit', 1e-6, 'dbunit', 1e-9);
        glib = add_struct(glib, child_struct); glib = add_struct(glib, parent_struct);
        
        % Flatten
        flat_struct = gds_flatten_for_3d(glib, 'structure_name', 'PARENT', 'verbose', 0);
        
        % Verify reflection about x-axis: y coordinates should be negated
        elements = flat_struct(:);
        xy = get(elements{1}, 'xy');
        if iscell(xy)
            xy = xy{1};
        end
        
        expected = [0 0; 10 0; 10 -5; 0 -5; 0 0];
        
        if max(max(abs(xy - expected))) > 1e-10
            pass = false;
            msg = 'Reflection incorrect';
            return;
        end
        
        pass = true;
        msg = 'X-axis reflection applied correctly';
        
    catch ME
        pass = false;
        msg = sprintf('Exception: %s', ME.message);
    end
end


%% ========================================================================
%% TEST 4: SREF WITH MAGNIFICATION
%% ========================================================================

function [pass, msg] = test_sref_magnification()
    try
        % Create a simple structure with a rectangle
        rect = gds_element('boundary', 'xy', [0 0; 10 0; 10 5; 0 5; 0 0], 'layer', 1);
        child_struct = gds_structure('CHILD');
        child_struct = add_element(child_struct, rect);
        
        % Create parent structure with magnified sref (2x)
        strans_rec = struct('angle', 0, 'reflect', 0, 'mag', 2.0);
        sref = gds_element('sref', 'sname', 'CHILD', 'xy', [0 0], 'strans', strans_rec);
        parent_struct = gds_structure('PARENT');
        parent_struct = add_element(parent_struct, sref);
        
        % Create library
        glib = gds_library('TEST_LIB', 'uunit', 1e-6, 'dbunit', 1e-9);
        glib = add_struct(glib, child_struct); glib = add_struct(glib, parent_struct);
        
        % Flatten
        flat_struct = gds_flatten_for_3d(glib, 'structure_name', 'PARENT', 'verbose', 0);
        
        % Verify magnification: all coordinates should be doubled
        elements = flat_struct(:);
        xy = get(elements{1}, 'xy');
        if iscell(xy)
            xy = xy{1};
        end
        
        expected = [0 0; 20 0; 20 10; 0 10; 0 0];
        
        if max(max(abs(xy - expected))) > 1e-10
            pass = false;
            msg = 'Magnification incorrect';
            return;
        end
        
        pass = true;
        msg = '2x magnification applied correctly';
        
    catch ME
        pass = false;
        msg = sprintf('Exception: %s', ME.message);
    end
end


%% ========================================================================
%% TEST 5: SIMPLE AREF (2x2 ARRAY)
%% ========================================================================

function [pass, msg] = test_simple_aref()
    try
        % Create a simple structure with a small rectangle
        rect = gds_element('boundary', 'xy', [0 0; 5 0; 5 5; 0 5; 0 0], 'layer', 1);
        child_struct = gds_structure('CHILD');
        child_struct = add_element(child_struct, rect);
        
        % Create parent structure with 2x2 array
        % Origin at (0,0), column spacing 10, row spacing 10
        adim_rec = struct('col', 2, 'row', 2);
        aref_xy = [0 0; 20 0; 0 20];  % 2 cols * 10 spacing, 2 rows * 10 spacing
        aref = gds_element('aref', 'sname', 'CHILD', 'xy', aref_xy, 'adim', adim_rec);
        parent_struct = gds_structure('PARENT');
        parent_struct = add_element(parent_struct, aref);
        
        % Create library
        glib = gds_library('TEST_LIB', 'uunit', 1e-6, 'dbunit', 1e-9);
        glib = add_struct(glib, child_struct); glib = add_struct(glib, parent_struct);
        
        % Flatten
        flat_struct = gds_flatten_for_3d(glib, 'structure_name', 'PARENT', 'verbose', 0);
        
        % Verify: should have 4 boundary elements (2x2 array)
        elements = flat_struct(:);
        if length(elements) ~= 4
            pass = false;
            msg = sprintf('Expected 4 elements (2x2 array), got %d', length(elements));
            return;
        end
        
        % Check that we have instances at (0,0), (10,0), (0,10), (10,10)
        positions = zeros(4, 2);
        for k = 1:4
            xy = get(elements{k}, 'xy');
            if iscell(xy)
                xy = xy{1};
            end
            % Get first vertex (origin of each instance)
            positions(k, :) = xy(1, :);
        end
        
        expected_positions = [0 0; 10 0; 0 10; 10 10];
        
        % Sort both arrays for comparison
        positions = sortrows(positions);
        expected_positions = sortrows(expected_positions);
        
        if max(max(abs(positions - expected_positions))) > 1e-10
            pass = false;
            msg = 'Array instance positions incorrect';
            return;
        end
        
        pass = true;
        msg = '2x2 array reference flattened correctly';
        
    catch ME
        pass = false;
        msg = sprintf('Exception: %s', ME.message);
    end
end


%% ========================================================================
%% TEST 6: NESTED REFERENCES (2-LEVEL HIERARCHY)
%% ========================================================================

function [pass, msg] = test_nested_refs()
    try
        % Create bottom-level structure (grandchild)
        rect = gds_element('boundary', 'xy', [0 0; 5 0; 5 5; 0 5; 0 0], 'layer', 1);
        grandchild_struct = gds_structure('GRANDCHILD');
        grandchild_struct = add_element(grandchild_struct, rect);
        
        % Create mid-level structure (child) with sref to grandchild at (10,0)
        sref1 = gds_element('sref', 'sname', 'GRANDCHILD', 'xy', [10 0]);
        child_struct = gds_structure('CHILD');
        child_struct = add_element(child_struct, sref1);
        
        % Create top-level structure (parent) with sref to child at (100,0)
        sref2 = gds_element('sref', 'sname', 'CHILD', 'xy', [100 0]);
        parent_struct = gds_structure('PARENT');
        parent_struct = add_element(parent_struct, sref2);
        
        % Create library
        glib = gds_library('TEST_LIB', 'uunit', 1e-6, 'dbunit', 1e-9);
        glib = add_struct(glib, grandchild_struct, child_struct); glib = add_struct(glib, parent_struct);
        
        % Flatten
        flat_struct = gds_flatten_for_3d(glib, 'structure_name', 'PARENT', 'verbose', 0);
        
        % Verify: should have 1 boundary element at (110, 0)
        % Translation chain: (0,0) + (10,0) + (100,0) = (110,0)
        elements = flat_struct(:);
        if length(elements) ~= 1
            pass = false;
            msg = sprintf('Expected 1 element, got %d', length(elements));
            return;
        end
        
        xy = get(elements{1}, 'xy');
        if iscell(xy)
            xy = xy{1};
        end
        expected = [110 0; 115 0; 115 5; 110 5; 110 0];
        
        if max(max(abs(xy - expected))) > 1e-10
            pass = false;
            msg = sprintf('Nested translation incorrect. Max error: %.2e', max(max(abs(xy - expected))));
            return;
        end
        
        pass = true;
        msg = 'Nested references (2-level) resolved correctly';
        
    catch ME
        pass = false;
        msg = sprintf('Exception: %s', ME.message);
    end
end


%% ========================================================================
%% TEST 7: COMBINED TRANSFORMATIONS
%% ========================================================================

function [pass, msg] = test_combined_transforms()
    try
        % Create a simple structure with a rectangle
        rect = gds_element('boundary', 'xy', [0 0; 10 0; 10 5; 0 5; 0 0], 'layer', 1);
        child_struct = gds_structure('CHILD');
        child_struct = add_element(child_struct, rect);
        
        % Create parent with combined transformations:
        % reflect=1, angle=90, mag=2, translate to (100,50)
        strans_rec = struct('angle', 90, 'reflect', 1, 'mag', 2.0);
        sref = gds_element('sref', 'sname', 'CHILD', 'xy', [100 50], 'strans', strans_rec);
        parent_struct = gds_structure('PARENT');
        parent_struct = add_element(parent_struct, sref);
        
        % Create library
        glib = gds_library('TEST_LIB', 'uunit', 1e-6, 'dbunit', 1e-9);
        glib = add_struct(glib, child_struct); glib = add_struct(glib, parent_struct);
        
        % Flatten
        flat_struct = gds_flatten_for_3d(glib, 'structure_name', 'PARENT', 'verbose', 0);
        
        % Verify transformation order:
        % 1. Reflect: [0,0]->[0,0], [10,0]->[10,0], [10,5]->[10,-5], [0,5]->[0,-5]
        % 2. Rotate 90°: (x,y)->(-y,x)
        %    [0,0]->[0,0], [10,0]->[0,10], [10,-5]->[5,10], [0,-5]->[5,0]
        % 3. Magnify 2x:
        %    [0,0]->[0,0], [0,10]->[0,20], [5,10]->[10,20], [5,0]->[10,0]
        % 4. Translate by (100,50):
        %    [0,0]->[100,50], [0,20]->[100,70], [10,20]->[110,70], [10,0]->[110,50]
        
        elements = flat_struct(:);
        xy = get(elements{1}, 'xy');
        if iscell(xy)
            xy = xy{1};
        end
        
        expected = [100 50; 100 70; 110 70; 110 50; 100 50];
        
        if max(max(abs(xy - expected))) > 1e-9
            pass = false;
            msg = sprintf('Combined transformations incorrect. Max error: %.2e', max(max(abs(xy - expected))));
            return;
        end
        
        pass = true;
        msg = 'Combined transformations (reflect+rotate+mag+translate) applied correctly';
        
    catch ME
        pass = false;
        msg = sprintf('Exception: %s', ME.message);
    end
end
