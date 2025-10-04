#!/usr/bin/env python3
"""
STEP file writer using pythonOCC
Called from MATLAB/Octave via system()

This script reads a JSON file containing extruded polygon data
and writes a STEP file using the pythonOCC library.

Usage:
    python3 step_writer.py input.json output.step

Input JSON format:
{
  "format": "AP203",
  "precision": 1e-6,
  "units": 1.0,
  "solids": [
    {
      "polygon": [[x1, y1], [x2, y2], ...],
      "z_bottom": z_bottom,
      "z_top": z_top,
      "material": "aluminum",
      "color": "#FF0000",
      "layer_name": "Metal1"
    }
  ]
}

Requirements:
    pip install pythonocc-core

Author: gdsii-toolbox-146
Date: October 4, 2025
"""

import sys
import json
import os

try:
    from OCC.Core.gp import gp_Pnt, gp_Vec, gp_Dir, gp_Ax2, gp_Pln
    from OCC.Core.BRepBuilderAPI import (
        BRepBuilderAPI_MakeEdge,
        BRepBuilderAPI_MakeWire,
        BRepBuilderAPI_MakeFace,
        BRepBuilderAPI_MakePolygon
    )
    from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakePrism
    from OCC.Core.STEPControl import STEPControl_Writer, STEPControl_AsIs
    from OCC.Core.IFSelect import IFSelect_RetDone
    from OCC.Core.TopoDS import TopoDS_Compound, TopoDS_Shape
    from OCC.Core.BRep import BRep_Builder
    from OCC.Core.Quantity import Quantity_Color, Quantity_TOC_RGB
    from OCC.Core.TopLoc import TopLoc_Location
    PYTHONOCC_AVAILABLE = True
except ImportError as e:
    PYTHONOCC_AVAILABLE = False
    IMPORT_ERROR = str(e)


def create_extruded_solid(polygon, z_bottom, z_top):
    """
    Convert 2D polygon + height to OpenCASCADE extruded solid
    
    Args:
        polygon: List of [x, y] coordinates
        z_bottom: Bottom Z coordinate
        z_top: Top Z coordinate
    
    Returns:
        TopoDS_Shape: Extruded solid
    """
    # Remove duplicate last point if present (closed polygon)
    if len(polygon) > 1 and polygon[0] == polygon[-1]:
        polygon = polygon[:-1]
    
    if len(polygon) < 3:
        raise ValueError(f"Polygon must have at least 3 vertices, got {len(polygon)}")
    
    # Create polygon wire at z_bottom
    poly_maker = BRepBuilderAPI_MakePolygon()
    
    for point in polygon:
        x, y = point[0], point[1]
        pnt = gp_Pnt(x, y, z_bottom)
        poly_maker.Add(pnt)
    
    # Close the polygon
    poly_maker.Close()
    
    if not poly_maker.IsDone():
        raise RuntimeError("Failed to create polygon wire")
    
    wire = poly_maker.Wire()
    
    # Create face from wire
    face_maker = BRepBuilderAPI_MakeFace(wire)
    
    if not face_maker.IsDone():
        raise RuntimeError("Failed to create face from wire")
    
    face = face_maker.Face()
    
    # Create extrusion vector
    extrusion_height = z_top - z_bottom
    if abs(extrusion_height) < 1e-10:
        raise ValueError(f"Extrusion height too small: {extrusion_height}")
    
    extrusion_vec = gp_Vec(0, 0, extrusion_height)
    
    # Extrude face to create solid
    prism_maker = BRepPrimAPI_MakePrism(face, extrusion_vec)
    
    if not prism_maker.IsDone():
        raise RuntimeError("Failed to extrude face")
    
    solid = prism_maker.Shape()
    
    return solid


def write_step(solids_data, output_file, step_format='AP203'):
    """
    Generate STEP file from solid definitions
    
    Args:
        solids_data: Dictionary with solid definitions
        output_file: Output STEP file path
        step_format: STEP format ('AP203' or 'AP214')
    """
    if not PYTHONOCC_AVAILABLE:
        raise ImportError(f"pythonOCC is not available: {IMPORT_ERROR}")
    
    # Create STEP writer
    step_writer = STEPControl_Writer()
    
    # Set STEP format
    # Note: pythonOCC uses Interface_Static for format selection
    # Default is typically AP203
    
    # Create compound to hold all solids
    compound = TopoDS_Compound()
    builder = BRep_Builder()
    builder.MakeCompound(compound)
    
    solids = solids_data.get('solids', [])
    
    if not solids:
        raise ValueError("No solids to export")
    
    print(f"Processing {len(solids)} solids...")
    
    # Process each solid
    for idx, solid_data in enumerate(solids):
        try:
            polygon = solid_data['polygon']
            z_bottom = solid_data['z_bottom']
            z_top = solid_data['z_top']
            
            # Create extruded solid
            solid = create_extruded_solid(polygon, z_bottom, z_top)
            
            # Add to compound
            builder.Add(compound, solid)
            
            # Optional: Add solid with metadata
            # (Material and color support depends on STEP AP version)
            layer_name = solid_data.get('layer_name', f'Layer_{idx}')
            material = solid_data.get('material', '')
            color = solid_data.get('color', '')
            
            print(f"  Solid {idx+1}: {layer_name} "
                  f"(z: {z_bottom:.3f} to {z_top:.3f})")
            
        except Exception as e:
            print(f"Warning: Failed to process solid {idx}: {e}", file=sys.stderr)
            continue
    
    # Transfer compound to STEP writer
    status = step_writer.Transfer(compound, STEPControl_AsIs)
    
    if status != IFSelect_RetDone:
        raise RuntimeError(f"STEP transfer failed with status: {status}")
    
    # Write STEP file
    status = step_writer.Write(output_file)
    
    if status != IFSelect_RetDone:
        raise RuntimeError(f"STEP write failed with status: {status}")
    
    print(f"STEP file written successfully: {output_file}")


def main():
    """Main entry point"""
    if len(sys.argv) != 3:
        print("Usage: python3 step_writer.py input.json output.step", file=sys.stderr)
        sys.exit(1)
    
    input_json = sys.argv[1]
    output_step = sys.argv[2]
    
    # Check if input file exists
    if not os.path.exists(input_json):
        print(f"Error: Input file not found: {input_json}", file=sys.stderr)
        sys.exit(1)
    
    # Check pythonOCC availability
    if not PYTHONOCC_AVAILABLE:
        print(f"Error: pythonOCC is not available: {IMPORT_ERROR}", file=sys.stderr)
        print("\nTo install pythonOCC:", file=sys.stderr)
        print("  conda install -c conda-forge pythonocc-core", file=sys.stderr)
        print("or", file=sys.stderr)
        print("  pip install pythonocc-core", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Read input JSON
        with open(input_json, 'r') as f:
            solids_data = json.load(f)
        
        # Get format
        step_format = solids_data.get('format', 'AP203')
        
        # Write STEP file
        write_step(solids_data, output_step, step_format)
        
        sys.exit(0)
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
