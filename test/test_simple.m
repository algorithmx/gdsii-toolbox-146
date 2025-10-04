pkg load msh;

fprintf('Testing msh2m_gmsh...\n');

try
    [mesh, output] = msh2m_gmsh('test_mesh');
    fprintf('Success!\n');
    fprintf('Nodes: %d\n', size(mesh.p, 1));
    fprintf('Triangles: %d\n', size(mesh.t, 1));
catch err
    fprintf('Error: %s\n', err.message);
    % Try to see if there's a log file
    if exist('test_mesh.log', 'file')
        fprintf('\nLog file contents:\n');
        type('test_mesh.log');
    end
end
