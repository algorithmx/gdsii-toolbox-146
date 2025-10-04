# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## About This Project

The GDSII Toolbox is a MATLAB/Octave library for creating, reading, and modifying GDSII format files used in semiconductor, MEMS, and nano-structured optics fabrication. It provides object-oriented classes and methods for working with layout databases.

## Build & Compilation Commands

This toolbox requires compilation of MEX functions before use:

### Linux/Unix with Octave
```bash
./makemex-octave
```

### MATLAB/Octave on Windows
```matlab
makemex
```

The compilation process builds:
- Low-level I/O functions (C MEX files)
- Boolean set operations using Clipper library (C++ MEX file)
- DataMatrix code generation (C MEX file with GPL license)

### Cleanup
```bash
./cleanup
```
Removes compiled MEX files and object files.

## Architecture Overview

The toolbox follows a hierarchical object-oriented design:

### Core Class Hierarchy
- **`gds_library`** - Top-level container for entire GDSII libraries
  - Contains multiple `gds_structure` objects
  - Methods: `write_gds_library`, `treeview`, `subtree`, `topstruct`
- **`gds_structure`** - Individual structures/cells within a library
  - Contains arrays of `gds_element` objects
  - Methods: `add_element`, `add_ref`, `find`, `poly_convert`
- **`gds_element`** - Individual geometric elements
  - Types: boundary, path, sref, aref, text, node, box
  - Methods: `poly_bool`, `poly_area`, Boolean operators (`&`, `|`, `-`, `^`)

### Directory Structure
- **`Basic/`** - Core classes, low-level I/O, and fundamental operations
  - `gdsio/` - MEX functions for file I/O (C code)
  - `@gds_library/`, `@gds_structure/`, `@gds_element/` - Class definitions
- **`Elements/`** - Higher-level functions returning `gds_element` objects
- **`Structures/`** - Functions returning `gds_structure` objects  
- **`Boolean/`** - Polygon Boolean operations using Clipper library
- **`Scripts/`** - Command-line utilities (gdstree, gdslayers, gdsmerge, cgdsconv)

### Key Features
- **Boolean Polygon Operations** - Uses Clipper library for union, intersection, difference
- **Compound Elements** - Single elements containing multiple polygons
- **Structure References** - Hierarchical design through sref/aref elements
- **Fast I/O** - MEX functions provide 4-5x speedup over pure MATLAB/Octave

## Testing & Validation

No formal test suite exists. Validation is typically done by:
1. Creating test layouts and verifying with KLayout viewer
2. Checking file I/O roundtrip consistency
3. Validating Boolean operations on known polygon sets

## Common Development Workflows

### Creating New Layout Functions
1. Place in appropriate directory (`Elements/` or `Structures/`)
2. Return appropriate object type (`gds_element` or `gds_structure`)
3. Follow naming convention: `gdsii_<function_name>.m`

### Working with Boolean Operations
```matlab
% Elements must have units defined before Boolean operations
result = element1 & element2;  % intersection
result = element1 | element2;  % union  
result = element1 - element2;  % difference
```

### File I/O Pattern
```matlab
% Reading
glib = read_gds_library('filename.gds');

% Writing  
glib.write_gds_library('output.gds');
```

## Environment Requirements

- **MATLAB** R2014b or later, OR **Octave** 3.8 or later
- **C compiler** - Must be C99 compliant (LCC not sufficient)
- **C++ compiler** - Required for Clipper library compilation
- **KLayout** (recommended) - For viewing/validating GDSII files

## Important Notes

- All MEX functions must be compiled before first use
- Boolean operations require user units to be defined in library
- Large files (>1GB) supported but may require memory management
- Multiple licensing: Public Domain (most), Boost (Clipper), GPL v2/v3 (some components)
- No Unicode string support currently
- Path elements limited to 8192 vertices, boundaries to 8191 vertices

## Command Line Tools

The `Scripts/` directory contains command-line utilities:
- **`gdstree`** - Display structure hierarchy
- **`gdslayers`** - Show layer statistics  
- **`gdsmerge`** - Merge multiple GDSII files
- **`cgdsconv`** - Convert compound GDS to standard format

Install these in `/usr/local/bin` or similar for system-wide access.