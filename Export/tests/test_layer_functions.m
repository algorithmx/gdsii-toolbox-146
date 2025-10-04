% test_layer_functions.m
%
% Test script for gds_read_layer_config and gds_layer_to_3d functions
%
% This script performs unit tests on the layer configuration parser
% and layer extraction functions for GDSII-to-3D conversion.
%
% Run this from the gdsii-toolbox-146 directory with:
%   octave Export/tests/test_layer_functions.m
% or from MATLAB:
%   run('Export/tests/test_layer_functions.m')
%
% Author: WARP AI Agent, October 2025

clear all;
close all;
clc;

fprintf('========================================\n');
fprintf('Testing Layer Configuration Functions\n');
fprintf('========================================\n\n');

% Add directories to path
addpath('Export');
addpath(genpath('Basic'));

% Test counter
num_tests = 0;
num_passed = 0;
num_failed = 0;

% =========================================================================
% TEST 1: Load test configuration
% =========================================================================
fprintf('TEST 1: Load test configuration file\n');
fprintf('--------------------------------------\n');
num_tests = num_tests + 1;

try
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    % Check structure fields
    assert(isfield(cfg, 'metadata'), 'Missing metadata field');
    assert(isfield(cfg, 'layers'), 'Missing layers field');
    assert(isfield(cfg, 'conversion_options'), 'Missing conversion_options field');
    assert(isfield(cfg, 'layer_map'), 'Missing layer_map field');
    
    % Check metadata
    assert(strcmp(cfg.metadata.project, 'Test Configuration'), 'Incorrect project name');
    assert(strcmp(cfg.metadata.units, 'micrometers'), 'Incorrect units');
    
    % Check layers
    assert(length(cfg.layers) == 3, 'Expected 3 layers');
    assert(cfg.layers(1).gds_layer == 1, 'Layer 1 incorrect');
    assert(strcmp(cfg.layers(1).name, 'Layer1'), 'Layer 1 name incorrect');
    assert(cfg.layers(1).z_bottom == 0.0, 'Layer 1 z_bottom incorrect');
    assert(cfg.layers(1).z_top == 0.5, 'Layer 1 z_top incorrect');
    assert(cfg.layers(1).thickness == 0.5, 'Layer 1 thickness incorrect');
    
    % Check color parsing
    assert(isequal(size(cfg.layers(1).color), [1 3]), 'Color not RGB vector');
    assert(cfg.layers(1).color(1) == 1.0, 'Red component incorrect');
    assert(cfg.layers(1).color(2) == 0.0, 'Green component incorrect');
    assert(cfg.layers(1).color(3) == 0.0, 'Blue component incorrect');
    
    % Check enabled flag
    assert(cfg.layers(1).enabled == true, 'Layer 1 should be enabled');
    assert(cfg.layers(3).enabled == false, 'Layer 3 should be disabled');
    
    % Check layer map
    idx1 = cfg.layer_map(2, 1);  % Layer 1 = GDS layer 1, datatype 0 (1-indexed)
    assert(idx1 == 1, 'Layer map lookup failed for layer 1');
    
    idx2 = cfg.layer_map(3, 1);  % Layer 2 = GDS layer 2, datatype 0
    assert(idx2 == 2, 'Layer map lookup failed for layer 2');
    
    fprintf('✓ PASSED: Configuration loaded and validated\n\n');
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 2: Load IHP SG13G2 configuration
% =========================================================================
fprintf('TEST 2: Load IHP SG13G2 configuration\n');
fprintf('--------------------------------------\n');
num_tests = num_tests + 1;

try
    cfg_ihp = gds_read_layer_config('layer_configs/ihp_sg13g2.json');
    
    % Check basic structure
    assert(isfield(cfg_ihp, 'metadata'), 'Missing metadata field');
    assert(isfield(cfg_ihp, 'layers'), 'Missing layers field');
    
    % Check metadata
    assert(strcmp(cfg_ihp.metadata.foundry, 'IHP Microelectronics'), 'Incorrect foundry');
    assert(strcmp(cfg_ihp.metadata.process, 'SG13G2'), 'Incorrect process');
    
    % Should have multiple layers
    assert(length(cfg_ihp.layers) >= 10, 'Expected at least 10 layers');
    
    fprintf('✓ PASSED: IHP configuration loaded with %d layers\n\n', length(cfg_ihp.layers));
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 3: Error handling - missing file
% =========================================================================
fprintf('TEST 3: Error handling - missing file\n');
fprintf('--------------------------------------\n');
num_tests = num_tests + 1;

try
    cfg_bad = gds_read_layer_config('nonexistent_file.json');
    fprintf('✗ FAILED: Should have thrown FileNotFound error\n\n');
    num_failed = num_failed + 1;
catch ME
    if ~isempty(strfind(ME.identifier, 'FileNotFound'))
        fprintf('✓ PASSED: Correctly caught FileNotFound error\n\n');
        num_passed = num_passed + 1;
    else
        fprintf('✗ FAILED: Wrong error type: %s\n\n', ME.identifier);
        num_failed = num_failed + 1;
    end
end

% =========================================================================
% TEST 4: Create simple test GDSII structure
% =========================================================================
fprintf('TEST 4: Create test GDSII structure\n');
fprintf('--------------------------------------\n');
num_tests = num_tests + 1;

