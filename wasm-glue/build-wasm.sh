#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/gdsii-viewer/public"
INCLUDES=(-I"$SCRIPT_DIR/include" -I"$PROJECT_ROOT/Basic/gdsio")
SOURCES=(
  "$SCRIPT_DIR/src/gds-wasm-adapter.c"
  "$SCRIPT_DIR/src/wasm-element-cache.c"
  "$SCRIPT_DIR/src/wasm-memory-manager.c"
)

EXPORTED_FUNCTIONS='[_malloc,_free,_gds_parse_from_memory,_gds_free_library,_gds_get_library_name,_gds_get_user_units_per_db_unit,_gds_get_meters_per_db_unit,_gds_get_structure_count,_gds_get_structure_name,_gds_get_library_creation_date,_gds_get_library_modification_date,_gds_get_element_count,_gds_get_element_type,_gds_get_element_layer,_gds_get_element_data_type,_gds_get_element_elflags,_gds_get_element_plex,_gds_get_element_polygon_count,_gds_get_element_polygon_vertex_count,_gds_get_element_polygon_vertices,_gds_get_element_path_width,_gds_get_element_path_type,_gds_get_element_path_begin_extension,_gds_get_element_path_end_extension,_gds_get_element_text,_gds_get_element_text_position,_gds_get_element_text_type,_gds_get_element_text_presentation,_gds_get_element_reference_name,_gds_get_element_array_columns,_gds_get_element_array_rows,_gds_get_element_reference_corners,_gds_get_element_strans_flags,_gds_get_element_magnification,_gds_get_element_rotation_angle,_gds_get_element_property_count,_gds_get_element_property_attribute,_gds_get_element_property_value,_gds_get_last_error,_gds_clear_error,_gds_validate_library,_gds_get_memory_usage]'

COMMON="-s WASM=1 -s ALLOW_MEMORY_GROWTH=1 -s MODULARIZE=1 -s ENVIRONMENT='web' -s FILESYSTEM=0 -s EXPORTED_RUNTIME_METHODS=['ccall','cwrap','getValue','setValue','UTF8ToString','stringToUTF8','writeArrayToMemory'] -s EXPORTED_FUNCTIONS=$EXPORTED_FUNCTIONS"
RELEASE_FLAGS="-O3 -flto -s WASM_ASYNC_COMPILATION=0 -s ASSERTIONS=0 -s STACK_SIZE=2097152 -s INITIAL_MEMORY=67108864"
DEBUG_FLAGS="-O1 -g4 --source-map-base http://localhost:3000/ -s ASSERTIONS=1 -s STACK_SIZE=4194304 -s INITIAL_MEMORY=134217728"

mkdir -p "$OUTPUT_DIR"

case "${1:-release}" in
  release)
    emcc "${SOURCES[@]}" "${INCLUDES[@]}" -o "$OUTPUT_DIR/gds-parser.js" \
      $COMMON $RELEASE_FLAGS \
      -s EXPORT_NAME="'GDSParserModule'" \
      --pre-js "$SCRIPT_DIR/src/pre.js" \
      --post-js "$SCRIPT_DIR/src/post.js"
    ;;
  debug)
    emcc "${SOURCES[@]}" "${INCLUDES[@]}" -o "$OUTPUT_DIR/gds-parser-debug.js" \
      $COMMON $DEBUG_FLAGS \
      -s EXPORT_NAME="'GDSParserModuleDebug'" \
      --pre-js "$SCRIPT_DIR/src/pre-debug.js"
    ;;
  clean)
    rm -f "$OUTPUT_DIR/gds-parser.js" "$OUTPUT_DIR/gds-parser.wasm" \
          "$OUTPUT_DIR/gds-parser-debug.js" "$OUTPUT_DIR/gds-parser-debug.wasm"
    ;;
  *)
    echo "Usage: $0 [release|debug|clean]" >&2
    exit 1
    ;;
esac

echo "Built outputs in $OUTPUT_DIR"