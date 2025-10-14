/*
 * GDSII Parser Adapter
 *
 * This file provides conversion functions between the internal C/C++ GDSII structures
 * from the base project and the WASM-compatible structures optimized for JavaScript
 * interaction.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "../include/wasm-types.h"

// Include base project headers (adjust paths as needed)
#include "../../Basic/gdsio/gdstypes.h"
#include "../../Basic/gdsio/eldata.h"

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Calculate the total memory needed for a WASM library
 */
static size_t calculate_wasm_library_size(gds_library_t* internal_lib) {
    if (!internal_lib) return 0;

    size_t size = sizeof(wasm_library_t);

    // Add space for structures
    size += internal_lib->structure_count * sizeof(wasm_structure_t);

    // Add space for elements in all structures
    for (int i = 0; i < internal_lib->structure_count; i++) {
        gds_structure_t* internal_struct = &internal_lib->structures[i];
        size += internal_struct->element_count * sizeof(wasm_element_t);

        // Add space for element geometry
        for (int j = 0; j < internal_struct->element_count; j++) {
            element_t* internal_el = &internal_struct->elements[j];

            // Estimate geometry size based on element type
            if (internal_el->kind == GDS_BOUNDARY || internal_el->kind == GDS_PATH) {
                size += sizeof(wasm_geometry_t);
                // Rough estimate for polygons (will be calculated precisely in conversion)
                size += 1000 * sizeof(wasm_vertex_t); // Arbitrary estimate
            }
        }
    }

    return size * 2; // Double for safety margin
}

/**
 * Initialize a WASM bounding box
 */
static void init_wasm_bbox(wasm_bbox_t* bbox) {
    if (bbox) {
        bbox->min_x = INFINITY;
        bbox->min_y = INFINITY;
        bbox->max_x = -INFINITY;
        bbox->max_y = -INFINITY;
    }
}

/**
 * Expand a WASM bounding box to include a vertex
 */
static void expand_wasm_bbox(wasm_bbox_t* bbox, const wasm_vertex_t* vertex) {
    if (!bbox || !vertex) return;

    if (vertex->x < bbox->min_x) bbox->min_x = vertex->x;
    if (vertex->y < bbox->min_y) bbox->min_y = vertex->y;
    if (vertex->x > bbox->max_x) bbox->max_x = vertex->x;
    if (vertex->y > bbox->max_y) bbox->max_y = vertex->y;
}

/**
 * Convert internal vertex to WASM vertex
 */
static void convert_vertex(const int32_t* internal_vertex, wasm_vertex_t* wasm_vertex, double dbu_to_uu) {
    if (internal_vertex && wasm_vertex) {
        wasm_vertex->x = (float)(internal_vertex[0] * dbu_to_uu);
        wasm_vertex->y = (float)(internal_vertex[1] * dbu_to_uu);
    }
}

// ============================================================================
// ELEMENT CONVERSION FUNCTIONS
// ============================================================================

/**
 * Convert internal boundary element to WASM boundary element
 */
