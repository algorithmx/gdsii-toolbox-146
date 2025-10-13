<<<<<<< HEAD
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

### Compiling MEX Functions
This toolbox contains MEX functions that must be compiled before use:

**For Linux/Unix with Octave:**
```bash
./makemex-octave
```

**For MATLAB/Octave on Windows:**
```matlab
>> makemex
```

Both commands compile low-level I/O functions, Boolean algebra operations, and utility functions required by the GDSII toolbox.

## Testing

### Running Test Suite
The project includes a comprehensive test suite for the GDS-to-STEP export functionality:

**From shell:**
```bash
cd Export/new_tests
./run_tests.sh
```

**From MATLAB/Octave:**
```matlab
cd Export/new_tests
run_tests()
```

**With optional tests:**
```matlab
run_tests('optional', true)
```

The test suite includes:
- Configuration system tests
- Extrusion core functionality tests
- File export tests
- Layer extraction tests
- Basic pipeline tests
- Optional PDK and advanced pipeline tests

## Architecture

### Core Components

**GDSII Object Framework:**
- `gds_library` - Top-level container for GDSII libraries
- `gds_structure` - Cell/structure definitions containing elements
- `gds_element` - Geometric elements (boundary, path, text, references)

**Key Directories:**
- `Basic/` - Low-level I/O functions and object-oriented framework
- `Elements/` - High-level functions returning gds_element objects
- `Structures/` - High-level functions returning gds_structure objects
- `Boolean/` - Polygon Boolean operations using Clipper library
- `Export/` - GDS-to-STEP conversion functionality
- `Scripts/` - Command-line scripts for Octave

### Object-Oriented Design
The toolbox uses MATLAB's object-oriented programming with classes for:
- Elements support property access via field indexing (e.g., `el.layer = 2`)
- Structures support array indexing for element access
- Libraries provide hierarchical structure management

### Boolean Operations
Boolean polygon operations are implemented using the Clipper library:
- Located in `Boolean/clipper.cpp` and `Boolean/clipper.hpp`
- Compiled as MEX function `poly_boolmex`
- Supports union, intersection, difference, and XOR operations

### GDSII Format Support
The toolbox supports most GDSII format features:
- All standard element types (boundary, path, text, box, node, sref, aref)
- Structure hierarchy and references
- Properties and attributes
- Both reading and writing capabilities

## Development Notes

### MEX Function Dependencies
- Low-level file I/O in `Basic/gdsio/`
- Element processing in `Basic/@gds_element/private/`
- Structure utilities in `Structures/private/`
- Boolean operations in `Boolean/`

### Compiler Requirements
- C99-conformant C compiler required
- C++ compiler needed for Clipper library
- LCC compiler (old MATLAB versions) is not supported

### File Viewing
[KLayout](https://klayout.de) is recommended for viewing and editing GDSII files.
=======
- This is a Octave-first project, although originally designed for both MATLAB and OCTAVE
- The folder `Export` contains a module with the capability of converting GDSII to STEP file.
>>>>>>> 455d611 (test migration)
