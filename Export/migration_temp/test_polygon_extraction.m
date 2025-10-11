% test_polygon_extraction.m
%
% Comprehensive test for polygon extraction functionality in gds_layer_to_3d
%
% This script tests various element types and scenarios:
% - Boundary elements (rectangles, polygons)
% - Box elements
% - Path elements with width
% - Multiple layers
% - Layer filtering
% - Bounding box calculation
% - Area calculation
%
% Run this from the gdsii-toolbox-146 directory with:
%   octave Export/tests/test_polygon_extraction.m
% or from MATLAB:
%   run('Export/tests/test_polygon_extraction.m')
%
% Author: WARP AI Agent, October 2025

clear all;
close all;
clc;

fprintf('========================================================\n');
fprintf('Comprehensive Test: Polygon Extraction by Layer\n');
fprintf('========================================================\n\n');

% Add directories to path
addpath('Export');
addpath(genpath('Basic'));

% Test counter
num_tests = 0;
num_passed = 0;
num_failed = 0;

% =========================================================================
% TEST 1: Boundary elements - Simple rectangles
% =========================================================================
fprintf('TEST 1: Extract boundary elements (rectangles)\n');
fprintf('------------------------------------------------\n');
num_tests = num_tests + 1;

try
    % Create rectangles on different layers
    rect1 = [0 0; 100 0; 100 50; 0 50; 0 0];
    elem1 = gds_element('boundary', 'xy', rect1, 'layer', 1, 'dtype', 0);
    
    rect2 = [50 25; 150 25; 150 75; 50 75; 50 25];
    elem2 = gds_element('boundary', 'xy', rect2, 'layer', 2, 'dtype', 0);
    
    % Create structure and library
    test_struct = gds_structure('BoundaryTest', elem1, elem2);
    
    % Load config
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    % Extract layers
    layer_data = gds_layer_to_3d(test_struct, cfg);
    
    % Verify
    assert(length(layer_data.layers) == 2, 'Expected 2 layers');
    assert(layer_data.layers(1).num_polygons == 1, 'Layer 1 should have 1 polygon');
    assert(layer_data.layers(2).num_polygons == 1, 'Layer 2 should have 1 polygon');
    
    % Check bounding boxes
    bbox1 = layer_data.layers(1).bbox;
    assert(bbox1(1) == 0 && bbox1(2) == 0, 'Layer 1 bbox min incorrect');
    assert(bbox1(3) == 100 && bbox1(4) == 50, 'Layer 1 bbox max incorrect');
    
    % Check areas
    assert(layer_data.layers(1).area == 5000, 'Layer 1 area incorrect');
    assert(layer_data.layers(2).area == 5000, 'Layer 2 area incorrect');
    
    fprintf('✓ PASSED: Boundary rectangles extracted correctly\n');
    fprintf('  - Layer 1: bbox=[%.0f %.0f %.0f %.0f], area=%.0f\n', ...
            bbox1(1), bbox1(2), bbox1(3), bbox1(4), layer_data.layers(1).area);
    fprintf('  - Layer 2: bbox=[%.0f %.0f %.0f %.0f], area=%.0f\n\n', ...
            layer_data.layers(2).bbox, layer_data.layers(2).area);
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 2: Boundary elements - Complex polygons
% =========================================================================
fprintf('TEST 2: Extract complex polygon shapes\n');
fprintf('---------------------------------------\n');
num_tests = num_tests + 1;

try
    % Create L-shaped polygon
    l_shape = [0 0; 60 0; 60 40; 40 40; 40 100; 0 100; 0 0];
    elem_l = gds_element('boundary', 'xy', l_shape, 'layer', 1, 'dtype', 0);
    
    % Create hexagon
    theta = linspace(0, 2*pi, 7);
    hex = 50 * [cos(theta') sin(theta')] + repmat([150 50], 7, 1);
    elem_hex = gds_element('boundary', 'xy', hex, 'layer', 1, 'dtype', 0);
    
    test_struct = gds_structure('ComplexPoly', elem_l, elem_hex);
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    layer_data = gds_layer_to_3d(test_struct, cfg);
    
    % Verify
    assert(length(layer_data.layers) == 1, 'Expected 1 layer');
    assert(layer_data.layers(1).num_polygons == 2, 'Layer 1 should have 2 polygons');
    
    % Check that both polygons are present
    poly1 = layer_data.layers(1).polygons{1};
    poly2 = layer_data.layers(1).polygons{2};
    assert(size(poly1, 1) == 7, 'L-shape should have 7 vertices');
    assert(size(poly2, 1) == 7, 'Hexagon should have 7 vertices');
    
    fprintf('✓ PASSED: Complex polygons extracted correctly\n');
    fprintf('  - L-shape: %d vertices\n', size(poly1, 1));
    fprintf('  - Hexagon: %d vertices\n\n', size(poly2, 1));
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 3: Box elements
% =========================================================================
fprintf('TEST 3: Extract box elements\n');
fprintf('----------------------------\n');
num_tests = num_tests + 1;

