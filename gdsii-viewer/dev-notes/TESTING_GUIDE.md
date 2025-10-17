# Phase 1 Testing Guide

Quick reference for testing the new renderer integration.

---

## 🚀 Quick Start

```bash
# Start development server
npm run dev

# Open browser to
http://localhost:5173
```

---

## ✅ Quick Validation Checklist

### 1. App Loads (30 seconds)
- [ ] Browser opens without errors
- [ ] Canvas element visible
- [ ] UI controls present (zoom buttons, file input, layer panel)
- [ ] No JavaScript errors in console

### 2. Placeholder Mode (1 minute)
Since WASM might not load, test with placeholder:
- [ ] Canvas shows empty or placeholder geometry
- [ ] Stats overlay appears (top-right corner)
- [ ] Console shows renderer initialization messages

### 3. Basic Interactions (2 minutes)
- [ ] Click and drag moves the view
- [ ] Mouse wheel zooms in/out
- [ ] Zoom buttons work
- [ ] Reset view centers content

### 4. Layer Controls (1 minute)
- [ ] Layer list appears after loading
- [ ] Checkboxes toggle layer visibility
- [ ] Layer colors display

---

## 🧪 Detailed Testing Scenarios

### Scenario A: Placeholder Mode (No WASM)

**Expected Behavior:**
- App loads with 3 placeholder elements (2 boundaries, 1 path)
- Elements visible on canvas with different colors
- Can pan and zoom to inspect

**Test Steps:**
1. Open app
2. Should auto-load placeholder OR show empty canvas
3. Try loading any file → should create placeholder
4. Zoom in to see individual elements
5. Check stats show culling working

**Success Criteria:**
- 3 elements rendered initially
- Culling rate increases when zoomed in
- FPS stays at 60

---

### Scenario B: File Loading (With WASM)

**Expected Behavior:**
- File loads and parses
- Elements appear on canvas
- Layer list populates
- Performance stats update

**Test Steps:**
1. Click "Choose File"
2. Select a .gds file
3. Wait for parsing
4. Should see:
   - File info panel updates
   - Canvas shows geometry
   - Layer list populates
   - Stats show element count

**Success Criteria:**
- File loads without errors
- All layers visible initially
- Geometry renders correctly
- Performance acceptable

---

### Scenario C: Performance Validation

**Goal:** Verify culling efficiency and frame rates

**Test Steps:**
1. Load file or use placeholder
2. Check stats overlay (top-right)
3. **Zoom Out:** Should show more elements
4. **Zoom In:** Should show fewer elements
5. Record culling percentage at different zoom levels

**Expected Results:**

| Zoom Level | Elements Visible | Culling % | FPS |
|------------|------------------|-----------|-----|
| Fit All | All (100%) | 0% | 60 |
| 2x Zoom | ~50% | 50% | 60 |
| 5x Zoom | ~20% | 80% | 60 |
| 10x Zoom | ~5-10% | 90-95% | 60 |

**Success Criteria:**
- Culling rate increases with zoom
- FPS maintains 60 at all zoom levels
- Frame time stays <16ms

---

### Scenario D: Layer Management

**Test Steps:**
1. Load file with multiple layers
2. Check layer list populated
3. Uncheck layer 1 → should disappear
4. Re-check layer 1 → should reappear
5. Toggle all layers on/off
6. Verify performance not affected

**Success Criteria:**
- Layers toggle instantly
- No visual artifacts
- Unchecked layers don't render
- FPS stays consistent

---

### Scenario E: Mouse Interactions

**Pan Test:**
1. Click and hold on canvas
2. Drag left/right/up/down
3. Should see content move smoothly
4. Release → movement stops
5. Cursor changes to "grabbing" while dragging

**Zoom Test:**
1. Click zoom in (+) button → zooms to center
2. Click zoom out (-) button → zooms from center
3. Scroll wheel up → zoom in at mouse position
4. Scroll wheel down → zoom out at mouse position
5. Verify zoom limits (0.01x to 100x)

**Reset Test:**
1. Pan and zoom to arbitrary position
2. Click "Reset View"
3. Should fit all content with padding
4. Content centered in canvas

**Success Criteria:**
- Pan feels smooth and responsive
- Zoom maintains focus point
- No lag or stuttering
- Reset fits content properly

---

## 🔍 Debugging Commands

### Browser Console Commands

```javascript
// Check if viewer initialized
window.gdsViewer

// Get library info
window.gdsViewer.getLibraryInfo()

// Check renderer
window.gdsViewer.renderer

// Get current stats
window.gdsViewer.renderer.getStatistics()

// Get viewport state
window.gdsViewer.viewport

// Check canvas
window.gdsViewer.canvas

// Manual render trigger
window.gdsViewer.render()
```

### Check Renderer State

```javascript
// Verify renderer type
window.gdsViewer.renderer.getCapabilities()
// Should show: { backend: 'canvas2d', ... }

// Check scene graph
window.gdsViewer.renderer.getSceneGraph

// Check layer styles
window.gdsViewer.renderer.getLayerStyle(1, 0)
```

### Performance Monitoring