static int convert_boundary_element(element_t* internal_el, wasm_element_t* wasm_el, double dbu_to_uu) {
    if (!internal_el || !wasm_el) return 0;

    wasm_el->kind = WASM_ELEMENT_BOUNDARY;
    wasm_el->layer = internal_el->layer;
    wasm_el->data_type = internal_el->dtype;
    wasm_el->elflags = internal_el->elflags;
    wasm_el->plex = internal_el->plex;

    // For boundary elements, we need to extract polygons from the internal data
    // This is a simplified implementation - in reality, we'd need to parse the
    // MATLAB cell array structure from the internal element data

    // Mock implementation - create a single polygon
    wasm_el->geometry.polygon_count = 1;
    wasm_el->geometry.vertex_counts = (int*)malloc(sizeof(int));
    wasm_el->geometry.vertex_counts[0] = 4; // Assume 4 vertices for demo

    wasm_el->geometry.polygons = (wasm_vertex_t**)malloc(sizeof(wasm_vertex_t*));
    wasm_el->geometry.polygons[0] = (wasm_vertex_t*)malloc(4 * sizeof(wasm_vertex_t));

    // Mock vertices (in reality, these would come from the internal element)
    wasm_el->geometry.polygons[0][0].x = -100.0f;
    wasm_el->geometry.polygons[0][0].y = -100.0f;
    wasm_el->geometry.polygons[0][1].x = 100.0f;
    wasm_el->geometry.polygons[0][1].y = -100.0f;
    wasm_el->geometry.polygons[0][2].x = 100.0f;
    wasm_el->geometry.polygons[0][2].y = 100.0f;
    wasm_el->geometry.polygons[0][3].x = -100.0f;
    wasm_el->geometry.polygons[0][3].y = 100.0f;

    wasm_el->geometry.total_vertex_count = 4;

    // Calculate bounding box
    init_wasm_bbox(&wasm_el->bounds);
    for (int i = 0; i < 4; i++) {
        expand_wasm_bbox(&wasm_el->bounds, &wasm_el->geometry.polygons[0][i]);
    }

    // Initialize properties (empty for now)
    wasm_el->property_count = 0;
    wasm_el->properties = NULL;

    return 1;
}

/**
 * Convert internal path element to WASM path element
 */
static int convert_path_element(element_t* internal_el, wasm_element_t* wasm_el, double dbu_to_uu) {
    if (!internal_el || !wasm_el) return 0;

    wasm_el->kind = WASM_ELEMENT_PATH;
    wasm_el->layer = internal_el->layer;
    wasm_el->data_type = internal_el->dtype;
    wasm_el->elflags = internal_el->elflags;
    wasm_el->plex = internal_el->plex;

    // Path-specific data
    wasm_el->element_specific.path_data.path_type = internal_el->ptype;
    wasm_el->element_specific.path_data.width = internal_el->width;
    wasm_el->element_specific.path_data.begin_extension = internal_el->bgnextn;
    wasm_el->element_specific.path_data.end_extension = internal_el->endextn;

    // Mock path geometry (similar to boundary)
    wasm_el->geometry.polygon_count = 1;
    wasm_el->geometry.vertex_counts = (int*)malloc(sizeof(int));
    wasm_el->geometry.vertex_counts[0] = 2; // Path with 2 vertices

    wasm_el->geometry.polygons = (wasm_vertex_t**)malloc(sizeof(wasm_vertex_t*));
    wasm_el->geometry.polygons[0] = (wasm_vertex_t*)malloc(2 * sizeof(wasm_vertex_t));

    // Mock path vertices
    wasm_el->geometry.polygons[0][0].x = -150.0f;
    wasm_el->geometry.polygons[0][0].y = 0.0f;
    wasm_el->geometry.polygons[0][1].x = 150.0f;
    wasm_el->geometry.polygons[0][1].y = 0.0f;

    wasm_el->geometry.total_vertex_count = 2;

    // Calculate bounding box
    init_wasm_bbox(&wasm_el->bounds);
    for (int i = 0; i < 2; i++) {
        expand_wasm_bbox(&wasm_el->bounds, &wasm_el->geometry.polygons[0][i]);
    }

    // Initialize properties
    wasm_el->property_count = 0;
    wasm_el->properties = NULL;

    return 1;
}

/**
 * Convert internal text element to WASM text element
 */
