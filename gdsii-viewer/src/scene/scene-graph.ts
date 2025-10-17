/**
 * Scene Graph Manager
 * 
 * Manages the scene representation with spatial indexing for efficient queries.
 * Coordinates between the data model (GDSLibrary) and rendering system.
 */

import type {
  GDSLibrary,
  GDSStructure,
  GDSElement,
  GDSBBox,
  GDSPoint,
  GDSLayer
} from '../gdsii-types';

import {
  calculateElementBBox,
  mergeBBoxes,
  createEmptyBBox,
  isValidBBox
} from '../gdsii-utils';

import {
  QuadTree,
  createQuadTree,
  type SpatialElement
} from './spatial-index';

import { logger, LogCategory } from '../debug-logger';

/**
 * Viewport definition for culling
 */
export interface Viewport {
  center: GDSPoint;
  width: number;
  height: number;
  zoom: number;
}

/**
 * Layer group for organization
 */
export interface LayerGroup {
  layer: number;
  dataType: number;
  elements: SpatialElement[];
  visible: boolean;
  color: string;
}

/**
 * Scene statistics
 */
export interface SceneStatistics {
  totalElements: number;
  totalStructures: number;
  totalLayers: number;
  spatialIndexStats: {
    totalNodes: number;
    maxDepth: number;
    avgElementsPerNode: number;
  };
  bounds: GDSBBox;
}

/**
 * Scene Graph manages spatial organization of GDSII elements
 */
export class SceneGraph {
  private spatialIndex: QuadTree | null = null;
  private layerGroups: Map<string, LayerGroup> = new Map();
  private allElements: SpatialElement[] = [];
  private bounds: GDSBBox = createEmptyBBox();
  private library: GDSLibrary | null = null;

  /**
   * Builds the scene graph from a library and flattened structures
   */
  buildFromLibrary(
    library: GDSLibrary,
    flattenedStructures: Map<string, GDSElement[]>
  ): void {
    console.time('Scene Graph Build');
    logger.info(LogCategory.SCENE_GRAPH, 'Building scene graph...', {
      structures: flattenedStructures.size,
      totalElements: Array.from(flattenedStructures.values()).reduce((sum, els) => sum + els.length, 0)
    });

    this.library = library;
    this.clear();

    // Collect all elements with their bounding boxes
    const allSpatialElements: SpatialElement[] = [];
    let libraryBounds = createEmptyBBox();
    
    // Track element types for debugging
    const elementTypeCounts = new Map<string, number>();

    for (const [structureName, elements] of flattenedStructures) {
      logger.debug(LogCategory.SCENE_GRAPH, `Processing structure: ${structureName}`, {
        elementCount: elements.length
      });
      
      for (let i = 0; i < elements.length; i++) {
        const element = elements[i];
        
        // Track element types
        const typeKey = element.type;
        elementTypeCounts.set(typeKey, (elementTypeCounts.get(typeKey) || 0) + 1);
        
        // Skip reference elements (should be resolved already)
        if (element.type === 'sref' || element.type === 'aref') {
          logger.debug(LogCategory.SCENE_GRAPH, `Skipping reference element: ${element.type}`);
          continue;
        }

        // Calculate bounding box if not present
        const bounds = element.bounds || calculateElementBBox(element);
        
        if (!isValidBBox(bounds)) {
          logger.warn(LogCategory.SCENE_GRAPH, `Invalid bbox for element ${i} in ${structureName}`, {
            type: element.type,
            bounds
          });
          console.warn(`Invalid bbox for element ${i} in ${structureName}`);
          continue;
        }

        const spatialElement: SpatialElement = {
          element,
          bounds,
          structureName,
          elementIndex: i
        };

        allSpatialElements.push(spatialElement);
        libraryBounds = mergeBBoxes(libraryBounds, bounds);

        // Group by layer
        const layerKey = `${element.layer}_${element.dataType}`;
        if (!this.layerGroups.has(layerKey)) {
          this.layerGroups.set(layerKey, {
            layer: element.layer,
            dataType: element.dataType,
            elements: [],
            visible: true,
            color: '#888888' // Default color, will be overridden
          });
          logger.debug(LogCategory.SCENE_GRAPH, `Created layer group: ${layerKey}`);
        }
        this.layerGroups.get(layerKey)!.elements.push(spatialElement);
      }
    }
    
    logger.info(LogCategory.SCENE_GRAPH, 'Element type breakdown', {
      types: Object.fromEntries(elementTypeCounts)
    });

    this.allElements = allSpatialElements;
    this.bounds = libraryBounds;
    
    logger.info(LogCategory.SCENE_GRAPH, 'Spatial elements collected', {
      total: allSpatialElements.length,
      layerGroups: this.layerGroups.size,
      bounds: libraryBounds
    });

    // Build spatial index
    if (isValidBBox(libraryBounds)) {
      logger.debug(LogCategory.SPATIAL_INDEX, 'Building QuadTree...');
      // Add 10% padding to bounds for better edge handling
      const paddedBounds = this.padBounds(libraryBounds, 1.1);
      this.spatialIndex = createQuadTree(paddedBounds);
      
      logger.debug(LogCategory.SPATIAL_INDEX, 'Inserting elements into QuadTree...');
      for (const element of allSpatialElements) {
        this.spatialIndex.insert(element);
      }
      logger.info(LogCategory.SPATIAL_INDEX, 'QuadTree built', {
        elementCount: allSpatialElements.length
      });
    } else {
      logger.error(LogCategory.SPATIAL_INDEX, 'Cannot build QuadTree: invalid bounds', {
        bounds: libraryBounds
      });
    }

    const stats = this.getStatistics();
    logger.info(LogCategory.SCENE_GRAPH, 'Scene graph complete', stats);
    console.log(`✓ Scene graph built: ${stats.totalElements} elements, ` +
                `${stats.totalLayers} layers, ` +
                `${stats.spatialIndexStats.totalNodes} nodes`);
    console.timeEnd('Scene Graph Build');
  }

