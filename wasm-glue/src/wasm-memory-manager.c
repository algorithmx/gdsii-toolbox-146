/*
 * WASM Memory Manager
 *
 * Provides centralized memory management for the WASM GDSII parser
 * with leak detection, usage tracking, and cleanup utilities.
 *
 * Copyright (c) 2025
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>
#include "wasm-element-cache.h"
#include "mem-file.h"

// ============================================================================
// MEMORY TRACKING STRUCTURES
// ============================================================================

typedef struct memory_allocation {
    void* ptr;
    size_t size;
    const char* file;
    int line;
    const char* function;
    struct memory_allocation* next;
} memory_allocation_t;

typedef struct {
    size_t total_allocated;
    size_t peak_usage;
    int allocation_count;
    int leak_count;

    memory_allocation_t* allocations;
    size_t max_allocations;

    // Statistics
    size_t cache_memory;
    size_t buffer_memory;
    size_t element_memory;

    int tracking_enabled;
    int debug_mode;
} wasm_memory_manager_t;

static wasm_memory_manager_t g_memory_manager = {0};

// ============================================================================
// MEMORY ALLOCATION TRACKING
// ============================================================================

static void track_allocation(void* ptr, size_t size, const char* file, int line, const char* function) {
    if (!g_memory_manager.tracking_enabled || !ptr) {
        return;
    }

    // Update statistics
    g_memory_manager.total_allocated += size;
    g_memory_manager.allocation_count++;

    if (g_memory_manager.total_allocated > g_memory_manager.peak_usage) {
        g_memory_manager.peak_usage = g_memory_manager.total_allocated;
    }

    // Add to allocation list
    memory_allocation_t* alloc = malloc(sizeof(memory_allocation_t));
    if (alloc) {
        alloc->ptr = ptr;
        alloc->size = size;
        alloc->file = file;
        alloc->line = line;
        alloc->function = function;
        alloc->next = g_memory_manager.allocations;
        g_memory_manager.allocations = alloc;
    }
}

static void untrack_allocation(void* ptr, const char* file, int line, const char* function) {
    if (!g_memory_manager.tracking_enabled || !ptr) {
        return;
    }

    memory_allocation_t** current = &g_memory_manager.allocations;
    while (*current) {
        if ((*current)->ptr == ptr) {
            memory_allocation_t* to_remove = *current;
            *current = (*current)->next;

            g_memory_manager.total_allocated -= to_remove->size;
            free(to_remove);
            return;
        }
        current = &(*current)->next;
    }

    if (g_memory_manager.debug_mode) {
        printf("WARNING: Attempting to free untracked pointer %p from %s:%d (%s)\n",
               ptr, file, line, function);
    }
}

// ============================================================================
// WRAPPER FUNCTIONS FOR MALLOC/FREE
// ============================================================================

void* wasm_malloc(size_t size, const char* file, int line, const char* function) {
    void* ptr = malloc(size);
    if (ptr) {
        track_allocation(ptr, size, file, line, function);
    }
    return ptr;
}

void* wasm_calloc(size_t count, size_t size, const char* file, int line, const char* function) {
    void* ptr = calloc(count, size);
    if (ptr) {
        track_allocation(ptr, count * size, file, line, function);
    }
    return ptr;
}

void* wasm_realloc(void* ptr, size_t new_size, const char* file, int line, const char* function) {
    if (ptr) {
        untrack_allocation(ptr, file, line, function);
    }

    void* new_ptr = realloc(ptr, new_size);
    if (new_ptr) {
        track_allocation(new_ptr, new_size, file, line, function);
    }

    return new_ptr;
}

void wasm_free(void* ptr, const char* file, int line, const char* function) {
    if (ptr) {
        untrack_allocation(ptr, file, line, function);
        free(ptr);
    }
}

// ============================================================================
// CONVENIENCE MACROS
// ============================================================================

#ifdef DEBUG
#define WASM_MALLOC(size) wasm_malloc(size, __FILE__, __LINE__, __FUNCTION__)
#define WASM_CALLOC(count, size) wasm_calloc(count, size, __FILE__, __LINE__, __FUNCTION__)
#define WASM_REALLOC(ptr, size) wasm_realloc(ptr, size, __FILE__, __LINE__, __FUNCTION__)
#define WASM_FREE(ptr) wasm_free(ptr, __FILE__, __LINE__, __FUNCTION__)
#else
#define WASM_MALLOC(size) wasm_malloc(size, NULL, 0, NULL)
#define WASM_CALLOC(count, size) wasm_calloc(count, size, NULL, 0, NULL)
#define WASM_REALLOC(ptr, size) wasm_realloc(ptr, size, NULL, 0, NULL)
#define WASM_FREE(ptr) wasm_free(ptr, NULL, 0, NULL)
#endif

// ============================================================================
// MEMORY MANAGER API
// ============================================================================

void wasm_memory_init(int enable_tracking, int debug_mode) {
    memset(&g_memory_manager, 0, sizeof(wasm_memory_manager_t));
    g_memory_manager.tracking_enabled = enable_tracking;
    g_memory_manager.debug_mode = debug_mode;
    g_memory_manager.max_allocations = 10000; // Max tracked allocations
}

void wasm_memory_shutdown(void) {
    if (g_memory_manager.tracking_enabled && g_memory_manager.allocations) {
        g_memory_manager.leak_count = 0;
        memory_allocation_t* current = g_memory_manager.allocations;

        while (current) {
            g_memory_manager.leak_count++;
            if (g_memory_manager.debug_mode) {
                printf("MEMORY LEAK: %zu bytes at %p allocated in %s (%s:%d)\n",
                       current->size, current->ptr, current->function,
                       current->file, current->line);
            }
            current = current->next;
        }

        if (g_memory_manager.leak_count > 0) {
            printf("WARNING: %d memory leaks detected (%zu bytes total)\n",
                   g_memory_manager.leak_count, g_memory_manager.total_allocated);
        }
    }

    // Clean up allocation tracking
    memory_allocation_t* current = g_memory_manager.allocations;
    while (current) {
        memory_allocation_t* next = current->next;
        free(current);
        current = next;
    }

    memset(&g_memory_manager, 0, sizeof(wasm_memory_manager_t));
}

void wasm_memory_get_stats(size_t* total_allocated, size_t* peak_usage,
                         int* allocation_count, int* leak_count) {
    if (total_allocated) *total_allocated = g_memory_manager.total_allocated;
    if (peak_usage) *peak_usage = g_memory_manager.peak_usage;
    if (allocation_count) *allocation_count = g_memory_manager.allocation_count;
    if (leak_count) *leak_count = g_memory_manager.leak_count;
}

void wasm_memory_dump_stats(void) {
    printf("=== WASM Memory Statistics ===\n");
    printf("Total allocated: %zu bytes\n", g_memory_manager.total_allocated);
    printf("Peak usage: %zu bytes\n", g_memory_manager.peak_usage);
    printf("Allocation count: %d\n", g_memory_manager.allocation_count);
    printf("Current allocations: %zu\n", g_memory_manager.total_allocated);
    printf("Cache memory: %zu bytes\n", g_memory_manager.cache_memory);
    printf("Buffer memory: %zu bytes\n", g_memory_manager.buffer_memory);
    printf("Element memory: %zu bytes\n", g_memory_manager.element_memory);

    if (g_memory_manager.leak_count > 0) {
        printf("Leaked allocations: %d\n", g_memory_manager.leak_count);
    }
    printf("==============================\n");
}

// ============================================================================
// SPECIALIZED MEMORY POOLS
// ============================================================================

typedef struct memory_pool {
    void* blocks[16];  // Array of memory blocks
    size_t block_size;
    int block_count;
    int used_blocks;
    struct memory_pool* next;
} memory_pool_t;

static memory_pool_t* g_pools = NULL;

memory_pool_t* wasm_create_pool(size_t block_size, int initial_blocks) {
    memory_pool_t* pool = WASM_MALLOC(sizeof(memory_pool_t));
    if (!pool) {
        return NULL;
    }

    memset(pool, 0, sizeof(memory_pool_t));
    pool->block_size = block_size;
    pool->block_count = initial_blocks;

    // Allocate initial blocks
    for (int i = 0; i < initial_blocks && i < 16; i++) {
        pool->blocks[i] = WASM_MALLOC(block_size);
        if (pool->blocks[i]) {
            pool->used_blocks++;
        }
    }

    pool->next = g_pools;
    g_pools = pool;

    return pool;
}

void* wasm_pool_alloc(memory_pool_t* pool) {
    if (!pool) {
        return WASM_MALLOC(1024); // Default size
    }

    // Find unused block
    for (int i = 0; i < pool->used_blocks; i++) {
        if (pool->blocks[i]) {
            void* ptr = pool->blocks[i];
            pool->blocks[i] = NULL;
            return ptr;
        }
    }

    // Allocate new block if possible
    if (pool->used_blocks < 16) {
        void* ptr = WASM_MALLOC(pool->block_size);
        if (ptr) {
            pool->blocks[pool->used_blocks] = NULL;
            pool->used_blocks++;
            return ptr;
        }
    }

    return NULL; // Pool exhausted
}

void wasm_pool_free(memory_pool_t* pool, void* ptr) {
    if (!pool || !ptr) {
        return;
    }

    // Find empty slot
    for (int i = 0; i < pool->used_blocks; i++) {
        if (pool->blocks[i] == NULL) {
            pool->blocks[i] = ptr;
            return;
        }
    }

    // No slot available, free the block
    WASM_FREE(ptr);
}

void wasm_destroy_pool(memory_pool_t* pool) {
    if (!pool) {
        return;
    }

    // Free all blocks
    for (int i = 0; i < pool->used_blocks; i++) {
        if (pool->blocks[i]) {
            WASM_FREE(pool->blocks[i]);
        }
    }

    // Remove from global pool list
    if (g_pools == pool) {
        g_pools = pool->next;
    } else {
        memory_pool_t* current = g_pools;
        while (current && current->next != pool) {
            current = current->next;
        }
        if (current) {
            current->next = pool->next;
        }
    }

    WASM_FREE(pool);
}

void wasm_destroy_all_pools(void) {
    while (g_pools) {
        wasm_destroy_pool(g_pools);
    }
}

// ============================================================================
// MEMORY VALIDATION
// ============================================================================

int wasm_validate_memory(void) {
    if (!g_memory_manager.tracking_enabled) {
        return 1; // Validation not enabled
    }

    int valid = 1;
    memory_allocation_t* current = g_memory_manager.allocations;

    while (current) {
        // Simple check: see if pointer is accessible
        volatile char test = *(char*)current->ptr;
        (void)test; // Suppress unused variable warning

        current = current->next;
    }

    return valid;
}

void wasm_memory_gc(void) {
    // Force garbage collection by suggesting to the JavaScript runtime
    // This is a no-op in pure C but can be implemented in JavaScript bindings
    if (g_memory_manager.debug_mode) {
        printf("Garbage collection requested\n");
    }
}

// ============================================================================
// INTEGRATION WITH CACHE SYSTEM
// ============================================================================

void wasm_memory_track_cache_memory(wasm_library_cache_t* cache) {
    if (!cache) {
        return;
    }

    size_t cache_memory = 0;
    int total_structures = 0;
    int total_elements = 0;

    wasm_get_cache_stats(cache, &total_structures, &total_elements, &cache_memory);
    g_memory_manager.cache_memory = cache_memory;
}

// ============================================================================
// CLEANUP HELPERS
// ============================================================================

void wasm_cleanup_all_resources(void) {
    // Destroy all memory pools
    wasm_destroy_all_pools();

    // Check for memory leaks
    if (g_memory_manager.tracking_enabled) {
        wasm_memory_shutdown();
    }
}