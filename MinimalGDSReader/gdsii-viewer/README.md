# GDSII Viewer

A minimal TypeScript single-page application for loading and visualizing GDSII files using Vite and HTML5 Canvas.

## Features

- **Maximized Canvas**: Full-screen layout with minimal UI chrome
- **File Loading**: Compact file input with folder icon
- **2D Canvas Visualization**: Basic rendering of GDSII elements using HTML5 Canvas
- **Interactive Controls**:
  - Floating zoom controls positioned on canvas
  - Zoom in/out with buttons or mouse wheel
  - Pan canvas by clicking and dragging
  - Reset view to default state
- **Collapsible Info Panel**: Right-side panel that can be hidden for maximum canvas space
  - File information display
  - Layer visibility toggles
  - Smooth slide-in/out animations
- **Modern UI**: Glassmorphism design with backdrop blur effects

## Current Status

This is a **minimal implementation** with placeholder functionality:

- ✅ Basic UI layout with controls and canvas
- ✅ File loading interface
- ✅ 2D canvas rendering system
- ✅ Interactive zoom and pan controls
- ✅ Layer visibility toggles
- ⚠️ **GDSII parsing is simulated** - returns demo data instead of parsing actual files

## Getting Started

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn

### Installation

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

The application will be available at `http://localhost:5173/`

### Build for Production

```bash
# Build the application
npm run build

# Preview the build
npm run preview
```

## Usage

1. Open the application in your browser
2. Click the 📁 folder icon to select a GDSII file
3. Use the floating zoom controls on the canvas:
   - ➕ Zoom in / ➖ Zoom out / 🔄 Reset view
   - Mouse wheel zooming
   - Click and drag to pan
4. Toggle the right info panel:
   - Click the ◀ arrow in the panel header to hide
   - Click the ▶ arrow on the right edge to show again
5. Manage layer visibility with checkboxes in the info panel

## Architecture

### Core Components

- **GDSViewer**: Main application class
- **GDSLibrary/GDSStructure/GDSElement**: TypeScript interfaces for GDSII data model
- **Canvas Rendering**: 2D drawing using HTML5 Canvas API
- **Event Handling**: Mouse and keyboard interactions

### File Structure

```
src/
├── main.ts          # Main application logic
├── style.css        # UI styling
└── counter.ts       # (removed)
```

## Development Notes

### GDSII Parsing

The current implementation includes a placeholder parser that simulates GDSII file parsing. For production use, you would need to:

1. Implement actual GDSII binary format parsing
2. Handle compression and record structures
3. Parse all GDSII element types (BOUNDARY, PATH, TEXT, etc.)
4. Support structure references and hierarchy

### Canvas Rendering

The canvas system supports:
- Basic geometric shapes (polygons, paths)
- Layer-based coloring
- Coordinate transformation (GDSII coordinates to screen coordinates)
- Interactive pan and zoom

### Browser Compatibility

- Modern browsers with Canvas API support
- TypeScript for type safety
- Vite for fast development and building

## Future Enhancements

- Real GDSII binary format parsing
- Support for all GDSII element types
- Layer styling and color customization
- Measurement tools
- Export functionality
- Structure hierarchy navigation
- Performance optimization for large files

## License

This project is provided as-is for educational and development purposes.