try
    % Create box element (5-point closed rectangle)
    box_coords = [10 10; 110 10; 110 60; 10 60; 10 10];
    elem_box = gds_element('box', 'xy', box_coords, 'layer', 2, 'dtype', 0);
    
    test_struct = gds_structure('BoxTest', elem_box);
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    layer_data = gds_layer_to_3d(test_struct, cfg);
    
    % Verify
    assert(length(layer_data.layers) == 1, 'Expected 1 layer');
    assert(layer_data.layers(1).num_polygons == 1, 'Should have 1 polygon');
    assert(layer_data.layers(1).area == 5000, 'Box area incorrect');
    
    fprintf('✓ PASSED: Box element extracted correctly\n');
    fprintf('  - Area: %.0f\n\n', layer_data.layers(1).area);
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 4: Path elements with width
% =========================================================================
fprintf('TEST 4: Extract path elements (with width conversion)\n');
fprintf('----------------------------------------------------\n');
num_tests = num_tests + 1;

try
    % Create path element - simple straight path
    path_coords = [20 20; 20 80];
    elem_path = gds_element('path', 'xy', path_coords, 'width', 10, 'layer', 1, 'dtype', 0);
    
    test_struct = gds_structure('PathTest', elem_path);
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    layer_data = gds_layer_to_3d(test_struct, cfg);
    
    % Verify
    assert(length(layer_data.layers) == 1, 'Expected 1 layer');
    assert(layer_data.layers(1).num_polygons == 1, 'Should have 1 polygon from path');
    
    poly = layer_data.layers(1).polygons{1};
    assert(size(poly, 1) >= 4, 'Path polygon should have at least 4 vertices');
    
    % Path of length 60 with width 10 should have approximate area 600
    area = layer_data.layers(1).area;
    assert(area > 500 && area < 700, sprintf('Path area unexpected: %.0f', area));
    
    fprintf('✓ PASSED: Path element converted to polygon\n');
    fprintf('  - Path length: 60, width: 10\n');
    fprintf('  - Resulting polygon: %d vertices, area=%.0f\n\n', size(poly, 1), area);
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 5: Multiple elements on same layer
% =========================================================================
fprintf('TEST 5: Multiple elements on same layer\n');
fprintf('---------------------------------------\n');
num_tests = num_tests + 1;

try
    % Create multiple elements on layer 1
    rect1 = [0 0; 30 0; 30 30; 0 30; 0 0];
    rect2 = [40 40; 70 40; 70 70; 40 70; 40 40];
    rect3 = [80 80; 110 80; 110 110; 80 110; 80 110];
    
    elem1 = gds_element('boundary', 'xy', rect1, 'layer', 1, 'dtype', 0);
    elem2 = gds_element('boundary', 'xy', rect2, 'layer', 1, 'dtype', 0);
    elem3 = gds_element('boundary', 'xy', rect3, 'layer', 1, 'dtype', 0);
    
    test_struct = gds_structure('MultiElement', elem1, elem2, elem3);
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    layer_data = gds_layer_to_3d(test_struct, cfg);
    
    % Verify
    assert(length(layer_data.layers) == 1, 'Expected 1 layer');
    assert(layer_data.layers(1).num_polygons == 3, 'Should have 3 polygons');
    assert(layer_data.layers(1).area == 2700, 'Total area incorrect (3 x 900)');
    
    % Check bounding box includes all elements
    bbox = layer_data.layers(1).bbox;
    assert(bbox(1) == 0 && bbox(2) == 0, 'Bbox min incorrect');
    assert(bbox(3) == 110 && bbox(4) == 110, 'Bbox max incorrect');
    
    fprintf('✓ PASSED: Multiple elements on same layer collected\n');
    fprintf('  - Number of polygons: %d\n', layer_data.layers(1).num_polygons);
    fprintf('  - Total area: %.0f\n', layer_data.layers(1).area);
    fprintf('  - Bounding box: [%.0f %.0f %.0f %.0f]\n\n', bbox);
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 6: Layer filtering with multiple layers
% =========================================================================
fprintf('TEST 6: Layer filtering\n');
fprintf('-----------------------\n');
num_tests = num_tests + 1;

