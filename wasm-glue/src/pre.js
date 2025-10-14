// GDSII Parser WASM Module - Pre-JS
// This code runs before the WASM module is initialized

console.log('Loading GDSII Parser WASM Module...');

// Add any global setup code here
if (typeof window !== 'undefined') {
    window.GDSParserLoading = true;
}