static int convert_text_element(element_t* internal_el, wasm_element_t* wasm_el, double dbu_to_uu) {
    if (!internal_el || !wasm_el) return 0;

    wasm_el->kind = WASM_ELEMENT_TEXT;
    wasm_el->layer = internal_el->layer;
    wasm_el->data_type = internal_el->dtype;
    wasm_el->elflags = internal_el->elflags;
    wasm_el->plex = internal_el->plex;

    // Text-specific data
    wasm_el->element_specific.text_data.text_type = internal_el->ttype;
    strcpy(wasm_el->element_specific.text_data.text_string, "Sample Text"); // Mock text

    // Mock position
    wasm_el->element_specific.text_data.position.x = 0.0f;
    wasm_el->element_specific.text_data.position.y = 0.0f;

    // Mock presentation
    wasm_el->element_specific.text_data.presentation.font = 0;
    wasm_el->element_specific.text_data.presentation.vertical_justification = 0;
    wasm_el->element_specific.text_data.presentation.horizontal_justification = 0;

    // Mock transformation
    wasm_el->element_specific.text_data.transformation.flags = 0;
    wasm_el->element_specific.text_data.transformation.magnification = 1.0f;
    wasm_el->element_specific.text_data.transformation.angle = 0.0f;

    // Text elements don't have geometry in the traditional sense
    wasm_el->geometry.polygon_count = 0;
    wasm_el->geometry.vertex_counts = NULL;
    wasm_el->geometry.polygons = NULL;
    wasm_el->geometry.total_vertex_count = 0;

    // Calculate bounding box (rough estimate for text)
    init_wasm_bbox(&wasm_el->bounds);
    wasm_vertex_t text_min = { -10.0f, -5.0f };
    wasm_vertex_t text_max = { 10.0f, 5.0f };
    expand_wasm_bbox(&wasm_el->bounds, &text_min);
    expand_wasm_bbox(&wasm_el->bounds, &text_max);

    // Initialize properties
    wasm_el->property_count = 0;
    wasm_el->properties = NULL;

    return 1;
}

/**
 * Convert internal SREF element to WASM SREF element
 */
static int convert_sref_element(element_t* internal_el, wasm_element_t* wasm_el, double dbu_to_uu) {
    if (!internal_el || !wasm_el) return 0;

    wasm_el->kind = WASM_ELEMENT_SREF;
    wasm_el->layer = 0; // SREF elements don't have layers
    wasm_el->data_type = 0;
    wasm_el->elflags = internal_el->elflags;
    wasm_el->plex = internal_el->plex;

    // SREF-specific data
    strcpy(wasm_el->element_specific.sref_data.structure_name, "ReferencedCell"); // Mock name

    // Mock single position
    wasm_el->element_specific.sref_data.position_count = 1;
    wasm_el->element_specific.sref_data.positions = (wasm_vertex_t*)malloc(sizeof(wasm_vertex_t));
    wasm_el->element_specific.sref_data.positions[0].x = 0.0f;
    wasm_el->element_specific.sref_data.positions[0].y = 0.0f;

    // Copy transformation
    wasm_el->element_specific.sref_data.transformation.flags = internal_el->strans.flags;
    wasm_el->element_specific.sref_data.transformation.magnification = internal_el->strans.mag;
    wasm_el->element_specific.sref_data.transformation.angle = internal_el->strans.angle;

    // SREF elements don't have geometry
    wasm_el->geometry.polygon_count = 0;
    wasm_el->geometry.vertex_counts = NULL;
    wasm_el->geometry.polygons = NULL;
    wasm_el->geometry.total_vertex_count = 0;

    // Calculate bounding box (rough estimate)
    init_wasm_bbox(&wasm_el->bounds);
    expand_wasm_bbox(&wasm_el->bounds, &wasm_el->element_specific.sref_data.positions[0]);

    // Initialize properties
    wasm_el->property_count = 0;
    wasm_el->properties = NULL;

    return 1;
}

/**
 * Convert internal AREF element to WASM AREF element
 */
