function test_pdk_converter(varargin)
%function test_pdk_converter(varargin)
%
% test_pdk_converter: Comprehensive test suite for PDK to layer configuration converters
%
% This function tests both gds_convert_lyp_lyt_to_config and gds_convert_pdk_to_config
% converters with various input formats and edge cases.
%
% INPUTS (NAME-VALUE PAIRS):
%   'verbose' : Boolean enable verbose output (default: true)
%   'test_all': Boolean run all tests including optional ones (default: true)
%   'create_fixtures': Boolean create test fixture files (default: false)
%
% USAGE:
%   test_pdk_converter();                    % Run all tests
%   test_pdk_converter('verbose', false);   % Run tests quietly
%   test_pdk_converter('create_fixtures', true); % Create test files
%
% TEST CATEGORIES:
%   1. Basic functionality tests
%   2. File format parsing tests
%   3. Data merging tests
%   4. Error handling tests
%   5. Integration tests
%   6. Edge case tests

    % Parse input arguments
    p = inputParser;
    addParameter(p, 'verbose', true, @islogical);
    addParameter(p, 'test_all', true, @islogical);
    addParameter(p, 'create_fixtures', false, @islogical);

    parse(p, varargin{:});

    verbose = p.Results.verbose;
    test_all = p.Results.test_all;
    create_fixtures = p.Results.create_fixtures;

    % Set up test environment
    test_dir = fileparts(mfilename('fullpath'));
    fixtures_dir = fullfile(test_dir, 'fixtures', 'pdk_converter');
    output_dir = fullfile(test_dir, 'test_output', 'pdk_converter');

    if create_fixtures
        create_test_fixtures(fixtures_dir, verbose);
        return;
    end

    % Ensure output directory exists
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % Initialize test results
    test_results = struct();
    test_results.total = 0;
    test_results.passed = 0;
    test_results.failed = 0;
    test_results.errors = {};

    fprintf('=== PDK Converter Test Suite ===\n');
    fprintf('Test directory: %s\n', test_dir);
    fprintf('Output directory: %s\n', output_dir);
    fprintf('===============================\n\n');

    % Run test categories
    try
        % Test 1: Basic LYP/LYT conversion
        test_results = run_test(test_results, 'Basic LYP/LYT Conversion', @test_basic_lyp_lyt_conversion, ...
                               fixtures_dir, output_dir, verbose);

        % Test 2: Universal PDK conversion
        test_results = run_test(test_results, 'Universal PDK Conversion', @test_universal_pdk_conversion, ...
                               fixtures_dir, output_dir, verbose);

        % Test 3: LEF file parsing
        test_results = run_test(test_results, 'LEF File Parsing', @test_lef_parsing, ...
                               fixtures_dir, output_dir, verbose);

        % Test 4: MAP file parsing
        test_results = run_test(test_results, 'MAP File Parsing', @test_map_parsing, ...
                               fixtures_dir, output_dir, verbose);

        % Test 5: CSV file parsing
        test_results = run_test(test_results, 'CSV File Parsing', @test_csv_parsing, ...
                               fixtures_dir, output_dir, verbose);

        % Test 6: Cross-section script parsing
        test_results = run_test(test_results, 'Cross-Section Script Parsing', @test_xs_parsing, ...
                               fixtures_dir, output_dir, verbose);

        % Test 7: Data merging and validation
        test_results = run_test(test_results, 'Data Merging and Validation', @test_data_merging, ...
                               fixtures_dir, output_dir, verbose);

        % Test 8: Error handling
        test_results = run_test(test_results, 'Error Handling', @test_error_handling, ...
                               fixtures_dir, output_dir, verbose);

        % Test 9: Integration with existing workflow
        test_results = run_test(test_results, 'Workflow Integration', @test_workflow_integration, ...
                               fixtures_dir, output_dir, verbose);

        if test_all
            % Test 10: Edge cases and boundary conditions
            test_results = run_test(test_results, 'Edge Cases', @test_edge_cases, ...
                                   fixtures_dir, output_dir, verbose);
        end

    catch ME
        fprintf('TEST SUITE ERROR: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
        return;
    end

    % Display final results
    fprintf('\n=== Test Results Summary ===\n');
    fprintf('Total tests:  %d\n', test_results.total);
    fprintf('Passed:       %d (%.1f%%)\n', test_results.passed, ...
            100*test_results.passed/test_results.total);
    fprintf('Failed:       %d (%.1f%%)\n', test_results.failed, ...
            100*test_results.failed/test_results.total);

    if ~isempty(test_results.errors)
        fprintf('\nFailed tests:\n');
        for i = 1:length(test_results.errors)
            fprintf('  %d. %s: %s\n', i, test_results.errors{i}.test_name, test_results.errors{i}.message);
        end
    end

    if test_results.failed == 0
        fprintf('\n✓ ALL TESTS PASSED!\n');
    else
        fprintf('\n✗ SOME TESTS FAILED!\n');
    end
    fprintf('============================\n');
end

function test_results = run_test(test_results, test_name, test_function, fixtures_dir, output_dir, verbose)
% run_test: Run individual test and update results

    test_results.total = test_results.total + 1;

    if verbose
        fprintf('Running: %s\n', test_name);
    end

    try
        % Run the test function
        test_function(fixtures_dir, output_dir, verbose);

        test_results.passed = test_results.passed + 1;

        if verbose
            fprintf('  ✓ PASSED\n');
        end

    catch ME
        test_results.failed = test_results.failed + 1;
        error_info = struct();
        error_info.test_name = test_name;
        error_info.message = ME.message;
        test_results.errors{end+1} = error_info;

        if verbose
            fprintf('  ✗ FAILED: %s\n', ME.message);
        end
    end

    if verbose
        fprintf('\n');
    end
end

function create_test_fixtures(fixtures_dir, verbose)
% create_test_fixtures: Create test fixture files for various PDK formats

    if verbose
        fprintf('Creating test fixture files in: %s\n', fixtures_dir);
    end

    % Create directory if it doesn't exist
    if ~exist(fixtures_dir, 'dir')
        mkdir(fixtures_dir);
    end

    % Create test LYP file (simplified XML format)
    lyp_content = sprintf([...
        '<?xml version="1.0" encoding="utf-8"?>\n' ...
        '<layer-properties>\n' ...
        '  <properties>\n' ...
        '    <name>Metal1</name>\n' ...
        '    <source>@8@0</source>\n' ...
        '    <frame-color>#39BFFF</frame-color>\n' ...
        '    <fill-color>#39BFFF</fill-color>\n' ...
        '    <visible>true</visible>\n' ...
        '  </properties>\n' ...
        '  <properties>\n' ...
        '    <name>Metal2</name>\n' ...
        '    <source>@10@0</source>\n' ...
        '    <frame-color>#CCCCD9</frame-color>\n' ...
        '    <fill-color>#CCCCD9</fill-color>\n' ...
        '    <visible>true</visible>\n' ...
        '  </properties>\n' ...
        '</layer-properties>\n']);

    write_text_file(fullfile(fixtures_dir, 'test.lyp'), lyp_content, verbose);

    % Create test LYT file (simplified format)
    lyt_content = sprintf([...
        '# Test layer technology file\n' ...
        '# Thickness values in micrometers\n' ...
        't_metal1 = 0.5\n' ...
        't_metal2 = 0.5\n' ...
        'z_metal1_bottom = 0.8\n' ...
        'z_metal1_top = 1.3\n' ...
        'z_metal2_bottom = 1.8\n' ...
        'z_metal2_top = 2.3\n']);

    write_text_file(fullfile(fixtures_dir, 'test.lyt'), lyt_content, verbose);

    % Create test LEF file
    lef_content = sprintf([...
        'VERSION 5.7 ;\n' ...
        'NAMESCASESENSITIVE ON ;\n' ...
        'UNITS DISTANCE MICRONS 1000 ;\n' ...
        '\n' ...
        'LAYER Metal1\n' ...
        '  TYPE ROUTING ;\n' ...
        '  DIRECTION HORIZONTAL ;\n' ...
        '  PITCH 0.14 ;\n' ...
        '  WIDTH 0.06 ;\n' ...
        '  THICKNESS 0.5 ;\n' ...
        'END Metal1\n' ...
        '\n' ...
        'LAYER Metal2\n' ...
        '  TYPE ROUTING ;\n' ...
        '  DIRECTION VERTICAL ;\n' ...
        '  PITCH 0.14 ;\n' ...
        '  WIDTH 0.06 ;\n' ...
        '  THICKNESS 0.5 ;\n' ...
        'END Metal2\n' ...
        '\n' ...
        'LAYER Via1\n' ...
        '  TYPE CUT ;\n' ...
        '  SPACING 0.08 ;\n' ...
        'END Via1\n']);

    write_text_file(fullfile(fixtures_dir, 'test.lef'), lef_content, verbose);

    % Create test MAP file
    map_content = sprintf([...
        '# Test GDSII layer mapping\n' ...
        '# Format: GDS_LAYER GDS_DATATYPE LAYER_NAME\n' ...
        '8   0   Metal1\n' ...
        '10  0   Metal2\n' ...
        '19  0   Via1\n']);

    write_text_file(fullfile(fixtures_dir, 'test.map'), map_content, verbose);

    % Create test CSV file
    csv_content = sprintf([...
        'layer_name,gds_layer,gds_datatype,thickness,z_bottom,z_top,material\n' ...
        'Metal1,8,0,0.5,0.8,1.3,Aluminum\n' ...
        'Metal2,10,0,0.5,1.8,2.3,Aluminum\n' ...
        'Via1,19,0,0.5,1.3,1.8,Tungsten\n']);

    write_text_file(fullfile(fixtures_dir, 'test.csv'), csv_content, verbose);

    % Create test cross-section script
    xs_content = sprintf([...
        '# Test cross-section script\n' ...
        '# Layer thickness definitions\n' ...
        '$t_metal1 = 0.5\n' ...
        '$t_metal2 = 0.5\n' ...
        '$t_via1 = 0.5\n' ...
        '\n' ...
        '# Z-height definitions\n' ...
        '$z_metal1_bottom = 0.8\n' ...
        '$z_metal1_top = 1.3\n' ...
        '$z_metal2_bottom = 1.8\n' ...
        '$z_metal2_top = 2.3\n' ...
        '$z_via1_bottom = 1.3\n' ...
        '$z_via1_top = 1.8\n']);

    write_text_file(fullfile(fixtures_dir, 'test.xs'), xs_content, verbose);

    % Create test generic tech file
    tech_content = sprintf([...
        '# Test generic technology file\n' ...
        '# Format: LAYER_NAME GDS_LAYER GDS_DATATYPE [properties]\n' ...
        'Metal1 8 0 thickness=0.5 z_bottom=0.8 material=Aluminum\n' ...
        'Metal2 10 0 thickness=0.5 z_bottom=1.8 material=Aluminum\n' ...
        'Via1 19 0 thickness=0.5 z_bottom=1.3 material=Tungsten\n']);

    write_text_file(fullfile(fixtures_dir, 'test.tech'), tech_content, verbose);

    if verbose
        fprintf('✓ Test fixture files created successfully\n');
    end
end

function write_text_file(file_path, content, verbose)
% write_text_file: Helper function to write text files

    fid = fopen(file_path, 'w', 'n', 'UTF-8');
    if fid == -1
        error('Cannot create file: %s', file_path);
    end

    fprintf(fid, '%s', content);
    fclose(fid);

    if verbose
        fprintf('  Created: %s\n', file_path);
    end
end

% =========================================================================
% INDIVIDUAL TEST FUNCTIONS
% =========================================================================

function test_basic_lyp_lyt_conversion(fixtures_dir, output_dir, verbose)
% test_basic_lyp_lyt_conversion: Test basic LYP/LYT to config conversion

    lyp_file = fullfile(fixtures_dir, 'test.lyp');
    lyt_file = fullfile(fixtures_dir, 'test.lyt');
    output_file = fullfile(output_dir, 'basic_lyp_lyt_output.json');

    % Convert LYP and LYT files
    config = gds_convert_lyp_lyt_to_config(lyp_file, lyt_file, ...
                                          'output_file', output_file, ...
                                          'project_name', 'Test Process', ...
                                          'verbose', verbose);

    % Validate basic structure
    assert(isstruct(config), 'Output should be a struct');
    assert(isfield(config, 'metadata'), 'Config should have metadata');
    assert(isfield(config, 'layers'), 'Config should have layers');
    assert(isfield(config, 'conversion_options'), 'Config should have conversion options');

    % Validate metadata
    assert(strcmp(config.metadata.project, 'Test Process'), 'Project name mismatch');
    assert(strcmp(config.metadata.units, 'micrometers'), 'Default units should be micrometers');

    % Validate layers
    assert(length(config.layers) >= 2, 'Should have at least 2 layers');

    % Check Metal1 layer
    metal1_found = false;
    for i = 1:length(config.layers)
        if strcmp(config.layers(i).name, 'Metal1')
            metal1_found = true;
            assert(config.layers(i).gds_layer == 8, 'Metal1 should be GDS layer 8');
            assert(config.layers(i).gds_datatype == 0, 'Metal1 should be datatype 0');
            assert(abs(config.layers(i).thickness - 0.5) < 1e-6, 'Metal1 thickness should be 0.5');
            assert(abs(config.layers(i).z_bottom - 0.8) < 1e-6, 'Metal1 z_bottom should be 0.8');
            assert(abs(config.layers(i).z_top - 1.3) < 1e-6, 'Metal1 z_top should be 1.3');
            break;
        end
    end
    assert(metal1_found, 'Metal1 layer should be found');

    % Check that output file was created
    assert(exist(output_file, 'file'), 'Output JSON file should be created');

    % Validate that output file can be read by gds_read_layer_config
    loaded_config = gds_read_layer_config(output_file);
    assert(isstruct(loaded_config), 'Loaded config should be a struct');
    assert(length(loaded_config.layers) >= 2, 'Loaded config should have layers');
end

function test_universal_pdk_conversion(fixtures_dir, output_dir, verbose)
% test_universal_pdk_conversion: Test universal PDK converter

    output_file = fullfile(output_dir, 'universal_pdk_output.json');

    % Test with multiple input files
    config = gds_convert_pdk_to_config('lyp_file', fullfile(fixtures_dir, 'test.lyp'), ...
                                      'lyt_file', fullfile(fixtures_dir, 'test.lyt'), ...
                                      'lef_file', fullfile(fixtures_dir, 'test.lef'), ...
                                      'map_file', fullfile(fixtures_dir, 'test.map'), ...
                                      'output_file', output_file, ...
                                      'project_name', 'Universal Test', ...
                                      'verbose', verbose);

    % Validate structure
    assert(isstruct(config), 'Output should be a struct');
    assert(isfield(config, 'metadata'), 'Config should have metadata');
    assert(isfield(config, 'layers'), 'Config should have layers');

    % Validate layers
    assert(length(config.layers) >= 3, 'Should have at least 3 layers from multiple sources');

    % Check that layers from different sources are merged correctly
    layer_names = {config.layers.name};
    assert(ismember('Metal1', layer_names), 'Metal1 should be present');
    assert(ismember('Metal2', layer_names), 'Metal2 should be present');
    assert(ismember('Via1', layer_names), 'Via1 should be present');

    % Validate output file
    assert(exist(output_file, 'file'), 'Output JSON file should be created');
end

function test_lef_parsing(fixtures_dir, output_dir, verbose)
% test_lef_parsing: Test LEF file parsing

    lef_file = fullfile(fixtures_dir, 'test.lef');
    output_file = fullfile(output_dir, 'lef_output.json');

    % Convert LEF file only
    config = gds_convert_pdk_to_config('lef_file', lef_file, ...
                                      'output_file', output_file, ...
                                      'project_name', 'LEF Test', ...
                                      'verbose', verbose);

    % Validate LEF-specific parsing
    assert(length(config.layers) >= 2, 'Should have at least 2 layers from LEF');

    % Check for routing layers
    routing_layers = 0;
    for i = 1:length(config.layers)
        if isfield(config.layers(i), 'properties') && isfield(config.layers(i).properties, 'type')
            if strcmp(config.layers(i).properties.type, 'routing')
                routing_layers = routing_layers + 1;
            end
        end
    end
    assert(routing_layers >= 2, 'Should have at least 2 routing layers');
end

function test_map_parsing(fixtures_dir, output_dir, verbose)
% test_map_parsing: Test MAP file parsing

    map_file = fullfile(fixtures_dir, 'test.map');
    output_file = fullfile(output_dir, 'map_output.json');

    % Convert MAP file only
    config = gds_convert_pdk_to_config('map_file', map_file, ...
                                      'output_file', output_file, ...
                                      'project_name', 'MAP Test', ...
                                      'verbose', verbose);

    % Validate MAP-specific parsing
    assert(length(config.layers) >= 3, 'Should have at least 3 layers from MAP');

    % Check GDSII layer numbers
    gds_layers = [config.layers.gds_layer];
    assert(ismember(8, gds_layers), 'Should have GDS layer 8 (Metal1)');
    assert(ismember(10, gds_layers), 'Should have GDS layer 10 (Metal2)');
    assert(ismember(19, gds_layers), 'Should have GDS layer 19 (Via1)');

    % Check datatypes
    gds_datatypes = [config.layers.gds_datatype];
    assert(all(gds_datatypes == 0), 'All datatypes should be 0');
end

function test_csv_parsing(fixtures_dir, output_dir, verbose)
% test_csv_parsing: Test CSV file parsing

    csv_file = fullfile(fixtures_dir, 'test.csv');
    output_file = fullfile(output_dir, 'csv_output.json');

    % Convert CSV file only
    config = gds_convert_pdk_to_config('csv_file', csv_file, ...
                                      'output_file', output_file, ...
                                      'project_name', 'CSV Test', ...
                                      'verbose', verbose);

    % Validate CSV-specific parsing
    assert(length(config.layers) >= 3, 'Should have at least 3 layers from CSV');

    % Check material assignments
    materials = {config.layers.material};
    assert(ismember('Aluminum', materials), 'Should have Aluminum layers');
    assert(ismember('Tungsten', materials), 'Should have Tungsten layers');

    % Check thickness values
    for i = 1:length(config.layers)
        assert(isfield(config.layers(i), 'thickness'), 'All layers should have thickness');
        assert(config.layers(i).thickness > 0, 'Thickness should be positive');
    end
end

function test_xs_parsing(fixtures_dir, output_dir, verbose)
% test_xs_parsing: Test cross-section script parsing

    xs_file = fullfile(fixtures_dir, 'test.xs');
    output_file = fullfile(output_dir, 'xs_output.json');

    % Convert XS file with MAP for layer names
    config = gds_convert_pdk_to_config('xs_file', xs_file, ...
                                      'map_file', fullfile(fixtures_dir, 'test.map'), ...
                                      'output_file', output_file, ...
                                      'project_name', 'XS Test', ...
                                      'verbose', verbose);

    % Validate XS-specific parsing
    assert(length(config.layers) >= 3, 'Should have at least 3 layers');

    % Check z-height assignments
    for i = 1:length(config.layers)
        assert(isfield(config.layers(i), 'z_bottom'), 'All layers should have z_bottom');
        assert(isfield(config.layers(i), 'z_top'), 'All layers should have z_top');
        assert(config.layers(i).z_top > config.layers(i).z_bottom, 'z_top should be greater than z_bottom');
    end
end

function test_data_merging(fixtures_dir, output_dir, verbose)
% test_data_merging: Test data merging from multiple sources

    output_file = fullfile(output_dir, 'merge_output.json');

    % Convert with all possible sources
    config = gds_convert_pdk_to_config('lyp_file', fullfile(fixtures_dir, 'test.lyp'), ...
                                      'lyt_file', fullfile(fixtures_dir, 'test.lyt'), ...
                                      'lef_file', fullfile(fixtures_dir, 'test.lef'), ...
                                      'map_file', fullfile(fixtures_dir, 'test.map'), ...
                                      'csv_file', fullfile(fixtures_dir, 'test.csv'), ...
                                      'xs_file', fullfile(fixtures_dir, 'test.xs'), ...
                                      'output_file', output_file, ...
                                      'project_name', 'Merge Test', ...
                                      'verbose', verbose);

    % Validate comprehensive merging
    assert(length(config.layers) >= 3, 'Should have layers from merged sources');

    % Check that no duplicate layers exist
    layer_names = {config.layers.name};
    [unique_names, ~, ic] = unique(layer_names);
    assert(length(unique_names) == length(layer_names), 'No duplicate layer names should exist');

    % Check that all layers have complete information
    for i = 1:length(config.layers)
        layer = config.layers(i);
        assert(isfield(layer, 'gds_layer') && ~isnan(layer.gds_layer), 'Layer should have GDS layer number');
        assert(isfield(layer, 'gds_datatype') && ~isnan(layer.gds_datatype), 'Layer should have datatype');
        assert(isfield(layer, 'name') && ~isempty(layer.name), 'Layer should have name');
        assert(isfield(layer, 'thickness') && layer.thickness > 0, 'Layer should have positive thickness');
        assert(isfield(layer, 'z_bottom'), 'Layer should have z_bottom');
        assert(isfield(layer, 'z_top'), 'Layer should have z_top');
        assert(isfield(layer, 'material') && ~isempty(layer.material), 'Layer should have material');
    end

    % Check thickness consistency
    for i = 1:length(config.layers)
        layer = config.layers(i);
        computed_thickness = layer.z_top - layer.z_bottom;
        assert(abs(computed_thickness - layer.thickness) < 1e-6, ...
               'Thickness should be consistent with z-heights for layer %s', layer.name);
    end
end

function test_error_handling(fixtures_dir, output_dir, verbose)
% test_error_handling: Test error handling for various edge cases

    % Test with non-existent file
    try
        gds_convert_pdk_to_config('lyp_file', 'nonexistent.lyp', 'verbose', false);
        error('Should have thrown an error for non-existent file');
    catch ME
        assert(contains(ME.identifier, 'FileNotFound'), 'Should be file not found error');
    end

    % Test with empty input
    try
        gds_convert_pdk_to_config('verbose', false);
        error('Should have thrown an error for no input files');
    catch ME
        assert(contains(ME.identifier, 'NoInputFiles'), 'Should be no input files error');
    end

    % Test with invalid CSV
    invalid_csv = fullfile(fixtures_dir, 'invalid.csv');
    write_text_file(invalid_csv, 'invalid,csv,format', false);

    try
        config = gds_convert_pdk_to_config('csv_file', invalid_csv, ...
                                          'verbose', false);
        % Should not crash, but may produce empty layers
        assert(isstruct(config), 'Should still produce a config struct');
    catch ME
        % If it throws an error, it should be a parsing error
        assert(contains(ME.identifier, 'ParseError'), 'Should be parse error');
    end

    % Test with mixed valid/invalid files
    config = gds_convert_pdk_to_config('map_file', fullfile(fixtures_dir, 'test.map'), ...
                                      'csv_file', invalid_csv, ...
                                      'verbose', false);
    assert(isstruct(config), 'Should produce config despite invalid file');
    assert(length(config.layers) >= 3, 'Should have layers from valid file');
end

function test_workflow_integration(fixtures_dir, output_dir, verbose)
% test_workflow_integration: Test integration with existing GDS workflow

    output_file = fullfile(output_dir, 'integration_output.json');

    % Generate configuration
    config = gds_convert_pdk_to_config('lyp_file', fullfile(fixtures_dir, 'test.lyp'), ...
                                      'lyt_file', fullfile(fixtures_dir, 'test.lyt'), ...
                                      'output_file', output_file, ...
                                      'project_name', 'Integration Test', ...
                                      'verbose', verbose);

    % Test that the output can be loaded by gds_read_layer_config
    loaded_config = gds_read_layer_config(output_file);
    assert(isstruct(loaded_config), 'Should be loadable by gds_read_layer_config');

    % Test that the loaded config has required fields
    assert(isfield(loaded_config, 'metadata'), 'Should have metadata');
    assert(isfield(loaded_config, 'layers'), 'Should have layers');
    assert(isfield(loaded_config, 'conversion_options'), 'Should have conversion options');
    assert(isfield(loaded_config, 'layer_map'), 'Should have layer map');

    % Test layer map functionality
    assert(size(loaded_config.layer_map, 1) == 256, 'Layer map should have 256 rows');
    assert(size(loaded_config.layer_map, 2) == 256, 'Layer map should have 256 columns');

    % Test layer lookup
    metal1_idx = loaded_config.layer_map(8+1, 0+1);  % Metal1 is layer 8, datatype 0
    assert(metal1_idx > 0, 'Metal1 should be found in layer map');
    assert(metal1_idx <= length(loaded_config.layers), 'Metal1 index should be valid');

    metal1_layer = loaded_config.layers(metal1_idx);
    assert(strcmp(metal1_layer.name, 'Metal1'), 'Should find correct Metal1 layer');
end

function test_edge_cases(fixtures_dir, output_dir, verbose)
% test_edge_cases: Test edge cases and boundary conditions

    % Test with minimal input
    minimal_map = fullfile(fixtures_dir, 'minimal.map');
    write_text_file(minimal_map, '1 0 TestLayer\n', false);

    output_file = fullfile(output_dir, 'minimal_output.json');
    config = gds_convert_pdk_to_config('map_file', minimal_map, ...
                                      'output_file', output_file, ...
                                      'verbose', false);

    assert(length(config.layers) == 1, 'Should have exactly 1 layer');
    assert(strcmp(config.layers(1).name, 'TestLayer'), 'Layer name should match');
    assert(config.layers(1).gds_layer == 1, 'GDS layer should be 1');
    assert(config.layers(1).gds_datatype == 0, 'GDS datatype should be 0');

    % Test with large layer numbers
    large_map = fullfile(fixtures_dir, 'large.map');
    write_text_file(sprintf('255 255 HighLayer\n'), false);

    config = gds_convert_pdk_to_config('map_file', large_map, ...
                                      'verbose', false);

    assert(length(config.layers) == 1, 'Should have exactly 1 layer');
    assert(config.layers(1).gds_layer == 255, 'GDS layer should be 255');
    assert(config.layers(1).gds_datatype == 255, 'GDS datatype should be 255');

    % Test with special characters in layer names
    special_map = fullfile(fixtures_dir, 'special.map');
    write_text_file('10 0 Metal-1_Special\n', false);

    config = gds_convert_pdk_to_config('map_file', special_map, ...
                                      'verbose', false);

    assert(length(config.layers) == 1, 'Should have exactly 1 layer');
    assert(contains(config.layers(1).name, 'Metal-1_Special'), 'Should preserve special characters');

    % Test with empty files
    empty_file = fullfile(fixtures_dir, 'empty.txt');
    write_text_file('', false);

    try
        config = gds_convert_pdk_to_config('map_file', empty_file, ...
                                          'verbose', false);
        % Should handle empty file gracefully
        assert(isstruct(config), 'Should still produce a config struct');
    catch
        % Empty file may cause error, which is acceptable
    end
end