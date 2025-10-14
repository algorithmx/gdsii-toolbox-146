#!/usr/bin/env node

/**
 * Simple test to verify WASM module functionality
 */

const fs = require('fs');
const path = require('path');

async function testWASMModule() {
    try {
        console.log('🧪 Testing WASM module loading...');

        // Check if WASM files exist
        const wasmPath = path.join(__dirname, 'public', 'gds-parser.wasm');
        const jsPath = path.join(__dirname, 'public', 'gds-parser.js');

        if (!fs.existsSync(wasmPath)) {
            throw new Error(`WASM file not found: ${wasmPath}`);
        }
        if (!fs.existsSync(jsPath)) {
            throw new Error(`JS file not found: ${jsPath}`);
        }

        console.log('✓ WASM files exist');

        // Check file sizes
        const wasmStats = fs.statSync(wasmPath);
        const jsStats = fs.statSync(jsPath);

        console.log(`✓ WASM file size: ${wasmStats.size} bytes`);
        console.log(`✓ JS file size: ${jsStats.size} bytes`);

        // Check if WASM file can be read
        const wasmBuffer = fs.readFileSync(wasmPath);
        console.log(`✓ WASM file readable, first 8 bytes: ${wasmBuffer.slice(0, 8).toString('hex')}`);

        // Check JS content for key functions
        const jsContent = fs.readFileSync(jsPath, 'utf8');
        const requiredFunctions = [
            '_gds_parse_from_memory',
            '_gds_free_library',
            '_gds_get_library_name',
            'GDSParserModule'
        ];

        for (const func of requiredFunctions) {
            if (jsContent.includes(func)) {
                console.log(`✓ Found function: ${func}`);
            } else {
                throw new Error(`Missing function: ${func}`);
            }
        }

        console.log('🎉 WASM module files are valid!');
        return true;

    } catch (error) {
        console.error('❌ WASM module test failed:', error.message);
        return false;
    }
}

testWASMModule().then(success => {
    process.exit(success ? 0 : 1);
});