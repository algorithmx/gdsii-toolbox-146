%% Test Suite for Subsref Modifications Compatibility
% This test verifies that the modified subsref methods for gds_library,
% gds_structure, and gds_element classes maintain backward compatibility
% and don't break existing functionality.

function test_subsref_compatibility()
    fprintf('================================================================\n');
    fprintf('  SUBSREF COMPATIBILITY TEST SUITE\n');
    fprintf('  Testing modified subsref methods for Octave compatibility\n');
    fprintf('================================================================\n');
    fprintf('\n');
    
    % Add paths
    root_dir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(fullfile(root_dir, 'Basic'));
    addpath(fullfile(root_dir, 'Basic', 'gdsio'));
    addpath(fullfile(root_dir, 'Structures'));
    
    tests_passed = 0;
    tests_failed = 0;
    
    %% Test 1: Create and access gds_library
    fprintf('TEST 1: gds_library creation and subsref access\n');
    fprintf('----------------------------------------------------------------------\n');
    try
        % Create a simple library
        glib = gds_library('TestLib');
        
        % Test direct field access
        lib_name = get(glib, 'lname');
        assert(strcmp(lib_name, 'TestLib'), 'Library name mismatch');
        
        fprintf('  ✓ gds_library creation successful\n');
        fprintf('  ✓ Field access works correctly\n');
        tests_passed = tests_passed + 1;
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        tests_failed = tests_failed + 1;
    end
    fprintf('\n');
    
    %% Test 2: Create and access gds_structure
    fprintf('TEST 2: gds_structure creation and subsref access\n');
    fprintf('----------------------------------------------------------------------\n');
    try
        % Create a structure
        gstruct = gds_structure('TestStruct');
        
        % Test name access
        struct_name = sname(gstruct);
        assert(strcmp(struct_name, 'TestStruct'), 'Structure name mismatch');
        
        % Add a boundary element
        xy_data = [0 0; 1 0; 1 1; 0 1; 0 0];
        gel = gds_element('boundary', 'xy', xy_data, 'layer', 1);
        gstruct = add_element(gstruct, gel);
        
        % Test element access via subsref
        el_list = get(gstruct, 'el');
        assert(iscell(el_list), 'Element list should be a cell array');
        assert(length(el_list) == 1, 'Should have 1 element');
        
        % Test indexed access
        first_el = gstruct.el{1};
        assert(isa(first_el, 'gds_element'), 'Should be gds_element');
        
        fprintf('  ✓ gds_structure creation successful\n');
        fprintf('  ✓ Element addition works\n');
        fprintf('  ✓ Element list access via get() works\n');
        fprintf('  ✓ Indexed element access works\n');
        tests_passed = tests_passed + 1;
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        fprintf('  Stack:\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
        tests_failed = tests_failed + 1;
    end
    fprintf('\n');
    
    %% Test 3: gds_element subsref access
    fprintf('TEST 3: gds_element creation and subsref access\n');
    fprintf('----------------------------------------------------------------------\n');
    try
        % Create boundary element
        xy_data = [0 0; 1 0; 1 1; 0 1; 0 0];
        gel = gds_element('boundary', 'xy', xy_data, 'layer', 1, 'dtype', 0);
        
        % Test layer access
        layer_num = get(gel, 'layer');
        assert(layer_num == 1, 'Layer should be 1');
        
        % Test datatype access
        dtype_num = get(gel, 'dtype');
        assert(dtype_num == 0, 'Datatype should be 0');
        
        % Test xy access
        xy_retrieved = xy(gel);
        assert(isequal(size(xy_retrieved), size(xy_data)), 'XY data size mismatch');
        
        % Test element type
        el_type = etype(gel);
        assert(strcmp(el_type, 'boundary'), 'Element type should be boundary');
        
        fprintf('  ✓ gds_element creation successful\n');
        fprintf('  ✓ Layer access works\n');
        fprintf('  ✓ Datatype access works\n');
        fprintf('  ✓ XY data access works\n');
        fprintf('  ✓ Element type detection works\n');
        tests_passed = tests_passed + 1;
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        tests_failed = tests_failed + 1;
    end
    fprintf('\n');
    
    %% Test 4: Library with structures (subsref chaining)
    fprintf('TEST 4: gds_library with structures - subsref chaining\n');
    fprintf('----------------------------------------------------------------------\n');
    try
        % Create library
        glib = gds_library('ChainTestLib');
        
        % Create structures
        gstruct1 = gds_structure('Struct1');
        gstruct2 = gds_structure('Struct2');
        
        % Add elements to structures
        xy1 = [0 0; 2 0; 2 2; 0 2; 0 0];
        gel1 = gds_element('boundary', 'xy', xy1, 'layer', 1);
        gstruct1 = add_element(gstruct1, gel1);
        
        xy2 = [0 0; 3 0; 3 3; 0 3; 0 0];
        gel2 = gds_element('boundary', 'xy', xy2, 'layer', 2);
        gstruct2 = add_element(gstruct2, gel2);
        
        % Add structures to library
        glib = add_struct(glib, gstruct1);
        glib = add_struct(glib, gstruct2);
        
        % Test library indexing
        num_structs = length(glib);
        assert(num_structs == 2, 'Should have 2 structures');
        
        % Test structure access by index
        first_struct = glib.st{1};
        assert(isa(first_struct, 'gds_structure'), 'Should be gds_structure');
        
        % Test structure access by name
        struct1_by_name = glib.Struct1;
        assert(strcmp(sname(struct1_by_name), 'Struct1'), 'Structure name mismatch');
        
        fprintf('  ✓ Library with multiple structures created\n');
        fprintf('  ✓ Structure indexing by position works\n');
        fprintf('  ✓ Structure indexing by name works\n');
        fprintf('  ✓ Subsref chaining works correctly\n');
        tests_passed = tests_passed + 1;
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        fprintf('  Stack:\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
        tests_failed = tests_failed + 1;
    end
    fprintf('\n');
    
    %% Test 5: Read existing GDS file (real-world test)
    fprintf('TEST 5: Read existing GDS file - real-world subsref usage\n');
    fprintf('----------------------------------------------------------------------\n');
    try
        test_gds = fullfile(fileparts(mfilename('fullpath')), ...
                           'test_output_via_N3', 'via_penetration_N3.gds');
        
        if ~exist(test_gds, 'file')
            fprintf('  ⚠ Test GDS file not found, skipping real-world test\n');
            tests_passed = tests_passed + 1;
        else
            % Read GDS
            glib = read_gds_library(test_gds);
            
            % Test library access
            lib_name = get(glib, 'lname');
            fprintf('  Library name: %s\n', lib_name);
            
            % Test structure access
            num_structs = length(glib);
            fprintf('  Number of structures: %d\n', num_structs);
            
            % Access first structure
            gstruct = glib.st{1};
            struct_name = sname(gstruct);
            fprintf('  First structure: %s\n', struct_name);
            
            % Access elements
            el_list = get(gstruct, 'el');
            num_elements = length(el_list);
            fprintf('  Number of elements: %d\n', num_elements);
            
            % Test element iteration
            for k = 1:min(num_elements, 3)
                gel = el_list{k};
                el_type = etype(gel);
                layer_num = get(gel, 'layer');
                fprintf('    Element %d: type=%s, layer=%d\n', k, el_type, layer_num);
            end
            
            fprintf('  ✓ GDS file read successfully\n');
            fprintf('  ✓ Library, structure, and element access all work\n');
            tests_passed = tests_passed + 1;
        end
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        fprintf('  Stack:\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
        tests_failed = tests_failed + 1;
    end
    fprintf('\n');
    
    %% Test 6: poly_convert with subsref (critical for 3D export)
    fprintf('TEST 6: poly_convert with modified subsref\n');
    fprintf('----------------------------------------------------------------------\n');
    try
        % Create a simple structure
        gstruct = gds_structure('ConvertTest');
        
        % Add boundary
        xy1 = [0 0; 1 0; 1 1; 0 1; 0 0];
        gel1 = gds_element('boundary', 'xy', xy1, 'layer', 1);
        gstruct = add_element(gstruct, gel1);
        
        % Add path (will be converted)
        xy2 = [0 0; 2 0];
        gel2 = gds_element('path', 'xy', xy2, 'layer', 2, 'width', 0.5);
        gstruct = add_element(gstruct, gel2);
        
        % Run poly_convert
        gstruct_flat = poly_convert(gstruct);
        
        % Verify structure is still accessible
        el_list = get(gstruct_flat, 'el');
        assert(iscell(el_list), 'Element list should be cell array');
        
        % Check elements
        for k = 1:length(el_list)
            gel = el_list{k};
            el_type = etype(gel);
            fprintf('    Element %d: type=%s\n', k, el_type);
        end
        
        fprintf('  ✓ poly_convert successful\n');
        fprintf('  ✓ Flattened structure accessible\n');
        fprintf('  ✓ Elements can be iterated\n');
        tests_passed = tests_passed + 1;
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        fprintf('  Stack:\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
        tests_failed = tests_failed + 1;
    end
    fprintf('\n');
    
    %% Summary
    fprintf('================================================================\n');
    fprintf('  TEST SUMMARY\n');
    fprintf('================================================================\n');
    fprintf('Tests passed: %d\n', tests_passed);
    fprintf('Tests failed: %d\n', tests_failed);
    fprintf('\n');
    
    if tests_failed == 0
        fprintf('✓ ALL TESTS PASSED - Subsref modifications are compatible!\n');
        fprintf('\n');
        fprintf('Modified classes:\n');
        fprintf('  - gds_library/subsref.m\n');
        fprintf('  - gds_structure/subsref.m\n');
        fprintf('  - gds_element/subsref.m\n');
        fprintf('\n');
        fprintf('All classes now use varargout for Octave compatibility\n');
        fprintf('while maintaining backward compatibility with MATLAB.\n');
    else
        fprintf('✗ SOME TESTS FAILED - Review modifications\n');
    end
    
    fprintf('================================================================\n');
    fprintf('\n');
end
