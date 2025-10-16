/**
 * Real GDSII File Test
 * Tests the WASM module with an actual GDSII file
 */

async function testRealGDSFile() {
    console.log('🧪 Testing WASM with real GDSII file...');

    try {
        // Load the WASM module
        console.log('  1. Loading WASM module...');
        const module = await GDSParserModule();
        console.log('  ✓ WASM module loaded');

        // Check if memory views are available
        console.log('  2. Checking memory views...');
        if (!module.HEAPU8 || !module.HEAPF64 || !module.HEAP32 || !module.HEAP8) {
            // Try to attach memory views
            console.log('  Attaching memory views...');
            if (module.HEAP && module.HEAP.buffer) {
                const buffer = module.HEAP.buffer;
                module.HEAPU8 = new Uint8Array(buffer);
                module.HEAPF64 = new Float64Array(buffer);
                module.HEAP32 = new Int32Array(buffer);
                module.HEAP8 = new Int8Array(buffer);
                console.log('  ✓ Memory views attached from module.HEAP.buffer');
            } else {
                throw new Error('Could not attach memory views');
            }
        } else {
            console.log('  ✓ Memory views already available');
        }

        // Fetch the real GDSII file
        console.log('  3. Loading GDSII file...');
        const response = await fetch('/test_multilayer.gds');
        if (!response.ok) {
            throw new Error(`Failed to fetch GDSII file: ${response.status}`);
        }
        const arrayBuffer = await response.arrayBuffer();
        const gdsData = new Uint8Array(arrayBuffer);
        console.log(`  ✓ GDSII file loaded (${gdsData.length} bytes)`);

        // Allocate memory in WASM
        console.log('  4. Allocating WASM memory...');
        const dataPtr = module._malloc(gdsData.length);
        const errorPtr = module._malloc(4);

        if (dataPtr === 0) {
            throw new Error('Failed to allocate memory for GDSII data');
        }
        console.log(`  ✓ Memory allocated at pointer ${dataPtr}`);

        // Copy data to WASM memory
        console.log('  5. Copying data to WASM memory...');
        module.HEAPU8.set(gdsData, dataPtr);
        console.log('  ✓ Data copied to WASM memory');

        // Parse the GDSII file
        console.log('  6. Parsing GDSII file...');
        const libraryPtr = module._gds_parse_from_memory(dataPtr, gdsData.length, errorPtr);

        if (libraryPtr === 0) {
            const errorCode = module.HEAP32[errorPtr / 4];
            const errorMsg = module._gds_get_last_error();
            throw new Error(`Parse failed: code=${errorCode}, error="${errorMsg}"`);
        }
        console.log(`  ✓ GDSII parsed successfully, library pointer: ${libraryPtr}`);

        // Extract library information
        console.log('  7. Extracting library data...');
        const libraryName = module._gds_get_library_name(libraryPtr);
        const userUnits = module._gds_get_user_units_per_db_unit(libraryPtr);
        const metersPerUnit = module._gds_get_meters_per_db_unit(libraryPtr);
        const structureCount = module._gds_get_structure_count(libraryPtr);

        console.log(`  ✓ Library: "${libraryName}"`);
        console.log(`  ✓ Units: ${userUnits} user/DB, ${metersPerUnit} m/DB`);
        console.log(`  ✓ Structures: ${structureCount}`);

        // Extract structure details
        if (structureCount > 0) {
            console.log('  8. Analyzing structures...');
            for (let i = 0; i < structureCount; i++) {
                const structureName = module._gds_get_structure_name(libraryPtr, i);
                const elementCount = module._gds_get_element_count(libraryPtr, i);

                console.log(`    Structure ${i}: "${structureName}" (${elementCount} elements)`);

                // Analyze elements
                for (let j = 0; j < elementCount && j < 10; j++) { // Limit to first 10 elements
                    const elementType = module._gds_get_element_type(libraryPtr, i, j);
                    const elementLayer = module._gds_get_element_layer(libraryPtr, i, j);
                    const polygonCount = module._gds_get_element_polygon_count(libraryPtr, i, j);

                    console.log(`      Element ${j}: type=${elementType}, layer=${elementLayer}, polygons=${polygonCount}`);

                    // Extract polygon vertices if available
                    if (polygonCount > 0) {
                        const vertexCount = module._gds_get_element_polygon_vertex_count(libraryPtr, i, j, 0);
                        const verticesPtr = module._gds_get_element_polygon_vertices(libraryPtr, i, j, 0);

                        if (vertexCount > 0 && verticesPtr !== 0) {
                            const vertices = [];
                            for (let k = 0; k < Math.min(vertexCount, 8); k++) { // Limit to first 8 vertices
                                const x = module.HEAPF64[(verticesPtr / 8) + k];
                                const y = module.HEAPF64[(verticesPtr / 8) + k + vertexCount];
                                vertices.push(`(${x.toFixed(2)}, ${y.toFixed(2)})`);
                            }
                            console.log(`        Vertices (first ${Math.min(vertexCount, 8)}): ${vertices.join(', ')}`);
                        }
                    }
                }

                if (elementCount > 10) {
                    console.log(`      ... and ${elementCount - 10} more elements`);
                }
            }
        }

        // Get memory usage
        console.log('  9. Getting memory statistics...');
        const totalAllocated = module._gds_get_memory_usage();
        console.log(`  ✓ Memory usage: ${totalAllocated} bytes`);

        // Clean up
        console.log(' 10. Cleaning up...');
        module._gds_free_library(libraryPtr);
        module._free(dataPtr);
        module._free(errorPtr);
        console.log('  ✓ Cleanup completed');

        console.log('🎉 Real GDSII file test completed successfully!');
        return {
            success: true,
            libraryName,
            structureCount,
            totalElements: Array.from({length: structureCount}, (_, i) =>
                module._gds_get_element_count(libraryPtr, i)
            ).reduce((a, b) => a + b, 0)
        };

    } catch (error) {
        console.error('❌ Real GDSII file test failed:', error);
        return {
            success: false,
            error: error.message
        };
    }
}

// Auto-run the test when the page loads
if (typeof window !== 'undefined') {
    // Wait for everything to load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            setTimeout(testRealGDSFile, 1000);
        });
    } else {
        setTimeout(testRealGDSFile, 1000);
    }
}

// Export for manual testing
if (typeof window !== 'undefined') {
    window.testRealGDSFile = testRealGDSFile;
}