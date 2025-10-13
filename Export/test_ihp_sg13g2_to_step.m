function test_ihp_sg13g2_to_step(varargin)
% TEST_IHP_SG13G2_TO_STEP - Standalone test for IHP SG13G2 PDK GDS to STEP conversion
%
% This function provides a complete, self-contained test that converts IHP SG13G2
% GDS files to STEP format using the new fixture structure. It works independently
% and creates all necessary directories and outputs.
%
% USAGE:
%   test_ihp_sg13g2_to_step()                           % Use default settings
%   test_ihp_sg13g2_to_step('config', 'accurate')       % Use LEF-based accurate config
%   test_ihp_sg13g2_to_step('output', '/path/to/dir')   % Custom output directory
%   test_ihp_sg13g2_to_step('verbose', true)           % Verbose output
%
% PARAMETERS:
%   config - 'standard' or 'accurate' (default: 'accurate')
%   output - Output directory for STEP files (default: auto-generated)
%   verbose - Enable detailed output (default: true)
%
% OUTPUT:
%   Creates STEP files in the output directory with detailed conversion report
%
% EXAMPLE:
%   % Convert all available GDS files to STEP
%   test_ihp_sg13g2_to_step();
%
%   % Convert with specific configuration
%   test_ihp_sg13g2_to_step('config', 'accurate', 'verbose', true);
%
% Author: WARP AI Agent, October 2025
% Standalone IHP SG13G2 GDS-to-STEP conversion test

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════╗\n');
    fprintf('║     IHP SG13G2 GDS to STEP Conversion Test           ║\n');
    fprintf('╚════════════════════════════════════════════════════════╝\n');
    fprintf('\n');

    % Parse input parameters
    p = inputParser;
    addParameter(p, 'config', 'accurate', @(x) ismember(x, {'standard', 'accurate', 'from_pdk'}));
    addParameter(p, 'output', '', @ischar);
    addParameter(p, 'verbose', true, @islogical);
    parse(p, varargin{:});

    config_type = p.Results.config;
    custom_output = p.Results.output;
    verbose = p.Results.verbose;

    % Setup paths
    [script_dir, export_dir, toolbox_root] = setup_paths(verbose);
    [config_file, pdk_dirs, output_dir] = setup_directories(script_dir, config_type, custom_output, verbose);

    % Add required paths
    add_required_paths(export_dir, toolbox_root);

    % Load configuration
    cfg = load_configuration(config_file, verbose);
    if isempty(cfg)
        return;
    end

    % Find and process GDS files
    gds_files = find_gds_files(pdk_dirs, verbose);

    if isempty(gds_files)
        fprintf('⚠️  No GDS files found in PDK test directories.\n');
        fprintf('\nTo add test files:\n');
        fprintf('1. Copy GDS files from IHP-Open-PDK to these directories:\n');
        for i = 1:length(pdk_dirs)
            fprintf('   %s\n', pdk_dirs{i});
        end
        fprintf('2. Run this test again.\n\n');
        return;
    end

    % Process all GDS files
    results = process_gds_files(gds_files, cfg, output_dir, verbose);

    % Generate summary report
    generate_summary_report(results, config_type, output_dir);
end

%% Helper Functions

function [script_dir, export_dir, toolbox_root] = setup_paths(verbose)
    % Setup standard directory paths

    script_dir = fileparts(mfilename('fullpath'));
    export_dir = script_dir;
    toolbox_root = fileparts(export_dir);

    if verbose
        fprintf('Path Setup:\n');
        fprintf('  Script directory: %s\n', script_dir);
        fprintf('  Export directory: %s\n', export_dir);
        fprintf('  Toolbox root: %s\n', toolbox_root);
        fprintf('\n');
    end
end

