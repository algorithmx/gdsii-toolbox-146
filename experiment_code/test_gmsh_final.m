% Test script for msh package with Gmsh
% Generates a simple 2D mesh and displays statistics

clear all;
close all;

% Load the msh package
pkg load msh;

fprintf('Testing msh package with Gmsh...\n');
fprintf('================================\n\n');

% Generate mesh from .geo file
fprintf('Generating mesh from test_mesh.geo...\n');
[mesh, gmsh_output] = msh2m_gmsh('test_mesh');

fprintf('Mesh generated successfully!\n\n');

% Display mesh structure fields
fprintf('Mesh structure fields:\n');
fprintf('---------------------\n');
disp(fieldnames(mesh));

% Display mesh statistics
fprintf('\nMesh Statistics:\n');
fprintf('----------------\n');
fprintf('Points (p): %dx%d\n', size(mesh.p));
fprintf('Triangles (t): %dx%d\n', size(mesh.t));
fprintf('Edges (e): %dx%d\n', size(mesh.e));

% Display actual data
fprintf('\nMesh Points (first 10):\n');
disp(mesh.p(1:min(10, size(mesh.p,1)), :));

fprintf('\nMesh Triangles (first 10):\n');
disp(mesh.t(1:min(10, size(mesh.t,1)), :));

% Try plotting
fprintf('\nAttempting to plot mesh...\n');
try
    figure('Name', 'Gmsh Test Mesh');
    
    % PDE-tool format: mesh.p is 2×N (rows are x,y; cols are points)
    % mesh.t is 4×M (first 3 rows are triangle vertices, 4th is subdomain)
    num_points = size(mesh.p, 2);
    num_triangles = size(mesh.t, 2);
    
    fprintf('Creating plot with %d points and %d triangles...\n', num_points, num_triangles);
    
    if num_points > 3
        % Plot the mesh structure
        % triplot expects: triplot(triangles, x_coords, y_coords)
        triplot(mesh.t(1:3,:)', mesh.p(1,:), mesh.p(2,:), 'b-', 'LineWidth', 1);
        hold on;
        plot(mesh.p(1,:), mesh.p(2,:), 'r.', 'MarkerSize', 8);
        
        axis equal;
        grid on;
        xlabel('X [units]');
        ylabel('Y [units]');
        title(sprintf('2D Mesh: %d nodes, %d triangles', num_points, num_triangles));
        legend('Mesh edges', 'Nodes', 'Location', 'best');
        
        fprintf('Plot successful!\n');
        print('-dpng', 'test_mesh_output.png');
        fprintf('Saved plot to test_mesh_output.png\n');
    else
        fprintf('Mesh too small to plot (only %d nodes)\n', num_points);
    end
catch err
    fprintf('Plotting error: %s\n', err.message);
    fprintf('Stack:\n');
    disp(err.stack);
end

fprintf('\nTest completed!\n');