  /**
   * Queries elements visible in the viewport
   */
  queryViewport(viewport: Viewport): SpatialElement[] {
    if (!this.spatialIndex) {
      logger.warn(LogCategory.SPATIAL_INDEX, 'No spatial index available for query');
      return [];
    }

    const viewportBBox = this.viewportToBBox(viewport);
    logger.debug(LogCategory.SPATIAL_INDEX, 'Querying viewport', {
      viewport,
      bbox: viewportBBox
    });
    
    const results = this.spatialIndex.query(viewportBBox);
    
    // Deduplicate results (QuadTree can return same element multiple times)
    const uniqueElements = this.deduplicateSpatialElements(results);
    
    logger.debug(LogCategory.SPATIAL_INDEX, 'Viewport query results', {
      rawCount: results.length,
      uniqueCount: uniqueElements.length,
      duplicates: results.length - uniqueElements.length,
      totalElements: this.allElements.length
    });
    
    return uniqueElements;
  }

  /**
   * Queries elements at a specific point (for picking)
   */
  queryPoint(point: GDSPoint): SpatialElement[] {
    if (!this.spatialIndex) {
      return [];
    }

    const results = this.spatialIndex.queryPoint(point);
    return this.deduplicateSpatialElements(results);
  }

  /**
   * Queries elements in a rectangular region
   */
  queryRegion(bbox: GDSBBox): SpatialElement[] {
    if (!this.spatialIndex) {
      return [];
    }

    const results = this.spatialIndex.query(bbox);
    return this.deduplicateSpatialElements(results);
  }

  /**
   * Gets all elements for a specific layer
   */
  getLayerElements(layer: number, dataType: number = 0): SpatialElement[] {
    const layerKey = `${layer}_${dataType}`;
    const layerGroup = this.layerGroups.get(layerKey);
    return layerGroup ? layerGroup.elements : [];
  }

  /**
   * Sets layer visibility
   */
  setLayerVisible(layer: number, dataType: number, visible: boolean): void {
    const layerKey = `${layer}_${dataType}`;
    const layerGroup = this.layerGroups.get(layerKey);
    if (layerGroup) {
      layerGroup.visible = visible;
    }
  }

  /**
   * Sets layer color
   */
  setLayerColor(layer: number, dataType: number, color: string): void {
    const layerKey = `${layer}_${dataType}`;
    const layerGroup = this.layerGroups.get(layerKey);
    if (layerGroup) {
      layerGroup.color = color;
    }
  }