function [config_file, pdk_dirs, output_dir] = setup_directories(script_dir, config_type, custom_output, verbose)
    % Setup all necessary directories

    % Configuration file
    if strcmp(config_type, 'from_pdk')
        config_file = fullfile(script_dir, 'new_tests', 'fixtures', 'ihp_sg13g2', ...
                              'layer_config_ihp_sg13g2_from_pdk.json');
    elseif strcmp(config_type, 'accurate')
        config_file = fullfile(script_dir, 'new_tests', 'fixtures', 'ihp_sg13g2', ...
                              'layer_config_ihp_sg13g2_accurate.json');
    else
        config_file = fullfile(script_dir, 'new_tests', 'fixtures', 'ihp_sg13g2', ...
                              'layer_config_ihp_sg13g2.json');
    end

    % PDK test directories
    base_fixture_dir = fullfile(script_dir, 'new_tests', 'fixtures', 'ihp_sg13g2', 'pdk_test_sets');
    pdk_dirs = {
        fullfile(base_fixture_dir, 'basic'),
        fullfile(base_fixture_dir, 'intermediate'),
        fullfile(base_fixture_dir, 'complex'),
        fullfile(base_fixture_dir, 'comprehensive')
    };

    % Output directory
    if isempty(custom_output)
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        output_dir = fullfile(script_dir, 'test_output_ihp_step', sprintf('conversion_%s', timestamp));
    else
        output_dir = custom_output;
    end

    % Create output directory
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    fprintf('Directory Setup:\n');
    fprintf('  Configuration: %s\n', config_file);
    fprintf('  Output: %s\n', output_dir);
    fprintf('\n');
end

function add_required_paths(export_dir, toolbox_root)
    % Add necessary paths to MATLAB/Octave environment

    paths_to_add = {
        export_dir,
        fullfile(toolbox_root, 'Basic'),
        fullfile(toolbox_root, 'Elements'),
        fullfile(toolbox_root, 'Structures'),
        fullfile(toolbox_root, 'Boolean')
    };

    for i = 1:length(paths_to_add)
        if exist(paths_to_add{i}, 'dir') && isempty(strfind(path, paths_to_add{i}))
            addpath(paths_to_add{i});
        end
    end
end

function cfg = load_configuration(config_file, verbose)
    % Load layer configuration file

    if ~exist(config_file, 'file')
        fprintf('✗ Configuration file not found: %s\n', config_file);
        cfg = [];
        return;
    end

    try
        cfg = gds_read_layer_config(config_file);
        if verbose
            fprintf('Configuration loaded successfully:\n');
            fprintf('  File: %s\n', config_file);
            fprintf('  Layers: %d\n', length(cfg.layers));
            fprintf('\n');
        end
    catch ME
        fprintf('✗ Failed to load configuration: %s\n', ME.message);
        cfg = [];
        return;
    end
end

function gds_files = find_gds_files(pdk_dirs, verbose)
    % Find all GDS files in PDK test directories

    gds_files = {};

    for i = 1:length(pdk_dirs)
        if exist(pdk_dirs{i}, 'dir')
            files = dir(fullfile(pdk_dirs{i}, '*.gds'));
            for j = 1:length(files)
                gds_files{end+1} = fullfile(pdk_dirs{i}, files(j).name);
            end
        end
    end

    if verbose && ~isempty(gds_files)
        fprintf('Found %d GDS files:\n', length(gds_files));
        for i = 1:length(gds_files)
            [~, name, ~] = fileparts(gds_files{i});
            fprintf('  %d. %s\n', i, name);
        end
        fprintf('\n');
    end
end

function results = process_gds_files(gds_files, cfg, output_dir, verbose)
    % Process all GDS files and convert to STEP

    results = struct();
    results.total_files = length(gds_files);
    results.processed = 0;
    results.failed = 0;
    results.file_results = {};
    results.total_time = 0;

    fprintf('Processing %d GDS files...\n', length(gds_files));
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

    start_time = tic;

    for i = 1:length(gds_files)
        file_result = process_single_gds(gds_files{i}, cfg, output_dir, verbose, i);
        results.file_results{end+1} = file_result;

        if file_result.success
            results.processed = results.processed + 1;
        else
            results.failed = results.failed + 1;
        end
    end

    results.total_time = toc(start_time);

    if verbose
        fprintf('\nProcessing completed in %.2f seconds\n', results.total_time);
    end
end

