function test_extrusion()
% TEST_EXTRUSION - Test suite for gds_extrude_polygon
%
% Tests the basic extrusion engine functionality including:
%   - Simple rectangular extrusion
%   - Complex polygon extrusion
%   - Polygon orientation handling
%   - Edge cases (minimum vertices, degenerate cases)
%   - Volume and area calculations
%   - Bounding box calculations
%
% USAGE:
%   test_extrusion()

    fprintf('\n');
    fprintf('=======================================================\n');
    fprintf('Testing gds_extrude_polygon.m - Basic Extrusion Engine\n');
    fprintf('=======================================================\n\n');
    
    % Counter for tests
    total_tests = 0;
    passed_tests = 0;
    
    % Test 1: Simple Rectangle
    [pass, msg] = test_simple_rectangle();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 1: %s\n', msg);
    else
        fprintf('✗ Test 1: %s\n', msg);
    end
    
    % Test 2: Triangle
    [pass, msg] = test_triangle();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 2: %s\n', msg);
    else
        fprintf('✗ Test 2: %s\n', msg);
    end
    
    % Test 3: Complex Polygon (L-shape)
    [pass, msg] = test_complex_polygon();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 3: %s\n', msg);
    else
        fprintf('✗ Test 3: %s\n', msg);
    end
    
    % Test 4: Clockwise Polygon (should be auto-corrected)
    [pass, msg] = test_clockwise_polygon();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 4: %s\n', msg);
    else
        fprintf('✗ Test 4: %s\n', msg);
    end
    
    % Test 5: Polygon with Duplicate Points
    [pass, msg] = test_duplicate_points();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 5: %s\n', msg);
    else
        fprintf('✗ Test 5: %s\n', msg);
    end
    
    % Test 6: Volume Calculation
    [pass, msg] = test_volume_calculation();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 6: %s\n', msg);
    else
        fprintf('✗ Test 6: %s\n', msg);
    end
    
    % Test 7: Bounding Box
    [pass, msg] = test_bounding_box();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 7: %s\n', msg);
    else
        fprintf('✗ Test 7: %s\n', msg);
    end
    
    % Test 8: Error Handling (invalid inputs)
    [pass, msg] = test_error_handling();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 8: %s\n', msg);
    else
        fprintf('✗ Test 8: %s\n', msg);
    end
    
    % Test 9: Face Structure
    [pass, msg] = test_face_structure();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 9: %s\n', msg);
    else
        fprintf('✗ Test 9: %s\n', msg);
    end
    
    % Test 10: Options (simplify, tolerance)
    [pass, msg] = test_options();
    total_tests = total_tests + 1;
    if pass
        passed_tests = passed_tests + 1;
        fprintf('✓ Test 10: %s\n', msg);
    else
        fprintf('✗ Test 10: %s\n', msg);
    end
    
    % Summary
    fprintf('\n');
    fprintf('=======================================================\n');
    fprintf('Test Summary: %d/%d tests passed\n', passed_tests, total_tests);
    if passed_tests == total_tests
        fprintf('Status: ALL TESTS PASSED ✓\n');
    else
        fprintf('Status: SOME TESTS FAILED ✗\n');
    end
    fprintf('=======================================================\n\n');
    
end

%% Individual Test Functions

function [pass, msg] = test_simple_rectangle()
    % Test basic rectangular extrusion
    try
        % Create a 10x5 rectangle
        poly = [0 0; 10 0; 10 5; 0 5];
        z_bottom = 0;
        z_top = 2;
        
        solid = gds_extrude_polygon(poly, z_bottom, z_top);
        
        % Check basic properties
        if solid.num_vertices ~= 8
            pass = false;
            msg = sprintf('Simple Rectangle: Expected 8 vertices, got %d', solid.num_vertices);
            return;
        end
        
        if solid.num_faces ~= 6  % 1 bottom + 1 top + 4 sides
            pass = false;
            msg = sprintf('Simple Rectangle: Expected 6 faces, got %d', solid.num_faces);
            return;
        end
        
        % Check height
        if abs(solid.height - 2) > 1e-9
            pass = false;
            msg = sprintf('Simple Rectangle: Expected height 2, got %.6f', solid.height);
            return;
        end
        
        pass = true;
        msg = 'Simple Rectangle: Correct vertices, faces, and height';
        
    catch err
        pass = false;
        msg = sprintf('Simple Rectangle: Error - %s', err.message);
    end
end

