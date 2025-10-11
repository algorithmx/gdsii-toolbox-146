# Test Fixtures

This directory contains test data and configuration files used by the test suite.

## Directory Structure

```
fixtures/
├── configs/              # Layer configuration JSON files
│   └── test_basic.json  # Basic 3-layer test configuration
└── README.md            # This file
```

## Configuration Files

### `configs/test_basic.json`

A minimal 3-layer configuration for unit testing:

- **Layer 1** (GDS 1): z=0.0-0.5 μm, Silicon, enabled ✅
- **Layer 2** (GDS 2): z=0.5-1.0 μm, SiO2, enabled ✅  
- **Layer 3** (GDS 3): z=1.0-1.5 μm, Metal, **disabled** ❌

This configuration is used by:
- `test_config_system.m` - Config parsing tests
- `test_layer_extraction.m` - Layer filtering tests
- `test_basic_pipeline.m` - End-to-end conversion tests

## External Fixtures

Some tests reference fixtures outside this directory:

- **IHP SG13G2 Config:** `../../layer_configs/ihp_sg13g2.json`
  - Used by `test_config_system.m` for real-world PDK validation
  - Test gracefully skips if file not found

## Adding New Fixtures

When adding test fixtures:

1. Place config files in `configs/`
2. Place GDS test files in appropriate subdirectory (TBD)
3. Update this README
4. Reference from test files using relative paths

## Fixture Guidelines

- **Keep fixtures minimal** - Only include what's needed for tests
- **Use relative paths** - Fixtures should work regardless of installation location
- **Document purpose** - Add comments explaining what each fixture tests
- **Version control** - All fixtures should be committed to git

---

**Last Updated:** October 5, 2025