function file_result = process_single_gds(gds_file, cfg, output_dir, verbose, file_num)
    % Process a single GDS file

    [~, filename, ~] = fileparts(gds_file);
    file_result = struct();
    file_result.filename = filename;
    file_result.gds_file = gds_file;
    file_result.success = false;
    file_result.error = '';
    file_result.timing = struct();
    file_result.output_files = {};

    if verbose
        fprintf('[%d/%d] Processing: %s\n', file_num, length(gds_files), filename);
    end

    try
        % Load GDS
        tic;
        gds_lib = read_gds_library(gds_file);
        file_result.timing.load_time = toc;

        if verbose
            fprintf('  ✓ Load GDS: %.3f sec, %d structures\n', ...
                    file_result.timing.load_time, length(gds_lib.structures));
        end

        % Extract layers
        tic;
        layer_data = gds_layer_to_3d(gds_lib, cfg);
        file_result.timing.extract_time = toc;

        % Count active layers and polygons
        active_layers = 0;
        total_polygons = 0;
        for k = 1:length(layer_data.layers)
            L = layer_data.layers(k);
            if L.num_polygons > 0
                active_layers = active_layers + 1;
                total_polygons = total_polygons + L.num_polygons;
            end
        end

        file_result.active_layers = active_layers;
        file_result.total_polygons = total_polygons;

        if verbose
            fprintf('  ✓ Extract layers: %.3f sec, %d active, %d polygons\n', ...
                    file_result.timing.extract_time, active_layers, total_polygons);
        end

        % Convert to STEP
        step_file = fullfile(output_dir, [filename '.step']);
        tic;
        gds_to_step(gds_lib, step_file, cfg);
        file_result.timing.step_time = toc;

        % Verify output
        if exist(step_file, 'file')
            step_info = dir(step_file);
            file_result.output_files{end+1} = step_file;
            file_result.step_size = step_info.bytes;

            if verbose
                fprintf('  ✓ Export STEP: %.3f sec, %.2f KB\n', ...
                        file_result.timing.step_time, step_info.bytes/1024);
            end

            % Also create STL for comparison
            stl_file = fullfile(output_dir, [filename '.stl']);
            gds_to_stl(gds_lib, stl_file, cfg);

            if exist(stl_file, 'file')
                stl_info = dir(stl_file);
                file_result.output_files{end+1} = stl_file;
                file_result.stl_size = stl_info.bytes;

                if verbose
                    fprintf('  ✓ Export STL: %.2f KB\n', stl_info.bytes/1024);
                end
            end

            file_result.success = true;

            if verbose
                total_time = file_result.timing.load_time + file_result.timing.extract_time + file_result.timing.step_time;
                fprintf('  ✅ SUCCESS (%.3f sec total)\n\n', total_time);
            end
        else
            file_result.error = 'STEP file was not created';
            if verbose
                fprintf('  ✗ FAILED: STEP file not created\n\n');
            end
        end

    catch ME
        file_result.error = ME.message;
        if verbose
            fprintf('  ✗ FAILED: %s\n\n', ME.message);
        end
    end
end

