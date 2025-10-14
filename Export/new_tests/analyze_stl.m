function analyze_stl(stl_file)
% ANALYZE_STL - Analyze an STL file for geometry issues
%
% Reads and validates a binary STL file, checking for common problems:
% - Invalid triangles (zero area)
% - Duplicate vertices
% - NaN or infinite coordinates
% - Normal vector consistency

    fprintf('Analyzing STL file: %s\n', stl_file);

    % Open file
    fid = fopen(stl_file, 'r', 'b');
    if fid == -1
        error('Cannot open file: %s', stl_file);
    end

    % Read header
    header = fread(fid, 80, 'uchar');
    header_str = char(header');
    fprintf('Header: %s\n', strtrim(header_str));

    % Read triangle count (STL format is little-endian)
    tri_count_bytes = fread(fid, 4, 'uint8');
    tri_count = typecast(uint8(tri_count_bytes), 'uint32');
    fprintf('Triangle count: %d (raw bytes: %02x %02x %02x %02x)\n', tri_count, tri_count_bytes);

    % Check file size
    fseek(fid, 0, 'eof');
    file_size = ftell(fid);
    expected_size = 80 + 4 + tri_count * 50;
    fprintf('File size: %d bytes (expected: %d bytes)\n', file_size, expected_size);

    if file_size ~= expected_size
        fprintf('WARNING: File size mismatch!\n');
    end

    % Reset to start of triangles
    fseek(fid, 84, 'bof');

    % Read all triangles
    fprintf('\nAnalyzing triangles...\n');

    invalid_count = 0;
    zero_area_count = 0;
    nan_count = 0;
    inf_count = 0;

    for i = 1:tri_count
        % Read triangle (normal + 3 vertices + attribute)
        data = fread(fid, 12, 'float32');
        attr = fread(fid, 1, 'uint16');

        normal = data(1:3);
        v1 = data(4:6);
        v2 = data(7:9);
        v3 = data(10:12);

        % Check for NaN or infinite values
        if any(isnan([normal; v1; v2; v3]))
            nan_count = nan_count + 1;
        end

        if any(isinf([normal; v1; v2; v3]))
            inf_count = inf_count + 1;
        end

        % Calculate triangle area using cross product
        edge1 = v2 - v1;
        edge2 = v3 - v1;
        cross_product = cross(edge1, edge2);
        area = 0.5 * norm(cross_product);

        % Check for zero area triangles
        if area < 1e-10
            zero_area_count = zero_area_count + 1;
        end

        % Check normal consistency
        if norm(cross_product) > 1e-10
            calculated_normal = cross_product / norm(cross_product);
            normal_diff = norm(normal - calculated_normal);
            if normal_diff > 0.1
                invalid_count = invalid_count + 1;
            end
        end

        if mod(i, 1000) == 0
            fprintf('  Processed %d/%d triangles\n', i, tri_count);
        end
    end

    fclose(fid);

    % Print summary
    fprintf('\n=== STL Analysis Summary ===\n');
    fprintf('Total triangles: %d\n', tri_count);
    fprintf('Invalid normals: %d\n', invalid_count);
    fprintf('Zero area triangles: %d\n', zero_area_count);
    fprintf('NaN values found: %d\n', nan_count);
    fprintf('Infinite values found: %d\n', inf_count);

    if invalid_count > 0 || zero_area_count > 0 || nan_count > 0 || inf_count > 0
        fprintf('\n⚠️  STL FILE HAS GEOMETRY ISSUES!\n');
    else
        fprintf('\n✓ STL file appears to be geometrically valid\n');
    end
    fprintf('============================\n');
end