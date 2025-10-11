function overall_results = run_tests(varargin)
% RUN_TESTS - Master test runner for essential GDS-STL-STEP test suite
%
% Executes all essential tests and provides comprehensive reporting.
%
% USAGE:
%   run_tests()                    % Run all essential tests
%   run_tests('verbose', true)     % Run with verbose output
%   run_tests('optional', true)    % Include optional tests (if available)
%
% RETURNS:
%   overall_results - Structure with complete test results
%
% Author: WARP AI Agent, October 2025
% Part of essential GDS-STL-STEP test suite

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════╗\n');
    fprintf('║      GDS-STL-STEP Essential Test Suite                ║\n');
    fprintf('╚════════════════════════════════════════════════════════╝\n');
    fprintf('\n');
    
    % Parse options
    opts = parse_options(varargin{:});
    
    % Essential tests (always run)
    essential_tests = {
        'test_config_system',
        'test_extrusion_core',
        'test_file_export',
        'test_layer_extraction',
        'test_basic_pipeline'
    };
    
    % Optional tests (run if requested)
    optional_tests = {
        'optional/test_pdk_basic',
        'optional/test_advanced_pipeline'
    };
    
    % Initialize overall results
    overall_results = struct();
    overall_results.test_suites = {};
    overall_results.total_tests = 0;
    overall_results.total_passed = 0;
    overall_results.total_failed = 0;
    overall_results.start_time = now;
    
    % Run essential tests
    fprintf('Running Essential Tests...\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    for i = 1:length(essential_tests)
        test_name = essential_tests{i};
        
        fprintf('[%d/%d] Running %s...\n', i, length(essential_tests), test_name);
        
        try
            % Execute test
            tic;
            test_func = str2func(test_name);
            results = test_func();
            elapsed = toc;
            
            % Store results
            suite_results = struct();
            suite_results.name = test_name;
            suite_results.results = results;
            suite_results.elapsed = elapsed;
            suite_results.status = 'COMPLETE';
            
            overall_results.test_suites{end+1} = suite_results;
            overall_results.total_tests = overall_results.total_tests + results.total;
            overall_results.total_passed = overall_results.total_passed + results.passed;
            overall_results.total_failed = overall_results.total_failed + results.failed;
            
            if results.failed == 0
                fprintf('  ✓ ALL PASSED (%d/%d tests, %.2f seconds)\n\n', ...
                        results.passed, results.total, elapsed);
            else
                fprintf('  ✗ SOME FAILED (%d/%d tests passed, %.2f seconds)\n\n', ...
                        results.passed, results.total, elapsed);
            end
            
        catch ME
            fprintf('  ✗ TEST SUITE FAILED: %s\n\n', ME.message);
            
            suite_results = struct();
            suite_results.name = test_name;
            suite_results.status = 'ERROR';
            suite_results.error = ME.message;
            overall_results.test_suites{end+1} = suite_results;
        end
    end
    
    % Run optional tests if requested
    if opts.optional
        fprintf('\n');
        fprintf('Running Optional Tests...\n');
        fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
        
        for i = 1:length(optional_tests)
            test_name = optional_tests{i};
            
            fprintf('[%d/%d] Running %s...\n', i, length(optional_tests), test_name);
            
            try
                % Execute test (add optional directory to path if needed)
                script_dir = fileparts(mfilename('fullpath'));
                optional_dir = fullfile(script_dir, 'optional');
                if isempty(strfind(path, optional_dir))
                    addpath(optional_dir);
                end
                
                tic;
                % Extract just the function name without directory
                [~, test_func_name, ~] = fileparts(test_name);
                test_func = str2func(test_func_name);
                results = test_func();
                elapsed = toc;
                
                % Store results
                suite_results = struct();
                suite_results.name = test_name;
                suite_results.results = results;
                suite_results.elapsed = elapsed;
                suite_results.status = 'COMPLETE';
                
                overall_results.test_suites{end+1} = suite_results;
                overall_results.total_tests = overall_results.total_tests + results.total;
                overall_results.total_passed = overall_results.total_passed + results.passed;
                overall_results.total_failed = overall_results.total_failed + results.failed;
                
                if results.failed == 0 && results.total > 0
                    fprintf('  ✓ ALL PASSED (%d/%d tests, %.2f seconds)\n\n', ...
                            results.passed, results.total, elapsed);
                elseif results.total == 0
                    fprintf('  ⚠️ SKIPPED (optional data not available)\n\n');
                else
                    fprintf('  ✗ SOME FAILED (%d/%d tests passed, %.2f seconds)\n\n', ...
                            results.passed, results.total, elapsed);
                end
                
            catch ME
                fprintf('  ✗ TEST SUITE FAILED: %s\n\n', ME.message);
                
                suite_results = struct();
                suite_results.name = test_name;
                suite_results.status = 'ERROR';
                suite_results.error = ME.message;
                overall_results.test_suites{end+1} = suite_results;
            end
        end
    end
    
    overall_results.end_time = now;
    overall_results.total_elapsed = (overall_results.end_time - overall_results.start_time) * 24 * 3600;
    
    % Print summary
    print_summary(overall_results, opts);
    
    % Return results
    if nargout == 0
        clear overall_results;
    end
end

%% Helper Functions

function opts = parse_options(varargin)
    % Parse optional parameters
    opts = struct();
    opts.verbose = true;
    opts.optional = false;
    
    for i = 1:2:length(varargin)
        if i+1 <= length(varargin)
            opts.(varargin{i}) = varargin{i+1};
        end
    end
end

function print_summary(overall_results, opts)
    % Print comprehensive test summary
    
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    if opts.optional
        fprintf('            TEST SUMMARY (with optional tests)\n');
    else
        fprintf('                    TEST SUMMARY\n');
    end
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    
    % Overall statistics
    fprintf('Overall Results:\n');
    fprintf('  Total test suites: %d\n', length(overall_results.test_suites));
    fprintf('  Total tests:       %d\n', overall_results.total_tests);
    fprintf('  Passed:            %d\n', overall_results.total_passed);
    fprintf('  Failed:            %d\n', overall_results.total_failed);
    fprintf('  Success rate:      %.1f%%\n', ...
            100 * overall_results.total_passed / overall_results.total_tests);
    fprintf('  Total time:        %.2f seconds\n', overall_results.total_elapsed);
    fprintf('\n');
    
    % Per-suite breakdown
    fprintf('Test Suite Breakdown:\n');
    for i = 1:length(overall_results.test_suites)
        suite = overall_results.test_suites{i};
        
        if strcmp(suite.status, 'COMPLETE')
            status_str = sprintf('%d/%d passed', ...
                                suite.results.passed, suite.results.total);
            if suite.results.failed == 0
                status_icon = '✓';
            else
                status_icon = '✗';
            end
        else
            status_str = 'ERROR';
            status_icon = '✗';
        end
        
        fprintf('  %s %-30s %s\n', status_icon, suite.name, status_str);
    end
    
    fprintf('\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    % Final verdict
    if overall_results.total_failed == 0
        fprintf('                ✓ ALL TESTS PASSED\n');
    else
        fprintf('                ✗ SOME TESTS FAILED\n');
    end
    
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
end
