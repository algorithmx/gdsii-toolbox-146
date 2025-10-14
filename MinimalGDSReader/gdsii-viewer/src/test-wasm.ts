/**
 * Simple WASM Integration Test
 * This validates that the WASM module can be loaded and basic functions work
 */

import { loadWASMModule, validateWASMModule, parseGDSII } from './wasm-interface';

// Simple test GDSII data (a square)
const testGDSData = new Uint8Array([
    0x00, 0x02, // HEADER
    0x01, 0x02, // BGNLIB (6 bytes timestamp)
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x02, 0x06, 0x54, 0x45, 0x53, 0x54, // LIBNAME = "TEST"
    0x03, 0x05, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, // UNITS
    0x3D, 0x0A, 0xD7, 0xA3, 0x70, 0x3D, 0x0A, 0xD7,
    0x05, 0x02, // BGNSTR
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x06, 0x06, 0x54, 0x45, 0x53, 0x54, // STRNAME = "TEST"
    0x08, 0x00, // BOUNDARY
    0x0d, 0x02, 0x00, 0x01, // LAYER = 1
    0x0e, 0x02, 0x00, 0x00, // DATATYPE = 0
    0x10, 0x03, // XY: (-50, -50)
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x10, 0x03, // XY: (50, -50)
    0x00, 0x32, 0x00, 0x00, 0x00, 0x32,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x10, 0x03, // XY: (50, 50)
    0x00, 0x32, 0x00, 0x00, 0x00, 0x32,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x10, 0x03, // XY: (-50, 50)
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x00, 0x32, 0x00, 0x00, 0x00, 0x00,
    0x11, 0x00, // ENDEL
    0x07, 0x00, // ENDSTR
    0x04, 0x00  // ENDLIB
]);

export async function testWASMIntegration(): Promise<boolean> {
    console.log('🧪 Testing WASM Integration...');

    try {
        // Test 1: Load WASM module
        console.log('  1. Loading WASM module...');
        const module = await loadWASMModule();
        console.log('     ✓ WASM module loaded');

        // Test 2: Validate module
        console.log('  2. Validating WASM module...');
        const isValid = validateWASMModule();
        if (!isValid) {
            console.error('     ✗ WASM module validation failed');
            return false;
        }
        console.log('     ✓ WASM module is valid');

        // Test 3: Parse GDSII data
        console.log('  3. Parsing GDSII data...');
        const startTime = performance.now();
        const library = await parseGDSII(testGDSData);
        const parseTime = performance.now() - startTime;

        console.log(`     ✓ GDSII parsed in ${parseTime.toFixed(2)}ms`);
        console.log(`     Library: ${library.name}`);
        console.log(`     Structures: ${library.structures.length}`);
        console.log(`     Units: ${library.units.userUnitsPerDatabaseUnit} user/DB, ${library.units.metersPerDatabaseUnit} m/DB`);

        if (library.structures.length > 0) {
            const struct = library.structures[0];
            console.log(`     First structure: ${struct.name} (${struct.elements.length} elements)`);
        }

        console.log('🎉 All WASM integration tests passed!');
        return true;

    } catch (error) {
        console.error('❌ WASM integration test failed:', error);
        return false;
    }
}

// Auto-run test when module is loaded
if (typeof window !== 'undefined') {
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            setTimeout(testWASMIntegration, 1000);
        });
    } else {
        setTimeout(testWASMIntegration, 1000);
    }
}