static int convert_aref_element(element_t* internal_el, wasm_element_t* wasm_el, double dbu_to_uu) {
    if (!internal_el || !wasm_el) return 0;

    wasm_el->kind = WASM_ELEMENT_AREF;
    wasm_el->layer = 0; // AREF elements don't have layers
    wasm_el->data_type = 0;
    wasm_el->elflags = internal_el->elflags;
    wasm_el->plex = internal_el->plex;

    // AREF-specific data
    strcpy(wasm_el->element_specific.aref_data.structure_name, "ReferencedCell"); // Mock name
    wasm_el->element_specific.aref_data.columns = internal_el->ncol;
    wasm_el->element_specific.aref_data.rows = internal_el->nrow;

    // Mock corners (origin, column vector, row vector)
    wasm_el->element_specific.aref_data.corners[0].x = 0.0f;  // Origin
    wasm_el->element_specific.aref_data.corners[0].y = 0.0f;
    wasm_el->element_specific.aref_data.corners[1].x = 10.0f; // Column spacing
    wasm_el->element_specific.aref_data.corners[1].y = 0.0f;
    wasm_el->element_specific.aref_data.corners[2].x = 0.0f;  // Row spacing
    wasm_el->element_specific.aref_data.corners[2].y = 10.0f;

    // Copy transformation
    wasm_el->element_specific.aref_data.transformation.flags = internal_el->strans.flags;
    wasm_el->element_specific.aref_data.transformation.magnification = internal_el->strans.mag;
    wasm_el->element_specific.aref_data.transformation.angle = internal_el->strans.angle;

    // AREF elements don't have geometry
    wasm_el->geometry.polygon_count = 0;
    wasm_el->geometry.vertex_counts = NULL;
    wasm_el->geometry.polygons = NULL;
    wasm_el->geometry.total_vertex_count = 0;

    // Calculate bounding box based on array extent
    init_wasm_bbox(&wasm_el->bounds);
    for (int i = 0; i < 3; i++) {
        expand_wasm_bbox(&wasm_el->bounds, &wasm_el->element_specific.aref_data.corners[i]);
    }

    // Initialize properties
    wasm_el->property_count = 0;
    wasm_el->properties = NULL;

    return 1;
}

// ============================================================================
// STRUCTURE CONVERSION FUNCTIONS
// ============================================================================

/**
 * Convert internal structure to WASM structure
 */
static int convert_structure(gds_structure_t* internal_struct, wasm_structure_t* wasm_struct, double dbu_to_uu) {
    if (!internal_struct || !wasm_struct) return 0;

    // Copy structure name
    strncpy(wasm_struct->name, internal_struct->sname, WASM_MAX_STRUCTURE_NAME - 1);
    wasm_struct->name[WASM_MAX_STRUCTURE_NAME - 1] = '\0';

    // Convert elements
    wasm_struct->element_count = internal_struct->el_count;
    if (wasm_struct->element_count > 0) {
        wasm_struct->elements = (wasm_element_t*)malloc(wasm_struct->element_count * sizeof(wasm_element_t));
        if (!wasm_struct->elements) return 0;

        // Initialize structure bounding box
        init_wasm_bbox(&wasm_struct->total_bounds);

        // Convert each element
        for (int i = 0; i < wasm_struct->element_count; i++) {
            element_t* internal_el = &internal_struct->el[i];
            wasm_element_t* wasm_el = &wasm_struct->elements[i];

            // Convert based on element type
            int conversion_result = 0;
            switch (internal_el->kind) {
                case GDS_BOUNDARY:
                    conversion_result = convert_boundary_element(internal_el, wasm_el, dbu_to_uu);
                    break;
                case GDS_PATH:
                    conversion_result = convert_path_element(internal_el, wasm_el, dbu_to_uu);
                    break;
                case GDS_TEXT:
                    conversion_result = convert_text_element(internal_el, wasm_el, dbu_to_uu);
                    break;
                case GDS_SREF:
                    conversion_result = convert_sref_element(internal_el, wasm_el, dbu_to_uu);
                    break;
                case GDS_AREF:
                    conversion_result = convert_aref_element(internal_el, wasm_el, dbu_to_uu);
                    break;
                default:
                    // Unsupported element type - skip
                    wasm_el->kind = WASM_ELEMENT_BOUNDARY; // Default
                    conversion_result = 0;
                    break;
            }

            // Expand structure bounding box with element bounds
            if (conversion_result) {
                expand_wasm_bbox(&wasm_struct->total_bounds, &wasm_el->bounds.min_x);
                expand_wasm_bbox(&wasm_struct->total_bounds, &wasm_el->bounds.max_x);
            }
        }
    } else {
        wasm_struct->elements = NULL;
    }

    // Initialize references (empty for now)
    wasm_struct->reference_count = 0;
    wasm_struct->references = NULL;

    return 1;
}