try
    % Create simple test geometry
    % Layer 1: Rectangle at (0,0) to (10,10)
    rect1 = [0 0; 10 0; 10 10; 0 10; 0 0];
    elem1 = gds_element('boundary', 'xy', rect1, 'layer', 1, 'dtype', 0);
    
    % Layer 2: Rectangle at (5,5) to (15,15)
    rect2 = [5 5; 15 5; 15 15; 5 15; 5 5];
    elem2 = gds_element('boundary', 'xy', rect2, 'layer', 2, 'dtype', 0);
    
    % Layer 3: Rectangle at (12,12) to (20,20)
    rect3 = [12 12; 20 12; 20 20; 12 20; 12 12];
    elem3 = gds_element('boundary', 'xy', rect3, 'layer', 3, 'dtype', 0);
    
    % Create structure
    test_struct = gds_structure('TestStruct', elem1, elem2, elem3);
    
    % Create library
    test_lib = gds_library('TestLib', test_struct);
    
    fprintf('✓ PASSED: Test GDSII structure created with 3 elements\n\n');
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 5: Extract layers from test structure
% =========================================================================
fprintf('TEST 5: Extract layers from test structure\n');
fprintf('--------------------------------------\n');
num_tests = num_tests + 1;

try
    % Load test config
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    % Extract layers
    layer_data = gds_layer_to_3d(test_struct, cfg);
    
    % Check structure
    assert(isfield(layer_data, 'metadata'), 'Missing metadata');
    assert(isfield(layer_data, 'layers'), 'Missing layers');
    assert(isfield(layer_data, 'statistics'), 'Missing statistics');
    
    % Check statistics
    assert(layer_data.statistics.total_elements == 3, 'Wrong element count');
    assert(layer_data.statistics.total_polygons == 2, 'Wrong polygon count (layer 3 disabled)');
    
    % Check extracted layers (should be 2, since layer 3 is disabled)
    assert(length(layer_data.layers) == 2, 'Expected 2 layers');
    
    % Check layer 1
    L1 = layer_data.layers(1);
    assert(strcmp(L1.config.name, 'Layer1'), 'Layer 1 name incorrect');
    assert(L1.num_polygons == 1, 'Layer 1 should have 1 polygon');
    assert(L1.area == 100, 'Layer 1 area should be 100');
    
    % Check layer 2
    L2 = layer_data.layers(2);
    assert(strcmp(L2.config.name, 'Layer2'), 'Layer 2 name incorrect');
    assert(L2.num_polygons == 1, 'Layer 2 should have 1 polygon');
    assert(L2.area == 100, 'Layer 2 area should be 100');
    
    fprintf('✓ PASSED: Layers extracted correctly\n\n');
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    disp(ME.stack);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 6: Layer filtering
% =========================================================================
fprintf('TEST 6: Layer filtering\n');
fprintf('--------------------------------------\n');
num_tests = num_tests + 1;

try
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    % Extract only layer 1
    layer_data = gds_layer_to_3d(test_struct, cfg, 'layers_filter', [1]);
    
    % Should have only 1 layer
    assert(length(layer_data.layers) == 1, 'Expected 1 layer');
    assert(strcmp(layer_data.layers(1).config.name, 'Layer1'), 'Wrong layer extracted');
    
    fprintf('✓ PASSED: Layer filtering works\n\n');
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 7: Enabled-only filtering
% =========================================================================
fprintf('TEST 7: Enabled-only filtering\n');
fprintf('--------------------------------------\n');
num_tests = num_tests + 1;

try
    cfg = gds_read_layer_config('Export/tests/fixtures/test_config.json');
    
    % Extract with enabled_only = false (should get all layers)
    layer_data = gds_layer_to_3d(test_struct, cfg, 'enabled_only', false);
    
    % Should have 3 layers now
    assert(length(layer_data.layers) == 3, 'Expected 3 layers with enabled_only=false');
    
    fprintf('✓ PASSED: Enabled-only filtering works\n\n');
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% TEST 8: Direct config file path
% =========================================================================
fprintf('TEST 8: Direct config file path to gds_layer_to_3d\n');
fprintf('--------------------------------------\n');
num_tests = num_tests + 1;

try
    % Pass config file path directly
    layer_data = gds_layer_to_3d(test_struct, 'Export/tests/fixtures/test_config.json');
    
    assert(isfield(layer_data, 'layers'), 'Missing layers field');
    assert(length(layer_data.layers) >= 1, 'No layers extracted');
    
    fprintf('✓ PASSED: Direct config file path works\n\n');
    num_passed = num_passed + 1;
    
catch ME
    fprintf('✗ FAILED: %s\n\n', ME.message);
    num_failed = num_failed + 1;
end

% =========================================================================
% SUMMARY
% =========================================================================
fprintf('\n========================================\n');
fprintf('TEST SUMMARY\n');
fprintf('========================================\n');
fprintf('Total tests:  %d\n', num_tests);
fprintf('Passed:       %d (%.1f%%)\n', num_passed, 100*num_passed/num_tests);
fprintf('Failed:       %d (%.1f%%)\n', num_failed, 100*num_failed/num_tests);
fprintf('========================================\n');

if num_failed == 0
    fprintf('\n✓✓✓ ALL TESTS PASSED ✓✓✓\n\n');
else
    fprintf('\n✗✗✗ SOME TESTS FAILED ✗✗✗\n\n');
end
