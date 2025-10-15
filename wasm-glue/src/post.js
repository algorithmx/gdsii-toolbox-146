// GDSII Parser WASM Module - Post-JS
// This code runs after the WASM module is initialized

if (typeof window !== 'undefined') {
    window.GDSParserLoading = false;
    console.log('GDSII Parser WASM Module loaded successfully');
}

// Export convenience functions
if (typeof Module !== 'undefined') {
    Module.gdsParseReady = true;

    // Make GDSParserModule globally accessible
    if (typeof window !== 'undefined') {
        window.GDSParserModule = Module;
    }

    // Auto-resolve the promise if something is waiting
    if (Module.gdsParseResolve) {
        Module.gdsParseResolve(Module);
    }
}
