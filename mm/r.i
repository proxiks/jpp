// jpp_runtime.c
// C runtime implementation - bridges Ada/SPARK to C/Go/Zig
// Author: Jatin (linuxab)

#include "jpp_runtime.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// Thread-local error buffer
_Thread_local char jpp_error_buffer[1024] = {0};

// === Memory Management ===

// These call into the Ada/SPARK runtime via extern declarations
// The actual implementation is in libjpp_runtime.a (Ada compiled library)

extern void* ada_jpp_heap_allocate(uint64_t size, uint64_t align, uint8_t region);
extern void ada_jpp_heap_deallocate(void* addr);
extern void* ada_jpp_heap_reallocate(void* addr, uint64_t new_size);
extern void ada_jpp_memory_copy(void* dest, const void* src, uint64_t count);
extern void ada_jpp_memory_set(void* addr, uint8_t value, uint64_t count);
extern void ada_jpp_memory_zero(void* addr, uint64_t count);
extern void* ada_jpp_dma_allocate(uint64_t size);
extern void* ada_jpp_xdna_allocate(uint64_t size, uint8_t mem_level);

void* jpp_heap_allocate(uint64_t size, uint64_t align, uint8_t region) {
    void* ptr = ada_jpp_heap_allocate(size, align, region);
    if (!ptr) {
        snprintf(jpp_error_buffer, sizeof(jpp_error_buffer), 
                 "Heap allocation failed: size=%lu, align=%lu, region=%d", 
                 size, align, region);
    }
    return ptr;
}

void jpp_heap_deallocate(void* addr) {
    if (!addr) {
        snprintf(jpp_error_buffer, sizeof(jpp_error_buffer), 
                 "Double free detected: addr=%p", addr);
        return;
    }
    ada_jpp_heap_deallocate(addr);
}

void* jpp_heap_reallocate(void* addr, uint64_t new_size) {
    void* ptr = ada_jpp_heap_reallocate(addr, new_size);
    if (!ptr) {
        snprintf(jpp_error_buffer, sizeof(jpp_error_buffer), 
                 "Heap reallocation failed: addr=%p, new_size=%lu", addr, new_size);
    }
    return ptr;
}

void jpp_memory_copy(void* dest, const void* src, uint64_t count) {
    if (!dest || !src) {
        snprintf(jpp_error_buffer, sizeof(jpp_error_buffer), 
                 "Invalid memory copy: dest=%p, src=%p", dest, src);
        return;
    }
    ada_jpp_memory_copy(dest, src, count);
}

void jpp_memory_set(void* addr, uint8_t value, uint64_t count) {
    if (!addr) {
        snprintf(jpp_error_buffer, sizeof(jpp_error_buffer), 
                 "Invalid memory set: addr=%p", addr);
        return;
    }
    ada_jpp_memory_set(addr, value, count);
}

void jpp_memory_zero(void* addr, uint64_t count) {
    if (!addr) {
        snprintf(jpp_error_buffer, sizeof(jpp_error_buffer), 
                 "Invalid memory zero: addr=%p", addr);
        return;
    }
    ada_jpp_memory_zero(addr, count);
}

void* jpp_dma_allocate(uint64_t size) {
    void* ptr = ada_jpp_dma_allocate(size);
    if (!ptr) {
        snprintf(jpp_error_buffer, sizeof(jpp_error_buffer), 
                 "DMA allocation failed: size=%lu", size);
    }
    return ptr;
}

void* jpp_xdna_allocate(uint64_t size, uint8_t mem_level) {
    void* ptr = ada_jpp_xdna_allocate(size, mem_level);
    if (!ptr) {
        snprintf(jpp_error_buffer, sizeof(jpp_error_buffer), 
                 "XDNA allocation failed: size=%lu, level=%d", size, mem_level);
    }
    return ptr;
}

// === Garbage Collection ===

extern void ada_jpp_gc_collect(void);
extern void ada_jpp_gc_get_stats(uint64_t* total, uint64_t* used, uint64_t* free,
                                  uint64_t* largest, uint32_t* fragments);

void jpp_gc_collect(void) {
    ada_jpp_gc_collect();
}

void jpp_gc_get_stats(uint64_t* total, uint64_t* used, uint64_t* free,
                      uint64_t* largest, uint32_t* fragments) {
    ada_jpp_gc_get_stats(total, used, free, largest, fragments);
}

// === Hardware Generation ===

extern uint8_t ada_jpp_generate_hardware(const char* source_code, uint64_t source_len,
                                         uint8_t target, uint8_t language,
                                         const char* top_entity, uint64_t entity_len,
                                         const char* output_path, uint64_t path_len);

uint8_t jpp_generate_hardware(const char* source_code, uint64_t source_len,
                              uint8_t target, uint8_t language,
                              const char* top_entity, uint64_t entity_len,
                              const char* output_path, uint64_t path_len) {
    uint8_t result = ada_jpp_generate_hardware(source_code, source_len,
                                              target, language,
                                              top_entity, entity_len,
                                              output_path, path_len);
    if (result != 0) {
        snprintf(jpp_error_buffer, sizeof(jpp_error_buffer), 
                 "Hardware generation failed with error code: %d", result);
    }
    return result;
}

// === Runtime Initialization ===

extern int ada_jpp_runtime_init(void);
extern void ada_jpp_runtime_shutdown(void);

int jpp_runtime_init(void) {
    return ada_jpp_runtime_init();
}

void jpp_runtime_shutdown(void) {
    ada_jpp_runtime_shutdown();
}

// === Error Handling ===

const char* jpp_get_error(void) {
    return jpp_error_buffer;
}

void jpp_clear_error(void) {
    jpp_error_buffer[0] = '\\0';
}