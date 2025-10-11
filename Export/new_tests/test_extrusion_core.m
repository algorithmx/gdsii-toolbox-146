function results = test_extrusion_core()
% TEST_EXTRUSION_CORE - Test 2D to 3D polygon extrusion
%
% Tests the gds_extrude_polygon function which converts 2D polygons
% to 3D solids by extruding along the Z-axis.
%
% COVERAGE:
%   - Simple rectangular extrusion
%   - Triangular polygon extrusion
%   - Volume calculation validation
%   - Error handling for invalid inputs
%
% USAGE:
%   results = test_extrusion_core()
%
% RETURNS:
%   results - Structure with test results and statistics
%
% Author: WARP AI Agent, October 2025
% Part of essential GDS-STL-STEP test suite

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('Testing 3D Extrusion Core\n');
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
    
    % Initialize results
    results = struct();
    results.total = 0;
    results.passed = 0;
    results.failed = 0;
    results.test_names = {};
    results.test_status = {};
    
    % Run essential tests
    results = run_test(results, 'Simple rectangular extrusion', ...
                       @test_simple_rectangle);
    
    results = run_test(results, 'Triangular polygon extrusion', ...
                       @test_triangle);
    
    results = run_test(results, 'Volume calculation validation', ...
                       @test_volume_calculation);
    
    results = run_test(results, 'Error handling - invalid inputs', ...
                       @test_error_handling);
    
    % Print summary
    fprintf('\n========================================\n');
    fprintf('Extrusion Core Test Summary\n');
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
    % Run a single test and update results
    
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

function test_simple_rectangle()
    % Test basic rectangular extrusion
    
    % Create a 10x5 rectangle
    poly = [0 0; 10 0; 10 5; 0 5];
    z_bottom = 0;
    z_top = 2;
    
    solid = gds_extrude_polygon(poly, z_bottom, z_top);
    
    % Check basic properties
    assert(solid.num_vertices == 8, ...
           sprintf('Expected 8 vertices, got %d', solid.num_vertices));
    
    assert(solid.num_faces == 6, ...
           sprintf('Expected 6 faces (1 bottom + 1 top + 4 sides), got %d', solid.num_faces));
    
    % Check height
    assert(abs(solid.height - 2) < 1e-9, ...
           sprintf('Expected height 2, got %.6f', solid.height));
    
    fprintf('  Vertices: %d (correct)\n', solid.num_vertices);
    fprintf('  Faces: %d (correct)\n', solid.num_faces);
    fprintf('  Height: %.2f (correct)\n', solid.height);
end

function test_triangle()
    % Test triangular extrusion
    
    % Create a triangle
    poly = [0 0; 4 0; 2 3];
    z_bottom = 1;
    z_top = 5;
    
    solid = gds_extrude_polygon(poly, z_bottom, z_top);
    
    % Check basic properties
    assert(solid.num_vertices == 6, ...
           sprintf('Expected 6 vertices, got %d', solid.num_vertices));
    
    assert(solid.num_faces == 5, ...
           sprintf('Expected 5 faces (1 bottom + 1 top + 3 sides), got %d', solid.num_faces));
    
    % Check height
    expected_height = 4;  % 5 - 1 = 4
    assert(abs(solid.height - expected_height) < 1e-9, ...
           sprintf('Expected height %d, got %.6f', expected_height, solid.height));
    
    fprintf('  Vertices: %d (correct)\n', solid.num_vertices);
    fprintf('  Faces: %d (correct)\n', solid.num_faces);
    fprintf('  Height: %.2f (correct)\n', solid.height);
end

function test_volume_calculation()
    % Test volume calculation for simple box
    
    % Create a 10x5 rectangle extruded to height 2
    poly = [0 0; 10 0; 10 5; 0 5];
    z_bottom = 0;
    z_top = 2;
    
    solid = gds_extrude_polygon(poly, z_bottom, z_top);
    
    % Expected volume = base_area * height = (10*5) * 2 = 100
    expected_volume = 100;
    
    assert(isfield(solid, 'volume'), 'Solid should have volume field');
    assert(abs(solid.volume - expected_volume) < 1e-6, ...
           sprintf('Expected volume %.2f, got %.6f', expected_volume, solid.volume));
    
    fprintf('  Base area: 10 × 5 = 50\n');
    fprintf('  Height: 2\n');
    fprintf('  Volume: %.2f (correct)\n', solid.volume);
end

function test_error_handling()
    % Test error handling for invalid inputs
    
    % Test 1: Empty polygon
    error_caught = false;
    try
        gds_extrude_polygon([], 0, 1);
    catch
        error_caught = true;
    end
    assert(error_caught, 'Should reject empty polygon');
    fprintf('  ✓ Empty polygon rejected\n');
    
    % Test 2: Invalid z coordinates (z_top < z_bottom)
    error_caught = false;
    try
        poly = [0 0; 1 0; 1 1; 0 1];
        gds_extrude_polygon(poly, 5, 2);  % z_top < z_bottom
    catch
        error_caught = true;
    end
    assert(error_caught, 'Should reject z_top < z_bottom');
    fprintf('  ✓ Invalid z coordinates rejected\n');
    
    % Test 3: Polygon with too few vertices
    error_caught = false;
    try
        poly = [0 0; 1 0];  % Only 2 vertices
        gds_extrude_polygon(poly, 0, 1);
    catch
        error_caught = true;
    end
    assert(error_caught, 'Should reject polygon with < 3 vertices');
    fprintf('  ✓ Too few vertices rejected\n');
end
