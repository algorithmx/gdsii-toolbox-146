#!/usr/bin/env python3
"""
3D Boolean Operations using pythonOCC

This module provides functions for performing boolean operations (union, 
intersection, difference) on 3D solids using OpenCASCADE via pythonOCC.

Called from MATLAB/Octave via system() for 3D solid merging operations.

Usage:
    python3 boolean_ops.py input.json output.json operation

Input JSON format:
{
  "solids": [
    {
      "polygon": [[x1, y1], [x2, y2], ...],
      "z_bottom": z_bottom,
      "z_top": z_top,
      "material": "aluminum",
      "color": "#FF0000",
      "layer_name": "Metal1"
    }
  ],
  "operation": "union",  // or "difference", "intersection"
  "precision": 1e-6
}

Output JSON format:
{
  "success": true,
  "merged_solids": [...],  // Same format as input solids
  "statistics": {
    "input_count": N,
    "output_count": M,
    "operation": "union"
  }
}

Requirements:
    pip install pythonocc-core

Author: WARP AI Agent
Date: October 4, 2025
Part of gdsii-toolbox-146 Section 4.10 implementation
"""

import sys
import json
import os
import traceback

try:
    from OCC.Core.gp import gp_Pnt, gp_Vec
    from OCC.Core.BRepBuilderAPI import (
        BRepBuilderAPI_MakePolygon,
        BRepBuilderAPI_MakeFace
    )
    from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakePrism
    from OCC.Core.BRepAlgoAPI import (
        BRepAlgoAPI_Fuse,
        BRepAlgoAPI_Common,
        BRepAlgoAPI_Cut
    )
    from OCC.Core.BRepTools import breptools_Read, breptools_Write
    from OCC.Core.BRep import BRep_Builder
    from OCC.Core.TopoDS import TopoDS_Shape, TopoDS_Compound
    from OCC.Core.TopExp import TopExp_Explorer
    from OCC.Core.TopAbs import TopAbs_SOLID, TopAbs_FACE
    from OCC.Core.BRepGProp import brepgprop_VolumeProperties
    from OCC.Core.GProp import GProp_GProps
    from OCC.Core.BRepBndLib import brepbndlib_Add
    from OCC.Core.Bnd import Bnd_Box
    from OCC.Core.BRepMesh import BRepMesh_IncrementalMesh
    from OCC.Core.StlAPI import StlAPI_Writer
    from OCC.Core.BRepClass3d import BRepClass3d_SolidClassifier
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


def get_solid_properties(shape):
    """
    Get geometric properties of a solid
    
    Args:
        shape: TopoDS_Shape
    
    Returns:
        dict: Properties including volume, bounding box, centroid
    """
    props = GProp_GProps()
    brepgprop_VolumeProperties(shape, props)
    
    volume = props.Mass()
    centroid = props.CentreOfMass()
    
    # Get bounding box
    bbox = Bnd_Box()
    brepbndlib_Add(shape, bbox)
    xmin, ymin, zmin, xmax, ymax, zmax = bbox.Get()
    
    return {
        'volume': volume,
        'centroid': [centroid.X(), centroid.Y(), centroid.Z()],
        'bbox': [xmin, ymin, zmin, xmax, ymax, zmax]
    }


def extract_polygon_from_face(face):
    """
    Extract polygon coordinates from a planar face
    
    This is a simplified extraction that assumes the face is planar
    and attempts to extract vertices from its wire.
    
    Args:
        face: TopoDS_Face
    
    Returns:
        list: List of [x, y, z] coordinates, or None if extraction fails
    """
    try:
        from OCC.Core.BRepTools import BRepTools_WireExplorer
        from OCC.Core.TopExp import TopExp_Explorer
        from OCC.Core.TopAbs import TopAbs_WIRE, TopAbs_VERTEX
        from OCC.Core.BRep import BRep_Tool
        
        # Get outer wire
        wire_explorer = TopExp_Explorer(face, TopAbs_WIRE)
        if not wire_explorer.More():
            return None
        
        wire = wire_explorer.Current()
        
        # Extract vertices from wire using WireExplorer for proper ordering
        vertices = []
        wire_exp = BRepTools_WireExplorer(wire)
        
        while wire_exp.More():
            # Get current vertex
            vertex = wire_exp.CurrentVertex()
            pnt = BRep_Tool.Pnt(vertex)
            vertices.append([pnt.X(), pnt.Y(), pnt.Z()])
            wire_exp.Next()
        
        # Remove duplicate last point if it equals first (closed wire)
        if len(vertices) > 1 and vertices[0] == vertices[-1]:
            vertices = vertices[:-1]
        
        return vertices if len(vertices) >= 3 else None
        
    except Exception:
        return None