```javascript
// Enable performance logging
setInterval(() => {
  const stats = window.gdsViewer.renderer.getStatistics();
  console.log('FPS:', stats.fps, 
              'Elements:', stats.elementsRendered,
              'Culled:', stats.elementsCulled);
}, 1000);
```

---

## 🐛 Common Issues & Quick Fixes

### Issue: Blank Canvas
```javascript
// Check renderer initialized
console.log(window.gdsViewer.renderer); // Should not be null

// Check library loaded
console.log(window.gdsViewer.currentLibrary); // Should have data

// Force render
window.gdsViewer.render();
```

### Issue: No Stats Overlay
```javascript
// Stats element should exist
document.getElementById('render-stats')

// Manually trigger stats update
window.gdsViewer.updateStatistics(
  window.gdsViewer.renderer.getStatistics()
);
```

### Issue: Pan/Zoom Not Working
```javascript
// Check viewport state
console.log(window.gdsViewer.viewport);
// Should have: center, zoom, width, height

// Check event listeners attached
window.gdsViewer.canvas.onclick // Should be defined
```

### Issue: Layers Not Showing
```javascript
// Get layer list
const layers = window.gdsViewer.renderer.getSceneGraph();

// Check layer visibility
window.gdsViewer.renderer.getLayerStyle(1, 0);

// Force layer visible
window.gdsViewer.renderer.setLayerVisible(1, 0, true);
window.gdsViewer.render();
```

---

## 📊 Performance Benchmarks

### Expected Performance Targets

| Metric | Target | Acceptable | Poor |
|--------|--------|------------|------|
| FPS | 60 | 45-60 | <45 |
| Frame Time | <16ms | <22ms | >22ms |
| Culling @ 5x zoom | >80% | >70% | <70% |
| Memory Usage | <100MB | <200MB | >200MB |
| Init Time | <500ms | <1s | >1s |

### Stress Test

To test with many elements:
1. Load a large GDSII file (>10K elements)
2. Zoom out to show all elements
3. Check FPS stays above 30
4. Zoom in progressively
5. Verify culling improves performance

**Expected:**
- FPS improves as you zoom in
- Culling rate approaches 95%+
- No stuttering or lag

---

## ✅ Phase 1 Sign-Off Criteria

Phase 1 is ready for Phase 2 if:

### Functional Requirements
- [x] TypeScript compiles without errors
- [ ] App loads in browser
- [ ] Renderer initializes successfully
- [ ] Canvas renders geometry
- [ ] Mouse interactions work
- [ ] Layer controls work
- [ ] Performance stats display

### Performance Requirements
- [ ] FPS ≥45 with typical files
- [ ] Culling efficiency >70%
- [ ] No visual glitches
- [ ] Smooth pan/zoom
- [ ] Fast initial load (<2s)

### Quality Requirements
- [x] Code follows TypeScript best practices
- [x] No TypeScript errors in critical path
- [x] Clean separation of concerns
- [x] Architecture supports WebGL backend
- [ ] Manual testing passes all scenarios

---

## 🎯 Quick Test Script

Run this in browser console for automated check:

```javascript
// Quick Validation Script
(function() {
  const checks = {
    'Viewer initialized': !!window.gdsViewer,
    'Renderer exists': !!window.gdsViewer?.renderer,
    'Canvas exists': !!window.gdsViewer?.canvas,
    'Viewport configured': !!window.gdsViewer?.viewport,
    'Stats method exists': typeof window.gdsViewer?.renderer?.getStatistics === 'function'
  };
  
  console.log('=== Phase 1 Quick Check ===');
  Object.entries(checks).forEach(([name, pass]) => {
    console.log(pass ? '✅' : '❌', name);
  });
  
  if (window.gdsViewer?.renderer) {
    const stats = window.gdsViewer.renderer.getStatistics();
    console.log('\n=== Current Stats ===');
    console.log('FPS:', stats.fps);
    console.log('Elements:', stats.elementsRendered);
    console.log('Draw Calls:', stats.drawCalls);
  }
  
  const allPass = Object.values(checks).every(v => v);
  console.log('\n' + (allPass ? '✅ All checks passed!' : '❌ Some checks failed'));
})();
```

---

## 📝 Test Report Template

After testing, document results:

```markdown
## Phase 1 Test Report

**Date:** [DATE]
**Tester:** [NAME]
**Browser:** [Chrome/Firefox/Safari] [VERSION]

### Results Summary
- [ ] All functional tests passed
- [ ] Performance targets met
- [ ] No blocking issues found

### Detailed Results
- App Load Time: ___ ms
- FPS (idle): ___
- FPS (zoomed out): ___
- FPS (zoomed in): ___
- Culling rate (5x zoom): ___ %
- Memory usage: ___ MB

### Issues Found
1. [Issue description]
2. [Issue description]

### Recommendations
- [ ] Ready for Phase 2
- [ ] Minor fixes needed
- [ ] Major issues to resolve

### Notes
[Additional observations]
```

---

## 🔜 Next Steps

After Phase 1 testing completes:

1. **Document any issues** found during testing
2. **Fix critical bugs** if any
3. **Optimize** if performance targets not met
4. **Create Phase 2 plan** for WebGL implementation
5. **Celebrate** Phase 1 completion! 🎉

---

**Ready to test?** Run `npm run dev` and start with Quick Validation Checklist!
