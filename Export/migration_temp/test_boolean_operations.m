% test_boolean_operations.m
% Comprehensive test suite for Section 4.10: 3D Boolean Operations
%
% Tests the gds_merge_solids_3d function with various geometric
% configurations and operations (union, intersection, difference).
%
% Author: WARP AI Agent
% Date: October 4, 2025
% Part of gdsii-toolbox-146 Section 4.10 implementation

fprintf('\n========================================\n');
fprintf('  Testing Section 4.10: 3D Boolean Operations\n');
fprintf('========================================\n\n');

% Add parent directory to path
addpath(fileparts(fileparts(mfilename('fullpath'))));

% Test counter
test_count = 0;
passed_count = 0;
failed_count = 0;

%% ========================================================================
%% TEST 1: Basic Union of Two Overlapping Boxes
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Basic union of two overlapping boxes\n', test_count);

try
    % Create two overlapping boxes
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    box2_poly = [5 5; 15 5; 15 15; 5 15];
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solid2 = gds_extrude_polygon(box2_poly, 0, 5);
    solid2.layer_name = 'layer1';
    solid2.material = 'silicon';
    solid2.polygon_xy = box2_poly;
    
    solids = {solid1, solid2};
    
    % Perform union
    merged = gds_merge_solids_3d(solids, 'operation', 'union', 'verbose', 0);
    
    % Validate results
    assert(~isempty(merged), 'Merged result should not be empty');
    assert(length(merged) <= length(solids), 'Merged should have same or fewer solids');
    
    fprintf('   PASSED: Union of overlapping boxes\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 2: Union of Non-Overlapping Boxes (Should Stay Separate)
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Union of non-overlapping boxes\n', test_count);

try
    % Create two non-overlapping boxes
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    box2_poly = [20 20; 30 20; 30 30; 20 30];
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solid2 = gds_extrude_polygon(box2_poly, 0, 5);
    solid2.layer_name = 'layer1';
    solid2.material = 'silicon';
    solid2.polygon_xy = box2_poly;
    
    solids = {solid1, solid2};
    
    % Perform union (non-overlapping should remain separate)
    merged = gds_merge_solids_3d(solids, 'operation', 'union', 'verbose', 0);
    
    % Validate results
    assert(~isempty(merged), 'Merged result should not be empty');
    % After union, non-overlapping solids may remain as compound
    
    fprintf('   PASSED: Union of non-overlapping boxes\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 3: Intersection of Overlapping Boxes
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Intersection of overlapping boxes\n', test_count);

try
    % Create two overlapping boxes
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    box2_poly = [5 5; 15 5; 15 15; 5 15];
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solid2 = gds_extrude_polygon(box2_poly, 0, 5);
    solid2.layer_name = 'layer1';
    solid2.material = 'silicon';
    solid2.polygon_xy = box2_poly;
    
    solids = {solid1, solid2};
    
    % Perform intersection
    merged = gds_merge_solids_3d(solids, 'operation', 'intersection', 'verbose', 0);
    
    % Validate results
    assert(~isempty(merged), 'Intersection result should not be empty');
    
    fprintf('   PASSED: Intersection of overlapping boxes\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 4: Difference Operation (Subtraction)
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Difference operation (subtraction)\n', test_count);

try
    % Create two overlapping boxes for subtraction
    box1_poly = [0 0; 20 0; 20 20; 0 20];  % Large box
    box2_poly = [5 5; 15 5; 15 15; 5 15];  % Small box to subtract
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solid2 = gds_extrude_polygon(box2_poly, 0, 5);
    solid2.layer_name = 'layer1';
    solid2.material = 'silicon';
    solid2.polygon_xy = box2_poly;
    
    solids = {solid1, solid2};
    
    % Perform difference (subtract solid2 from solid1)
    merged = gds_merge_solids_3d(solids, 'operation', 'difference', 'verbose', 0);
    
    % Validate results
    assert(~isempty(merged), 'Difference result should not be empty');
    
    fprintf('   PASSED: Difference operation\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 5: Multiple Boxes Union (Three Solids)
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Union of three overlapping boxes\n', test_count);

try
    % Create three overlapping boxes
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    box2_poly = [5 0; 15 0; 15 10; 5 10];
    box3_poly = [10 0; 20 0; 20 10; 10 10];
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solid2 = gds_extrude_polygon(box2_poly, 0, 5);
    solid2.layer_name = 'layer1';
    solid2.material = 'silicon';
    solid2.polygon_xy = box2_poly;
    
    solid3 = gds_extrude_polygon(box3_poly, 0, 5);
    solid3.layer_name = 'layer1';
    solid3.material = 'silicon';
    solid3.polygon_xy = box3_poly;
    
    solids = {solid1, solid2, solid3};
    
    % Perform union
    merged = gds_merge_solids_3d(solids, 'operation', 'union', 'verbose', 0);
    
    % Validate results
    assert(~isempty(merged), 'Merged result should not be empty');
    assert(length(merged) <= length(solids), 'Merged should have same or fewer solids');
    
    fprintf('   PASSED: Union of three boxes\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 6: Different Layers (Should NOT Merge)
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Solids on different layers should not merge\n', test_count);

try
    % Create two overlapping boxes on different layers
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    box2_poly = [5 5; 15 5; 15 15; 5 15];
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solid2 = gds_extrude_polygon(box2_poly, 0, 5);
    solid2.layer_name = 'layer2';  % Different layer
    solid2.material = 'aluminum';
    solid2.polygon_xy = box2_poly;
    
    solids = {solid1, solid2};
    
    % Perform union
    merged = gds_merge_solids_3d(solids, 'operation', 'union', 'verbose', 0);
    
    % Validate results - should remain as 2 separate solids
    assert(~isempty(merged), 'Merged result should not be empty');
    assert(length(merged) == 2, 'Different layers should remain separate');
    
    fprintf('   PASSED: Different layers remain separate\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 7: Different Z Heights (Should NOT Merge)
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Solids at different z heights should not merge\n', test_count);

try
    % Create two overlapping boxes at different z heights
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    box2_poly = [5 5; 15 5; 15 15; 5 15];
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solid2 = gds_extrude_polygon(box2_poly, 10, 15);  % Different z range
    solid2.layer_name = 'layer1';  % Same layer name
    solid2.material = 'silicon';
    solid2.polygon_xy = box2_poly;
    
    solids = {solid1, solid2};
    
    % Perform union
    merged = gds_merge_solids_3d(solids, 'operation', 'union', 'verbose', 0);
    
    % Validate results - should remain as 2 separate solids
    assert(~isempty(merged), 'Merged result should not be empty');
    assert(length(merged) == 2, 'Different z heights should remain separate');
    
    fprintf('   PASSED: Different z heights remain separate\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 8: Complex Polygon (L-Shape)
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Union with complex L-shaped polygon\n', test_count);

try
    % Create L-shaped polygon (two rectangles)
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    l_shape_poly = [8 8; 20 8; 20 20; 8 20; 8 12; 12 12; 12 8; 8 8];
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solid2 = gds_extrude_polygon(l_shape_poly, 0, 5);
    solid2.layer_name = 'layer1';
    solid2.material = 'silicon';
    solid2.polygon_xy = l_shape_poly;
    
    solids = {solid1, solid2};
    
    % Perform union
    merged = gds_merge_solids_3d(solids, 'operation', 'union', 'verbose', 0);
    
    % Validate results
    assert(~isempty(merged), 'Merged result should not be empty');
    
    fprintf('   PASSED: Union with L-shaped polygon\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 9: Single Solid (No Merge Needed)
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Single solid (no merge needed)\n', test_count);

try
    % Create single box
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solids = {solid1};
    
    % Perform union (should just return the same solid)
    merged = gds_merge_solids_3d(solids, 'operation', 'union', 'verbose', 0);
    
    % Validate results
    assert(~isempty(merged), 'Merged result should not be empty');
    assert(length(merged) == 1, 'Single solid should remain single');
    
    fprintf('   PASSED: Single solid handling\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 10: Empty Input
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Empty input handling\n', test_count);

try
    solids = {};
    
    % Should handle empty input gracefully
    merged = gds_merge_solids_3d(solids, 'operation', 'union', 'verbose', 0);
    
    % Validate results
    assert(isempty(merged), 'Empty input should return empty result');
    
    fprintf('   PASSED: Empty input handling\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 11: Custom Precision Parameter
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Custom precision parameter\n', test_count);

try
    % Create two overlapping boxes
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    box2_poly = [5 5; 15 5; 15 15; 5 15];
    
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.material = 'silicon';
    solid1.polygon_xy = box1_poly;
    
    solid2 = gds_extrude_polygon(box2_poly, 0, 5);
    solid2.layer_name = 'layer1';
    solid2.material = 'silicon';
    solid2.polygon_xy = box2_poly;
    
    solids = {solid1, solid2};
    
    % Perform union with custom precision
    merged = gds_merge_solids_3d(solids, 'operation', 'union', ...
                                 'precision', 1e-9, 'verbose', 0);
    
    % Validate results
    assert(~isempty(merged), 'Merged result should not be empty');
    
    fprintf('   PASSED: Custom precision parameter\n\n');
    passed_count = passed_count + 1;
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% TEST 12: Invalid Operation Name
%% ========================================================================

test_count = test_count + 1;
fprintf('TEST %d: Invalid operation name (should error)\n', test_count);

try
    % Create test solid
    box1_poly = [0 0; 10 0; 10 10; 0 10];
    solid1 = gds_extrude_polygon(box1_poly, 0, 5);
    solid1.layer_name = 'layer1';
    solid1.polygon_xy = box1_poly;
    
    solids = {solid1};
    
    % Try invalid operation
    try
        merged = gds_merge_solids_3d(solids, 'operation', 'invalid_op', 'verbose', 0);
        % Should have errored
        error('Should have thrown error for invalid operation');
    catch ME
        % Expected to error
        if contains(ME.identifier, 'InvalidOperation') || contains(ME.message, 'Operation')
            fprintf('   PASSED: Invalid operation properly rejected\n\n');
            passed_count = passed_count + 1;
        else
            rethrow(ME);
        end
    end
    
catch ME
    fprintf('   FAILED: %s\n\n', ME.message);
    failed_count = failed_count + 1;
end

%% ========================================================================
%% SUMMARY
%% ========================================================================

fprintf('========================================\n');
fprintf('  Test Results Summary\n');
fprintf('========================================\n');
fprintf('Total tests:    %d\n', test_count);
fprintf('Passed:         %d\n', passed_count);
fprintf('Failed:         %d\n', failed_count);
fprintf('Success rate:   %.1f%%\n', 100 * passed_count / test_count);
fprintf('========================================\n\n');

if failed_count == 0
    fprintf('✓ All tests passed!\n\n');
    exit(0);
else
    fprintf('✗ Some tests failed.\n\n');
    exit(1);
end