def shape_to_solid_data(shape, z_bottom, z_top, metadata=None):
    """
    Convert an OpenCASCADE shape back to solid data format
    
    This attempts to extract the base polygon from the shape.
    For complex merged shapes, this is a simplified approximation.
    
    Args:
        shape: TopoDS_Shape
        z_bottom: Bottom Z coordinate
        z_top: Top Z coordinate  
        metadata: Optional metadata dict
    
    Returns:
        dict: Solid data in the standard format
    """
    # Get shape properties
    props = get_solid_properties(shape)
    
    # Try to extract a representative polygon
    # For complex shapes, we'll extract from one of the faces
    polygon = []
    
    try:
        # Find a face at approximately z_bottom
        explorer = TopExp_Explorer(shape, TopAbs_FACE)
        while explorer.More():
            face = explorer.Current()
            vertices = extract_polygon_from_face(face)
            
            if vertices and len(vertices) >= 3:
                # Check if face is approximately at z_bottom
                z_coords = [v[2] for v in vertices]
                avg_z = sum(z_coords) / len(z_coords)
                
                if abs(avg_z - z_bottom) < abs(avg_z - z_top):
                    # This face is closer to bottom
                    polygon = [[v[0], v[1]] for v in vertices]
                    break
            
            explorer.Next()
    except Exception:
        pass
    
    # If we couldn't extract polygon, use bounding box as approximation
    if not polygon:
        bbox = props['bbox']
        xmin, ymin, zmin, xmax, ymax, zmax = bbox
        polygon = [
            [xmin, ymin],
            [xmax, ymin],
            [xmax, ymax],
            [xmin, ymax]
        ]
    
    solid_data = {
        'polygon': polygon,
        'z_bottom': float(z_bottom),
        'z_top': float(z_top),
        'volume': float(props['volume']),
        'centroid': props['centroid'],
        'bbox': props['bbox']
    }
    
    # Add metadata if provided
    if metadata:
        solid_data.update(metadata)
    
    return solid_data


def perform_boolean_union(shapes, precision=1e-6):
    """
    Perform union (fuse) operation on multiple shapes
    
    Args:
        shapes: List of TopoDS_Shape objects
        precision: Geometric tolerance
    
    Returns:
        TopoDS_Shape: Fused shape
    """
    if not shapes:
        raise ValueError("No shapes provided for union operation")
    
    if len(shapes) == 1:
        return shapes[0]
    
    # Start with first shape
    result = shapes[0]
    
    # Fuse with remaining shapes
    for i, shape in enumerate(shapes[1:], start=1):
        try:
            fuse_op = BRepAlgoAPI_Fuse(result, shape)
            fuse_op.SetFuzzyValue(precision)
            fuse_op.Build()
            
            if not fuse_op.IsDone():
                print(f"Warning: Union operation {i} failed", file=sys.stderr)
                continue
            
            result = fuse_op.Shape()
            
        except Exception as e:
            print(f"Warning: Union operation {i} raised exception: {e}", file=sys.stderr)
            continue
    
    return result


def perform_boolean_intersection(shapes, precision=1e-6):
    """
    Perform intersection (common) operation on multiple shapes
    
    Args:
        shapes: List of TopoDS_Shape objects
        precision: Geometric tolerance
    
    Returns:
        TopoDS_Shape: Intersected shape
    """
    if not shapes:
        raise ValueError("No shapes provided for intersection operation")
    
    if len(shapes) == 1:
        return shapes[0]
    
    # Start with first shape
    result = shapes[0]
    
    # Intersect with remaining shapes
    for i, shape in enumerate(shapes[1:], start=1):
        try:
            common_op = BRepAlgoAPI_Common(result, shape)
            common_op.SetFuzzyValue(precision)
            common_op.Build()
            
            if not common_op.IsDone():
                print(f"Warning: Intersection operation {i} failed", file=sys.stderr)
                continue
            
            result = common_op.Shape()
            
        except Exception as e:
            print(f"Warning: Intersection operation {i} raised exception: {e}", file=sys.stderr)
            continue
    
    return result


def perform_boolean_difference(base_shape, tool_shapes, precision=1e-6):
    """
    Perform difference (cut) operation - subtract tool shapes from base
    
    Args:
        base_shape: TopoDS_Shape (base solid)
        tool_shapes: List of TopoDS_Shape objects to subtract
        precision: Geometric tolerance
    
    Returns:
        TopoDS_Shape: Result after subtraction
    """
    if not tool_shapes:
        return base_shape
    
    result = base_shape
    
    # Subtract each tool shape
    for i, tool in enumerate(tool_shapes):
        try:
            cut_op = BRepAlgoAPI_Cut(result, tool)
            cut_op.SetFuzzyValue(precision)
            cut_op.Build()
            
            if not cut_op.IsDone():
                print(f"Warning: Difference operation {i} failed", file=sys.stderr)
                continue
            
            result = cut_op.Shape()
            
        except Exception as e:
            print(f"Warning: Difference operation {i} raised exception: {e}", file=sys.stderr)
            continue
    
    return result