function [pass, msg] = test_triangle()
    % Test triangular extrusion
    try
        % Create a triangle
        poly = [0 0; 4 0; 2 3];
        z_bottom = 1;
        z_top = 5;
        
        solid = gds_extrude_polygon(poly, z_bottom, z_top);
        
        % Check basic properties
        if solid.num_vertices ~= 6
            pass = false;
            msg = sprintf('Triangle: Expected 6 vertices, got %d', solid.num_vertices);
            return;
        end
        
        if solid.num_faces ~= 5  % 1 bottom + 1 top + 3 sides
            pass = false;
            msg = sprintf('Triangle: Expected 5 faces, got %d', solid.num_faces);
            return;
        end
        
        pass = true;
        msg = 'Triangle: Correct structure';
        
    catch err
        pass = false;
        msg = sprintf('Triangle: Error - %s', err.message);
    end
end

function [pass, msg] = test_complex_polygon()
    % Test L-shaped polygon
    try
        % Create an L-shape
        poly = [0 0; 3 0; 3 2; 1 2; 1 3; 0 3];
        z_bottom = 0;
        z_top = 1.5;
        
        solid = gds_extrude_polygon(poly, z_bottom, z_top);
        
        % Check basic properties
        if solid.num_vertices ~= 12
            pass = false;
            msg = sprintf('Complex Polygon: Expected 12 vertices, got %d', solid.num_vertices);
            return;
        end
        
        if solid.num_faces ~= 8  % 1 bottom + 1 top + 6 sides
            pass = false;
            msg = sprintf('Complex Polygon: Expected 8 faces, got %d', solid.num_faces);
            return;
        end
        
        pass = true;
        msg = 'Complex Polygon (L-shape): Correct structure';
        
    catch err
        pass = false;
        msg = sprintf('Complex Polygon: Error - %s', err.message);
    end
end

function [pass, msg] = test_clockwise_polygon()
    % Test that CW polygons are automatically converted to CCW
    try
        % Create a CW rectangle (reverse of CCW)
        poly_cw = [0 0; 0 5; 10 5; 10 0];
        z_bottom = 0;
        z_top = 2;
        
        solid = gds_extrude_polygon(poly_cw, z_bottom, z_top);
        
        % Should still work correctly
        if solid.num_vertices ~= 8
            pass = false;
            msg = sprintf('Clockwise Polygon: Expected 8 vertices, got %d', solid.num_vertices);
            return;
        end
        
        % Base area should be positive
        if solid.base_area <= 0
            pass = false;
            msg = sprintf('Clockwise Polygon: Base area should be positive, got %.6f', solid.base_area);
            return;
        end
        
        pass = true;
        msg = 'Clockwise Polygon: Auto-corrected to CCW';
        
    catch err
        pass = false;
        msg = sprintf('Clockwise Polygon: Error - %s', err.message);
    end
end

function [pass, msg] = test_duplicate_points()
    % Test polygon with duplicate consecutive points
    try
        % Rectangle with duplicate points
        poly = [0 0; 0 0; 10 0; 10 0; 10 5; 0 5];
        z_bottom = 0;
        z_top = 1;
        
        solid = gds_extrude_polygon(poly, z_bottom, z_top);
        
        % Should clean up duplicates and work correctly
        if solid.num_vertices > 8
            pass = false;
            msg = sprintf('Duplicate Points: Too many vertices after cleanup: %d', solid.num_vertices);
            return;
        end
        
        pass = true;
        msg = 'Duplicate Points: Correctly removed duplicates';
        
    catch err
        pass = false;
        msg = sprintf('Duplicate Points: Error - %s', err.message);
    end
end

function [pass, msg] = test_volume_calculation()
    % Test volume calculation for known geometry
    try
        % 10x5 rectangle, height 2 -> volume = 100
        poly = [0 0; 10 0; 10 5; 0 5];
        z_bottom = 0;
        z_top = 2;
        
        solid = gds_extrude_polygon(poly, z_bottom, z_top);
        expected_volume = 10 * 5 * 2;
        
        if abs(solid.volume - expected_volume) > 1e-6
            pass = false;
            msg = sprintf('Volume: Expected %.2f, got %.6f', expected_volume, solid.volume);
            return;
        end
        
        pass = true;
        msg = sprintf('Volume: Correct calculation (%.2f)', solid.volume);
        
    catch err
        pass = false;
        msg = sprintf('Volume: Error - %s', err.message);
    end