// ============================================================================
// LIBRARY CONVERSION FUNCTIONS
// ============================================================================

/**
 * Create WASM library from internal library
 */
wasm_library_t* create_wasm_library(gds_library_t* internal_lib) {
    if (!internal_lib) return NULL;

    // Allocate WASM library structure
    wasm_library_t* wasm_lib = (wasm_library_t*)malloc(sizeof(wasm_library_t));
    if (!wasm_lib) return NULL;

    // Initialize with zeros
    memset(wasm_lib, 0, sizeof(wasm_library_t));

    // Copy library metadata
    strncpy(wasm_lib->name, internal_lib->lname, WASM_MAX_STRUCTURE_NAME - 1);
    wasm_lib->name[WASM_MAX_STRUCTURE_NAME - 1] = '\0';

    // Copy units
    wasm_lib->user_units_per_db_unit = internal_lib->uunit;
    wasm_lib->meters_per_db_unit = internal_lib->dbunit;

    // Copy structure count
    wasm_lib->structure_count = internal_lib->st_count;

    // Convert structures
    if (wasm_lib->structure_count > 0) {
        wasm_lib->structures = (wasm_structure_t*)malloc(wasm_lib->structure_count * sizeof(wasm_structure_t));
        if (!wasm_lib->structures) {
            free(wasm_lib);
            return NULL;
        }

        // Convert each structure
        for (int i = 0; i < wasm_lib->structure_count; i++) {
            gds_structure_t* internal_struct = &internal_lib->st[i];
            wasm_structure_t* wasm_struct = &wasm_lib->structures[i];

            if (!convert_structure(internal_struct, wasm_struct, wasm_lib->user_units_per_db_unit)) {
                // Cleanup on failure
                for (int j = 0; j < i; j++) {
                    free(wasm_lib->structures[j].elements);
                    free(wasm_lib->structures[j].references);
                }
                free(wasm_lib->structures);
                free(wasm_lib);
                return NULL;
            }
        }
    } else {
        wasm_lib->structures = NULL;
    }

    // Initialize reference libraries and fonts (empty for now)
    wasm_lib->ref_lib_count = 0;
    wasm_lib->font_count = 0;
    for (int i = 0; i < WASM_MAX_REFERENCE_LIBRARIES; i++) {
        wasm_lib->ref_libraries[i] = NULL;
    }
    for (int i = 0; i < WASM_MAX_FONTS; i++) {
        wasm_lib->fonts[i] = NULL;
    }

    return wasm_lib;
}

// ============================================================================
// MEMORY MANAGEMENT FUNCTIONS
// ============================================================================

/**
 * Free WASM library and all allocated memory
 */