def group_by_material_and_continuity(solids, precision=1e-6):
    """
    Group solids by material and vertical continuity
    
    Solids with the same material and vertically adjacent z-ranges are grouped
    together for merging. This allows vertical structures like VIAs to be merged
    into single continuous objects.
    
    Args:
        solids: List of solid data dictionaries
        precision: Geometric tolerance for z-coordinate matching
    
    Returns:
        dict: Groups indexed by group key
    """
    # First, group by material
    material_groups = {}
    for solid_data in solids:
        material = solid_data.get('material', 'unknown')
        
        if material not in material_groups:
            material_groups[material] = []
        
        material_groups[material].append(solid_data)
    
    # Now, for each material, find vertically continuous chains
    groups = {}
    group_id = 0
    
    for material, mat_solids in material_groups.items():
        # Sort by z_bottom
        mat_solids.sort(key=lambda s: s.get('z_bottom', 0))
        
        # Check for vertical continuity and same footprint
        visited = [False] * len(mat_solids)
        
        for i in range(len(mat_solids)):
            if visited[i]:
                continue
            
            # Start a new group with this solid
            group = [mat_solids[i]]
            visited[i] = True
            
            # Try to extend the group downward (higher indices, higher z)
            for j in range(i + 1, len(mat_solids)):
                if visited[j]:
                    continue
                
                # Check if j is vertically adjacent to any solid in current group
                for group_solid in group:
                    z_gap = abs(mat_solids[j]['z_bottom'] - group_solid['z_top'])
                    
                    if z_gap < precision:
                        # Check if footprints match (same polygon)
                        if polygons_match(mat_solids[j]['polygon'], 
                                        group_solid['polygon'], 
                                        precision):
                            group.append(mat_solids[j])
                            visited[j] = True
                            break
            
            # Store this group
            if len(group) > 1:
                # This is a vertically continuous group - merge them
                group_key = f"material_{material}_group_{group_id}"
                z_min = min(s['z_bottom'] for s in group)
                z_max = max(s['z_top'] for s in group)
                
                groups[group_key] = {
                    'solids': group,
                    'metadata': {
                        'layer_name': f"{material}_continuous",
                        'z_bottom': z_min,
                        'z_top': z_max,
                        'material': material,
                        'color': group[0].get('color', ''),
                        'merged': True
                    }
                }
                group_id += 1
            else:
                # Single solid, use original grouping
                s = group[0]
                layer_name = s.get('layer_name', 'default')
                z_bottom = s.get('z_bottom', 0)
                z_top = s.get('z_top', 0)
                group_key = f"{layer_name}_{z_bottom}_{z_top}"
                
                groups[group_key] = {
                    'solids': [s],
                    'metadata': {
                        'layer_name': layer_name,
                        'z_bottom': z_bottom,
                        'z_top': z_top,
                        'material': material,
                        'color': s.get('color', ''),
                        'merged': False
                    }
                }
    
    return groups


def polygons_match(poly1, poly2, precision=1e-6):
    """
    Check if two polygons have the same footprint
    
    Args:
        poly1, poly2: Lists of [x, y] coordinates
        precision: Tolerance for coordinate comparison
    
    Returns:
        bool: True if polygons match
    """
    if len(poly1) != len(poly2):
        return False
    
    # Simple check: compare all vertices
    # This assumes polygons are in the same order
    for p1, p2 in zip(poly1, poly2):
        if abs(p1[0] - p2[0]) > precision or abs(p1[1] - p2[1]) > precision:
            return False
    
    return True