try
    % Create elements on layers 1, 2, and 3
    elem1 = gds_element('boundary', 'xy', [0 0; 10 0; 10 10; 0 10; 0 0], 'layer', 1);
    elem2 = gds_element('boundary', 'xy', [0 0; 10 0; 10 10; 0 10; 0 0], 'layer', 2);
    elem3 = gds_element('boundary', 'xy', [0 0; 10 0; 10 10; 0 10; 0 0], 'layer', 3);
    
    test_struct = gds_structure('FilterTest', elem1, elem2, elem3);
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    % Extract only layer 2
    layer_data = gds_layer_to_3d(test_struct, cfg, 'layers_filter', [2]);
    
    % Verify
    assert(length(layer_data.layers) == 1, 'Expected 1 layer after filtering');
    assert(strcmp(layer_data.layers(1).config.name, 'Layer2'), 'Wrong layer extracted');
    assert(layer_data.statistics.total_polygons == 1, 'Should have 1 polygon');
    
    fprintf('✓ PASSED: Layer filtering works correctly\n');
    fprintf('  - Filtered to layer: %s\n', layer_data.layers(1).config.name);
    fprintf('  - Polygons extracted: %d\n\n', layer_data.statistics.total_polygons);
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 7: Empty layers (no matching elements)
% =========================================================================
fprintf('TEST 7: Handle empty layers gracefully\n');
fprintf('--------------------------------------\n');
num_tests = num_tests + 1;

try
    % Create element on layer 10 (not in config)
    elem = gds_element('boundary', 'xy', [0 0; 10 0; 10 10; 0 10; 0 0], 'layer', 10);
    
    test_struct = gds_structure('EmptyTest', elem);
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    layer_data = gds_layer_to_3d(test_struct, cfg);
    
    % Verify - should return empty layer array
    assert(length(layer_data.layers) == 0, 'Should have no layers when no elements match config');
    assert(layer_data.statistics.total_elements == 1, 'Should count 1 element processed');
    assert(layer_data.statistics.total_polygons == 0, 'Should have 0 polygons extracted');
    
    fprintf('✓ PASSED: Empty layers handled correctly\n');
    fprintf('  - Elements processed: %d\n', layer_data.statistics.total_elements);
    fprintf('  - Polygons extracted: %d\n', layer_data.statistics.total_polygons);
    fprintf('  - Layers in output: %d\n\n', length(layer_data.layers));
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 8: Polygon coordinate validation
% =========================================================================
fprintf('TEST 8: Validate extracted polygon coordinates\n');
fprintf('----------------------------------------------\n');
num_tests = num_tests + 1;

try
    % Create rectangle with known coordinates
    rect = [100 200; 300 200; 300 400; 100 400; 100 200];
    elem = gds_element('boundary', 'xy', rect, 'layer', 1, 'dtype', 0);
    
    test_struct = gds_structure('CoordTest', elem);
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    layer_data = gds_layer_to_3d(test_struct, cfg);
    
    % Get extracted polygon
    poly = layer_data.layers(1).polygons{1};
    
    % Verify coordinates match input
    assert(isequal(poly, rect), 'Extracted coordinates do not match input');
    
    % Verify it's closed (first == last)
    assert(isequal(poly(1,:), poly(end,:)), 'Polygon should be closed');
    
    fprintf('✓ PASSED: Polygon coordinates preserved correctly\n');
    fprintf('  - Input rectangle: [%.0f %.0f] to [%.0f %.0f]\n', ...
            rect(1,1), rect(1,2), rect(3,1), rect(3,2));
    fprintf('  - Extracted matches input: YES\n\n');
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% SUMMARY
% =========================================================================
fprintf('\n========================================================\n');
fprintf('TEST SUMMARY - Polygon Extraction\n');
fprintf('========================================================\n');
fprintf('Total tests:  %d\n', num_tests);
fprintf('Passed:       %d (%.1f%%)\n', num_passed, 100*num_passed/num_tests);
fprintf('Failed:       %d (%.1f%%)\n', num_failed, 100*num_failed/num_tests);
fprintf('========================================================\n');

if num_failed == 0
    fprintf('\n✓✓✓ ALL POLYGON EXTRACTION TESTS PASSED ✓✓✓\n\n');
    fprintf('Section 4.2 (Polygon Extraction by Layer) is fully functional!\n');
    fprintf('\nKey capabilities verified:\n');
    fprintf('  ✓ Boundary element extraction\n');
    fprintf('  ✓ Complex polygon shapes\n');
    fprintf('  ✓ Box element extraction\n');
    fprintf('  ✓ Path-to-polygon conversion\n');
    fprintf('  ✓ Multiple elements per layer\n');
    fprintf('  ✓ Layer filtering\n');
    fprintf('  ✓ Empty layer handling\n');
    fprintf('  ✓ Coordinate preservation\n');
    fprintf('  ✓ Bounding box calculation\n');
    fprintf('  ✓ Area calculation\n\n');
else
    fprintf('\n✗✗✗ SOME TESTS FAILED ✗✗✗\n\n');
end

