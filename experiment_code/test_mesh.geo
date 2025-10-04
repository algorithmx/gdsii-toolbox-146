// Simple 2D rectangle geometry for testing
lc = 0.1;  // characteristic length (mesh size)

// Define corner points
Point(1) = {0, 0, 0, lc};
Point(2) = {1, 0, 0, lc};
Point(3) = {1, 0.5, 0, lc};
Point(4) = {0, 0.5, 0, lc};

// Define boundary lines
Line(1) = {1, 2};
Line(2) = {2, 3};
Line(3) = {3, 4};
Line(4) = {4, 1};

// Create surface
Line Loop(1) = {1, 2, 3, 4};
Plane Surface(1) = {1};

// Physical groups for boundary conditions
Physical Line(1) = {1, 2, 3, 4};  // Boundary
Physical Surface(1) = {1};  // Domain