def merge_solids_by_layer(solids_data, operation='union', precision=1e-6, use_material_grouping=True):
    """
    Merge solids by layer, performing boolean operations within each layer
    
    Args:
        solids_data: Dictionary with 'solids' list
        operation: 'union', 'intersection', or 'difference'
        precision: Geometric tolerance
        use_material_grouping: If True, group by material+continuity; else use layer names
    
    Returns:
        dict: Merged solids data
    """
    solids = solids_data.get('solids', [])
    
    if not solids:
        return {
            'success': False,
            'error': 'No solids provided',
            'merged_solids': []
        }
    
    # Choose grouping strategy
    if use_material_grouping:
        layers = group_by_material_and_continuity(solids, precision)
        print(f"Grouped {len(solids)} solids into {len(layers)} groups (material-based)")
    else:
        # Original layer-based grouping
        layers = {}
        for solid_data in solids:
            layer_name = solid_data.get('layer_name', 'default')
            z_bottom = solid_data.get('z_bottom', 0)
            z_top = solid_data.get('z_top', 0)
            
            # Create layer key including z-coordinates
            layer_key = f"{layer_name}_{z_bottom}_{z_top}"
            
            if layer_key not in layers:
                layers[layer_key] = {
                    'solids': [],
                    'metadata': {
                        'layer_name': layer_name,
                        'z_bottom': z_bottom,
                        'z_top': z_top,
                        'material': solid_data.get('material', ''),
                        'color': solid_data.get('color', '')
                    }
                }
            
            layers[layer_key]['solids'].append(solid_data)
        
        print(f"Grouped {len(solids)} solids into {len(layers)} layers (layer-based)")
    
    merged_solids = []
    
    # Process each layer
    for layer_key, layer_info in layers.items():
        layer_solids = layer_info['solids']
        metadata = layer_info['metadata']
        
        print(f"\nProcessing layer: {metadata['layer_name']} "
              f"(z: {metadata['z_bottom']} to {metadata['z_top']})")
        print(f"  Input solids: {len(layer_solids)}")
        
        if len(layer_solids) == 1:
            # Only one solid, no merging needed
            merged_solids.append(layer_solids[0])
            continue
        
        try:
            # Create OCC shapes from solid data
            shapes = []
            for solid_data in layer_solids:
                shape = create_extruded_solid(
                    solid_data['polygon'],
                    solid_data['z_bottom'],
                    solid_data['z_top']
                )
                shapes.append(shape)
            
            # Perform boolean operation
            if operation == 'union':
                merged_shape = perform_boolean_union(shapes, precision)
            elif operation == 'intersection':
                merged_shape = perform_boolean_intersection(shapes, precision)
            elif operation == 'difference':
                if len(shapes) < 2:
                    merged_shape = shapes[0]
                else:
                    merged_shape = perform_boolean_difference(shapes[0], shapes[1:], precision)
            else:
                raise ValueError(f"Unknown operation: {operation}")
            
            # Convert back to solid data
            # For vertically merged solids with same footprint, use original polygon
            if len(layer_solids) > 1 and metadata.get('merged', False):
                # Use polygon from first solid (they all match)
                original_polygon = layer_solids[0]['polygon']
                merged_solid = {
                    'polygon': original_polygon,
                    'z_bottom': float(metadata['z_bottom']),
                    'z_top': float(metadata['z_top'])
                }
                # Add metadata
                merged_solid.update(metadata)
            else:
                # Extract polygon from merged shape for other cases
                merged_solid = shape_to_solid_data(
                    merged_shape,
                    metadata['z_bottom'],
                    metadata['z_top'],
                    metadata
                )
            
            merged_solids.append(merged_solid)
            print(f"  Output solids: 1 (merged)")
            
        except Exception as e:
            print(f"Warning: Failed to merge layer {layer_key}: {e}", file=sys.stderr)
            # Fall back to keeping original solids
            merged_solids.extend(layer_solids)
    
    return {
        'success': True,
        'merged_solids': merged_solids,
        'statistics': {
            'input_count': len(solids),
            'output_count': len(merged_solids),
            'operation': operation,
            'layers_processed': len(layers)
        }
    }


def main():
    """Main entry point"""
    if len(sys.argv) != 4:
        print("Usage: python3 boolean_ops.py input.json output.json operation", 
              file=sys.stderr)
        print("Operations: union, intersection, difference", file=sys.stderr)
        sys.exit(1)
    
    input_json = sys.argv[1]
    output_json = sys.argv[2]
    operation = sys.argv[3].lower()
    
    # Validate operation
    if operation not in ['union', 'intersection', 'difference']:
        print(f"Error: Invalid operation '{operation}'", file=sys.stderr)
        print("Valid operations: union, intersection, difference", file=sys.stderr)
        sys.exit(1)
    
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
        
        # Get precision if specified
        precision = solids_data.get('precision', 1e-6)
        
        # Perform boolean operations
        result = merge_solids_by_layer(solids_data, operation, precision)
        
        # Write output JSON
        with open(output_json, 'w') as f:
            json.dump(result, f, indent=2)
        
        if result['success']:
            print(f"\nBoolean operation completed successfully!")
            print(f"Input solids: {result['statistics']['input_count']}")
            print(f"Output solids: {result['statistics']['output_count']}")
            print(f"Output written to: {output_json}")
            sys.exit(0)
        else:
            print(f"Error: {result.get('error', 'Unknown error')}", file=sys.stderr)
            sys.exit(1)
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