end

function [pass, msg] = test_bounding_box()
    % Test bounding box calculation
    try
        poly = [1 2; 5 2; 5 7; 1 7];
        z_bottom = 3;
        z_top = 8;
        
        solid = gds_extrude_polygon(poly, z_bottom, z_top);
        
        expected_bbox = [1, 2, 3, 5, 7, 8];
        
        if any(abs(solid.bbox - expected_bbox) > 1e-9)
            pass = false;
            msg = sprintf('Bounding Box: Expected [%s], got [%s]', ...
                         num2str(expected_bbox), num2str(solid.bbox));
            return;
        end
        
        pass = true;
        msg = 'Bounding Box: Correct calculation';
        
    catch err
        pass = false;
        msg = sprintf('Bounding Box: Error - %s', err.message);
    end
end

function [pass, msg] = test_error_handling()
    % Test error handling for invalid inputs
    try
        poly = [0 0; 10 0; 10 5; 0 5];
        
        % Test 1: z_top <= z_bottom
        try
            gds_extrude_polygon(poly, 5, 2);
            pass = false;
            msg = 'Error Handling: Failed to catch z_top <= z_bottom';
            return;
        catch
            % Expected
        end
        
        % Test 2: Too few vertices
        try
            gds_extrude_polygon([0 0; 1 1], 0, 1);
            pass = false;
            msg = 'Error Handling: Failed to catch too few vertices';
            return;
        catch
            % Expected
        end
        
        % Test 3: Invalid polygon format
        try
            gds_extrude_polygon([0 0 0; 1 1 1], 0, 1);
            pass = false;
            msg = 'Error Handling: Failed to catch invalid polygon format';
            return;
        catch
            % Expected
        end
        
        pass = true;
        msg = 'Error Handling: All invalid inputs caught correctly';
        
    catch err
        pass = false;
        msg = sprintf('Error Handling: Unexpected error - %s', err.message);
    end
end

function [pass, msg] = test_face_structure()
    % Test face structure integrity
    try
        poly = [0 0; 4 0; 4 3; 0 3];
        z_bottom = 0;
        z_top = 2;
        
        solid = gds_extrude_polygon(poly, z_bottom, z_top);
        
        % Check face structure
        if ~iscell(solid.faces)
            pass = false;
            msg = 'Face Structure: faces should be a cell array';
            return;
        end
        
        % Check bottom face
        if length(solid.bottom_face) ~= 4
            pass = false;
            msg = sprintf('Face Structure: Bottom face should have 4 vertices, got %d', ...
                         length(solid.bottom_face));
            return;
        end
        
        % Check top face
        if length(solid.top_face) ~= 4
            pass = false;
            msg = sprintf('Face Structure: Top face should have 4 vertices, got %d', ...
                         length(solid.top_face));
            return;
        end
        
        % Check side faces
        if length(solid.side_faces) ~= 4
            pass = false;
            msg = sprintf('Face Structure: Should have 4 side faces, got %d', ...
                         length(solid.side_faces));
            return;
        end
        
        % Each side face should have 4 vertices
        for i = 1:length(solid.side_faces)
            if length(solid.side_faces{i}) ~= 4
                pass = false;
                msg = sprintf('Face Structure: Side face %d should have 4 vertices, got %d', ...
                             i, length(solid.side_faces{i}));
                return;
            end
        end
        
        pass = true;
        msg = 'Face Structure: All faces correctly structured';
        
    catch err
        pass = false;
        msg = sprintf('Face Structure: Error - %s', err.message);
    end
end

function [pass, msg] = test_options()
    % Test optional parameters
    try
        % Polygon with collinear points
        poly = [0 0; 5 0; 10 0; 10 5; 0 5];  % Middle point is collinear
        z_bottom = 0;
        z_top = 1;
        
        % Test with simplification
        options.simplify = true;
        options.tolerance = 1e-6;
        solid = gds_extrude_polygon(poly, z_bottom, z_top, options);
        
        % After simplification, should have fewer vertices
        % (removing collinear middle point)
        if solid.num_vertices > 8  % 4 bottom + 4 top = 8
            pass = false;
            msg = sprintf('Options (simplify): Expected <= 8 vertices, got %d', solid.num_vertices);
            return;
        end
        
        pass = true;
        msg = 'Options: Simplification works correctly';
        
    catch err
        pass = false;
        msg = sprintf('Options: Error - %s', err.message);
    end
end