function generate_summary_report(results, config_type, output_dir)
    % Generate comprehensive summary report

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════╗\n');
    fprintf('║           CONVERSION SUMMARY REPORT                    ║\n');
    fprintf('╚════════════════════════════════════════════════════════╝\n');
    fprintf('\n');

    fprintf('Configuration: %s\n', config_type);
    fprintf('Output Directory: %s\n', output_dir);
    fprintf('Date: %s\n\n', datestr(now));

    fprintf('Overall Results:\n');
    fprintf('  Total files:     %d\n', results.total_files);
    fprintf('  Successfully converted: %d\n', results.processed);
    fprintf('  Failed:          %d\n', results.failed);

    if results.total_files > 0
        fprintf('  Success rate:    %.1f%%\n', 100 * results.processed / results.total_files);
        fprintf('  Total time:      %.2f seconds\n', results.total_time);
        fprintf('  Average time:    %.3f seconds per file\n', results.total_time / results.total_files);
    end

    fprintf('\n');

    % Detailed results
    fprintf('Detailed Results:\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    for i = 1:length(results.file_results)
        result = results.file_results{i};

        if result.success
            status = '✅ PASS';
            time_str = sprintf('%.3f sec', sum(struct2array(result.timing)));

            fprintf('  %-20s %s %8s', result.filename, status, time_str);
            if result.active_layers > 0
                fprintf('  %d layers, %d polys', result.active_layers, result.total_polygons);
            end
            fprintf('\n');
        else
            status = '❌ FAIL';
            fprintf('  %-20s %s %s\n', result.filename, status, result.error);
        end
    end

    fprintf('\n');

    % Statistics for successful conversions
    if results.processed > 0
        successful_results = results.file_results(cellfun(@(x) x.success, results.file_results));

        total_layers = sum(cellfun(@(x) x.active_layers, successful_results));
        total_polygons = sum(cellfun(@(x) x.total_polygons, successful_results));
        total_step_size = sum(cellfun(@(x) x.step_size, successful_results));
        total_stl_size = sum(cellfun(@(x) x.stl_size, successful_results));

        fprintf('Successful Conversion Statistics:\n');
        fprintf('  Total layers processed: %d\n', total_layers);
        fprintf('  Total polygons:         %d\n', total_polygons);
        fprintf('  Total STEP size:        %.2f KB\n', total_step_size/1024);
        fprintf('  Total STL size:         %.2f KB\n', total_stl_size/1024);
        fprintf('  Average layers/file:    %.1f\n', total_layers / results.processed);
        fprintf('  Average polygons/file:  %.1f\n', total_polygons / results.processed);
    end

    fprintf('\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    if results.failed == 0
        fprintf('                🎉 ALL CONVERSIONS SUCCEEDED!\n');
    else
        fprintf('                ⚠️  SOME CONVERSIONS FAILED\n');
    end

    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

    % Save report to file
    report_file = fullfile(output_dir, 'conversion_report.txt');
    save_report_to_file(results, config_type, output_dir, report_file);

    fprintf('📄 Detailed report saved to: %s\n', report_file);
end

function save_report_to_file(results, config_type, output_dir, report_file)
    % Save detailed report to text file

    fid = fopen(report_file, 'w');
    if fid == -1
        return;
    end

    fprintf(fid, 'IHP SG13G2 GDS to STEP Conversion Report\n');
    fprintf(fid, '=========================================\n\n');
    fprintf(fid, 'Configuration: %s\n', config_type);
    fprintf(fid, 'Output Directory: %s\n', output_dir);
    fprintf(fid, 'Date: %s\n\n', datestr(now));

    fprintf(fid, 'Overall Results:\n');
    fprintf(fid, '  Total files: %d\n', results.total_files);
    fprintf(fid, '  Successfully converted: %d\n', results.processed);
    fprintf(fid, '  Failed: %d\n', results.failed);
    fprintf(fid, '  Success rate: %.1f%%\n', 100 * results.processed / results.total_files);
    fprintf(fid, '  Total time: %.2f seconds\n\n', results.total_time);

    fprintf(fid, 'Detailed Results:\n');
    fprintf(fid, '-----------------\n');

    for i = 1:length(results.file_results)
        result = results.file_results{i};
        fprintf(fid, '\n%d. %s\n', i, result.filename);
        fprintf(fid, '   Status: %s\n', ternary(result.success, 'SUCCESS', 'FAILED'));

        if result.success
            fprintf(fid, '   Load time: %.3f sec\n', result.timing.load_time);
            fprintf(fid, '   Extract time: %.3f sec\n', result.timing.extract_time);
            fprintf(fid, '   STEP export time: %.3f sec\n', result.timing.step_time);
            fprintf(fid, '   Active layers: %d\n', result.active_layers);
            fprintf(fid, '   Total polygons: %d\n', result.total_polygons);
            fprintf(fid, '   STEP file size: %.2f KB\n', result.step_size/1024);

            if isfield(result, 'stl_size')
                fprintf(fid, '   STL file size: %.2f KB\n', result.stl_size/1024);
            end

            fprintf(fid, '   Output files:\n');
            for j = 1:length(result.output_files)
                [~, name, ext] = fileparts(result.output_files{j});
                fprintf(fid, '     - %s%s\n', name, ext);
            end
        else
            fprintf(fid, '   Error: %s\n', result.error);
        end
    end

    fclose(fid);
end

function result = ternary(condition, true_value, false_value)
    % Simple ternary operator
    if condition
        result = true_value;
    else
        result = false_value;
    end
end