  /**
   * Gets all layer groups
   */
  getLayerGroups(): Map<string, LayerGroup> {
    return new Map(this.layerGroups);
  }

  /**
   * Gets the bounds of the entire scene
   */
  getBounds(): GDSBBox {
    return { ...this.bounds };
  }

  /**
   * Gets scene statistics
   */
  getStatistics(): SceneStatistics {
    const spatialIndexStats = this.spatialIndex
      ? this.spatialIndex.getStatistics()
      : { totalNodes: 0, maxDepth: 0, avgElementsPerNode: 0, totalElements: 0 };

    return {
      totalElements: this.allElements.length,
      totalStructures: this.library?.structures.length || 0,
      totalLayers: this.layerGroups.size,
      spatialIndexStats: {
        totalNodes: spatialIndexStats.totalNodes,
        maxDepth: spatialIndexStats.maxDepth,
        avgElementsPerNode: spatialIndexStats.avgElementsPerNode
      },
      bounds: this.bounds
    };
  }

  /**
   * Deduplicates spatial elements by creating unique keys
   * @private
   */
  private deduplicateSpatialElements(elements: SpatialElement[]): SpatialElement[] {
    // Use a Map with a unique key per element to deduplicate
    const uniqueMap = new Map<string, SpatialElement>();
    
    for (const element of elements) {
      // Create a unique key combining structure name and element index
      const key = `${element.structureName}_${element.elementIndex}`;
      if (!uniqueMap.has(key)) {
        uniqueMap.set(key, element);
      }
    }
    
    return Array.from(uniqueMap.values());
  }

  /**
   * Clears the scene graph
   */
  clear(): void {
    this.spatialIndex = null;
    this.layerGroups.clear();
    this.allElements = [];
    this.bounds = createEmptyBBox();
    this.library = null;
  }

  /**
   * Invalidates and rebuilds the spatial index
   */
  rebuildSpatialIndex(): void {
    if (this.allElements.length === 0 || !isValidBBox(this.bounds)) {
      return;
    }

    console.time('Spatial Index Rebuild');
    
    const paddedBounds = this.padBounds(this.bounds, 1.1);
    this.spatialIndex = createQuadTree(paddedBounds);

    for (const element of this.allElements) {
      this.spatialIndex.insert(element);
    }

    console.timeEnd('Spatial Index Rebuild');
  }

  /**
   * Converts viewport to bounding box
   */
  private viewportToBBox(viewport: Viewport): GDSBBox {
    const halfWidth = viewport.width / (2 * viewport.zoom);
    const halfHeight = viewport.height / (2 * viewport.zoom);

    return {
      minX: viewport.center.x - halfWidth,
      minY: viewport.center.y - halfHeight,
      maxX: viewport.center.x + halfWidth,
      maxY: viewport.center.y + halfHeight
    };
  }

  /**
   * Adds padding to bounds
   */
  private padBounds(bounds: GDSBBox, factor: number): GDSBBox {
    const width = bounds.maxX - bounds.minX;
    const height = bounds.maxY - bounds.minY;
    const centerX = (bounds.minX + bounds.maxX) / 2;
    const centerY = (bounds.minY + bounds.maxY) / 2;

    const newHalfWidth = (width * factor) / 2;
    const newHalfHeight = (height * factor) / 2;

    return {
      minX: centerX - newHalfWidth,
      minY: centerY - newHalfHeight,
      maxX: centerX + newHalfWidth,
      maxY: centerY + newHalfHeight
    };
  }

  /**
   * Gets library reference
   */
  getLibrary(): GDSLibrary | null {
    return this.library;
  }

  /**
   * Gets all spatial elements
   */
  getAllElements(): SpatialElement[] {
    return [...this.allElements];
  }

  /**
   * Tests culling efficiency for a viewport
   */
  testCullingEfficiency(viewport: Viewport): {
    totalElements: number;
    visibleElements: number;
    cullRate: number;
  } {
    const visibleElements = this.queryViewport(viewport);
    const cullRate = 1 - (visibleElements.length / this.allElements.length);

    return {
      totalElements: this.allElements.length,
      visibleElements: visibleElements.length,
      cullRate
    };
  }
}