void free_wasm_library(wasm_library_t* wasm_lib) {
    if (!wasm_lib) return;

    // Free structures
    if (wasm_lib->structures) {
        for (int i = 0; i < wasm_lib->structure_count; i++) {
            wasm_structure_t* structure = &wasm_lib->structures[i];

            // Free elements
            if (structure->elements) {
                for (int j = 0; j < structure->element_count; j++) {
                    wasm_element_t* element = &structure->elements[j];

                    // Free geometry
                    if (element->geometry.polygons) {
                        for (int k = 0; k < element->geometry.polygon_count; k++) {
                            if (element->geometry.polygons[k]) {
                                free(element->geometry.polygons[k]);
                            }
                        }
                        free(element->geometry.polygons);
                    }

                    if (element->geometry.vertex_counts) {
                        free(element->geometry.vertex_counts);
                    }

                    // Free properties
                    if (element->properties) {
                        free(element->properties);
                    }

                    // Free reference-specific data
                    if (element->kind == WASM_ELEMENT_SREF && element->element_specific.sref_data.positions) {
                        free(element->element_specific.sref_data.positions);
                    }
                }
                free(structure->elements);
            }

            // Free references
            if (structure->references) {
                for (int k = 0; k < structure->reference_count; k++) {
                    if (structure->references[k].instance_bounds) {
                        free(structure->references[k].instance_bounds);
                    }
                }
                free(structure->references);
            }
        }
        free(wasm_lib->structures);
    }

    // Free reference libraries
    for (int i = 0; i < wasm_lib->ref_lib_count; i++) {
        if (wasm_lib->ref_libraries[i]) {
            free(wasm_lib->ref_libraries[i]);
        }
    }

    // Free fonts
    for (int i = 0; i < wasm_lib->font_count; i++) {
        if (wasm_lib->fonts[i]) {
            free(wasm_lib->fonts[i]);
        }
    }

    free(wasm_lib);
}

/**
 * Validate WASM library structure
 */
int validate_wasm_library(wasm_library_t* lib) {
    if (!lib) return 0;

    // Validate name
    if (strlen(lib->name) == 0) return 0;

    // Validate units
    if (lib->user_units_per_db_unit <= 0 || lib->meters_per_db_unit <= 0) {
        return 0;
    }

    // Validate structure count
    if (lib->structure_count < 0) return 0;

    // Validate structures
    for (int i = 0; i < lib->structure_count; i++) {
        wasm_structure_t* structure = &lib->structures[i];

        // Validate structure name
        if (strlen(structure->name) == 0) return 0;

        // Validate element count
        if (structure->element_count < 0) return 0;

        // Validate elements
        for (int j = 0; j < structure->element_count; j++) {
            wasm_element_t* element = &structure->elements[j];

            // Validate element kind
            if (element->kind < WASM_ELEMENT_BOUNDARY || element->kind > WASM_ELEMENT_AREF) {
                return 0;
            }

            // Validate layer (except for reference elements)
            if (element->kind != WASM_ELEMENT_SREF && element->kind != WASM_ELEMENT_AREF) {
                if (element->layer < 0 || element->layer > 255) return 0;
            }

            // Validate geometry
            if (element->geometry.polygon_count < 0) return 0;
            if (element->geometry.polygon_count > 0 && !element->geometry.polygons) return 0;
        }
    }

    return 1;
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Calculate estimated memory usage for a WASM library
 */
size_t calculate_wasm_memory_usage(wasm_library_t* lib) {
    if (!lib) return 0;

    size_t total_size = sizeof(wasm_library_t);

    // Add structure sizes
    total_size += lib->structure_count * sizeof(wasm_structure_t);

    // Add element sizes
    for (int i = 0; i < lib->structure_count; i++) {
        wasm_structure_t* structure = &lib->structures[i];
        total_size += structure->element_count * sizeof(wasm_element_t);

        // Add geometry sizes
        for (int j = 0; j < structure->element_count; j++) {
            wasm_element_t* element = &structure->elements[j];

            if (element->geometry.polygon_count > 0) {
                total_size += element->geometry.polygon_count * sizeof(wasm_vertex_t*);
                total_size += element->geometry.polygon_count * sizeof(int);

                for (int k = 0; k < element->geometry.polygon_count; k++) {
                    total_size += element->geometry.vertex_counts[k] * sizeof(wasm_vertex_t);
                }
            }
        }
    }

    return total_size;
}

/**
 * Optimize WASM library layout for better memory access patterns
 */
void optimize_wasm_layout(wasm_library_t* lib) {
    if (!lib) return;

    // This function could be used to reorganize memory layout for better cache performance
    // For now, it's a placeholder for future optimization

    // Potential optimizations:
    // 1. Group elements by type for better cache locality
    // 2. Align data structures to cache line boundaries
    // 3. Precompute frequently accessed data
    // 4. Compress sparse data structures
}