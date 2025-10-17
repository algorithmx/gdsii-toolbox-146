/**
 * Scene Module Exports
 * 
 * Central export point for scene graph and spatial indexing components.
 */

// Scene graph
export {
  SceneGraph,
  type Viewport,
  type LayerGroup,
  type SceneStatistics
} from './scene-graph';

// Spatial indexing
export {
  QuadTree,
  createQuadTree,
  buildQuadTree,
  type SpatialElement
} from './spatial-index';
