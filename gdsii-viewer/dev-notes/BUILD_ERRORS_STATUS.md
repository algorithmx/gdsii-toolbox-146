# Build Errors Status

## Fixed ✅
1. **gdsii-utils.ts** - Type narrowing for calculateBoxBBox and calculateNodeBBox
2. **hierarchy-resolver.ts** - Type narrowing in transformElement function
3. **canvas2d-renderer.ts** - Type narrowing for drawBox and drawNode methods

## Remaining Errors

### main.ts (~138 errors)
The main.ts file still contains old rendering code that needs to be replaced with the new renderer system:

#### Old Properties to Remove:
- `ctx: CanvasRenderingContext2D`
- `scale`, `offsetX`, `offsetY`
- `lastOffset`
- `flattenedStructures`
- `layers`
- `renderOptions`

#### Missing Imports:
- `flattenStructure` (from hierarchy-resolver)
- `extractLayersFromLibrary` (needs to be created or removed)
- `DEFAULT_RENDER_OPTIONS` (from gdsii-types)
- `GDSRenderOptions` (from gdsii-types)
- Type imports: `GDSBoundaryElement`, `GDSPathElement`, `GDSTextElement`

#### Old Methods to Remove/Replace:
- `renderLibrary()` - uses old ctx, scale, layers
- `drawElements()` - uses old ctx rendering
- `drawBoundaryElement()` - uses old ctx
- `drawPathElement()` - uses old ctx
- `drawBoxElement()` - uses old ctx
- `drawTextElement()` - uses old ctx
- `zoom()` - manipulates old scale
- `fitToView()` - manipulates old scale/offset
- `startPan()`, `pan()` - manipulate old offset
- `reset()` - resets old properties

### wasm-interface.ts (~115 errors)
The WASM interface has many type mismatches with the EnhancedWASMModule interface:

####Missing Methods on EnhancedWASMModule:
- `writeArrayToMemory`, `setValue`, `getValue`
- `HEAP16`, `HEAPF32`
- `_gds_get_library_creation_date`
- `_gds_get_library_modification_date`
- `_gds_get_structure_dates`
- `_gds_get_element_data_type`
- `_gds_get_element_elflags`
- `_gds_get_element_plex`
- `_gds_get_element_path_*` methods
- `_gds_get_element_text_position`
- `_gds_get_element_text_type`
- `_gds_get_element_reference_corners`
- `_gds_get_element_strans_flags`
- `_gds_get_element_magnification`
- `_gds_get_element_rotation_angle`

#### Error Handling Issues:
- Multiple places pass Error objects to functions expecting number parameters
- Error constructor called with 2 arguments (only accepts 1)

## Recommended Fix Order

### Priority 1: Get Basic Build Working
1. Comment out/stub the old rendering methods in main.ts
2. Add necessary imports for the new renderer system
3. Remove references to old properties (ctx, scale, etc.)

### Priority 2: Complete Renderer Integration  
1. Implement proper renderer lifecycle in main.ts
2. Connect UI controls to renderer viewport
3. Remove all old canvas drawing code

### Priority 3: Fix WASM Interface (Optional - if WASM is needed)
1. Update EnhancedWASMModule interface to match actual WASM exports
2. Fix error handling patterns
3. Add proper memory access helpers

## Quick Fix Strategy

For immediate compilation, we can:
1. **Stub out old methods** in main.ts with TODO comments
2. **Import required types** from gdsii-types and hierarchy-resolver
3. **Comment out WASM-dependent code** until interface is fixed
4. Focus on **getting the new renderer working** first

The new renderer system (Phase 1) is complete and tested. The integration just needs to replace the old canvas code in main.ts.
