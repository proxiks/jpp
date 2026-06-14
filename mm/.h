// jpp_runtime.h
// C header for J++ Ada runtime - Used by Go and Zig
// Author: Jatin (linuxab)

#ifndef JPP_RUNTIME_H
#define JPP_RUNTIME_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Memory regions (match Ada enum)
typedef enum {
    JPP_REGION_KERNEL = 0,
    JPP_REGION_USER = 1,
    JPP_REGION_DMA = 2,
    JPP_REGION_XDNA_L1 = 3,
    JPP_REGION_XDNA_L2 = 4,
    JPP_REGION_XDNA_L3 = 5,
    JPP_REGION_DEVICE = 6
} jpp_memory_region_t;

// Allocation strategies
typedef enum {
    JPP_ALLOC_FIRST_FIT = 0,
    JPP_ALLOC_BEST_FIT = 1,
    JPP_ALLOC_WORST_FIT = 2,
    JPP_ALLOC_BUDDY = 3
} jpp_alloc_strategy_t;

// Hardware targets
typedef enum {
    JPP_TARGET_XILINX_ARTIX7 = 0,
    JPP_TARGET_XILINX_KINTEX7 = 1,
    JPP_TARGET_XILINX_VIRTEX7 = 2,
    JPP_TARGET_XILINX_ZYNQ = 3,
    JPP_TARGET_XILINX_ALVEO = 4,
    JPP_TARGET_INTEL_CYCLONE = 5,
    JPP_TARGET_INTEL_ARRIA = 6,
    JPP_TARGET_INTEL_STRATIX = 7,
    JPP_TARGET_LATTICE_ECP5 = 8,
    JPP_TARGET_LATTICE_CROSSLINK = 9,
    JPP_TARGET_CUSTOM = 10
} jpp_target_platform_t;

// HDL languages
typedef enum {
    JPP_HDL_VHDL = 0,
    JPP_HDL_VERILOG = 1,
    JPP_HDL_SYSTEMVERILOG = 2,
    JPP_HDL_NETLIST = 3
} jpp_hdl_language_t;

// Memory block handle (opaque)
typedef struct jpp_memory_block jpp_memory_block_t;

// === Memory Management ===

// Allocate memory from heap
void* jpp_heap_allocate(uint64_t size, uint64_t align, uint8_t region);

// Free memory
void jpp_heap_deallocate(void* addr);

// Reallocate memory
void* jpp_heap_reallocate(void* addr, uint64_t new_size);

// Copy memory
void jpp_memory_copy(void* dest, const void* src, uint64_t count);

// Set memory
void jpp_memory_set(void* addr, uint8_t value, uint64_t count);

// Zero memory
void jpp_memory_zero(void* addr, uint64_t count);

// DMA allocation (contiguous, below 16MB)
void* jpp_dma_allocate(uint64_t size);

// XDNA NPU memory allocation
void* jpp_xdna_allocate(uint64_t size, uint8_t mem_level);

// === Garbage Collection ===

// Run garbage collector
void jpp_gc_collect(void);

// Get GC statistics
void jpp_gc_get_stats(uint64_t* total, uint64_t* used, uint64_t* free,
                      uint64_t* largest, uint32_t* fragments);

// === Hardware Generation ===

// Generate hardware from J++ source
uint8_t jpp_generate_hardware(const char* source_code, uint64_t source_len,
                              uint8_t target, uint8_t language,
                              const char* top_entity, uint64_t entity_len,
                              const char* output_path, uint64_t path_len);

// === Runtime Initialization ===

// Initialize J++ runtime
int jpp_runtime_init(void);

// Shutdown J++ runtime
void jpp_runtime_shutdown(void);

// === Error Handling ===

// Get last error message
const char* jpp_get_error(void);

// Clear error
void jpp_clear_error(void);

#ifdef __cplusplus
}
#endif

#endif // JPP_RUNTIME_H
"""

with open(f"{base}/compiler/runtime/jpp_runtime.h", "w") as f:
    f.write(c_header)

# ============================================
# 7. GO BINDING TO ADA RUNTIME
# ============================================

go_binding = """// jpp_runtime.go
// Go binding to J++ Ada runtime
// Author: Jatin (linuxab)

package runtime

/*
#cgo LDFLAGS: -ljpp_runtime
#include "jpp_runtime.h"
*/
import "C"
import (
	"fmt"
	"unsafe"
)

// MemoryRegion represents J++ memory regions
type MemoryRegion int

const (
	RegionKernel MemoryRegion = iota
	RegionUser
	RegionDMA
	RegionXDNAL1
	RegionXDNAL2
	RegionXDNAL3
	RegionDevice
)

// TargetPlatform represents FPGA/ASIC targets
type TargetPlatform int

const (
	XilinxArtix7 TargetPlatform = iota
	XilinxKintex7
	XilinxVirtex7
	XilinxZynq
	XilinxAlveo
	IntelCyclone
	IntelArria
	IntelStratix
	LatticeECP5
	LatticeCrosslink
	CustomTarget
)

// HDLLanguage represents hardware description languages
type HDLLanguage int

const (
	VHDL HDLLanguage = iota
	Verilog
	SystemVerilog
	Netlist
)

// MemoryBlock represents an allocated memory block
type MemoryBlock struct {
	Addr   unsafe.Pointer
	Size   uint64
	Region MemoryRegion
}

// Allocate allocates memory from the J++ heap
func Allocate(size uint64, align uint64, region MemoryRegion) (*MemoryBlock, error) {
	addr := C.jpp_heap_allocate(C.uint64_t(size), C.uint64_t(align), C.uint8_t(region))
	if addr == nil {
		return nil, fmt.Errorf("memory allocation failed")
	}
	return &MemoryBlock{
		Addr:   addr,
		Size:   size,
		Region: region,
	}, nil
}

// Free deallocates a memory block
func (b *MemoryBlock) Free() error {
	if b.Addr == nil {
		return fmt.Errorf("double free detected")
	}
	C.jpp_heap_deallocate(b.Addr)
	b.Addr = nil
	return nil
}

// Reallocate changes the size of a memory block
func (b *MemoryBlock) Reallocate(newSize uint64) error {
	if b.Addr == nil {
		return fmt.Errorf("invalid memory block")
	}
	newAddr := C.jpp_heap_reallocate(b.Addr, C.uint64_t(newSize))
	if newAddr == nil {
		return fmt.Errorf("reallocation failed")
	}
	b.Addr = newAddr
	b.Size = newSize
	return nil
}

// Copy copies memory from src to dest
func Copy(dest, src *MemoryBlock, count uint64) error {
	if dest.Addr == nil || src.Addr == nil {
		return fmt.Errorf("invalid memory block")
	}
	if count > dest.Size || count > src.Size {
		return fmt.Errorf("buffer overflow: count %d exceeds dest %d or src %d", 
			count, dest.Size, src.Size)
	}
	C.jpp_memory_copy(dest.Addr, src.Addr, C.uint64_t(count))
	return nil
}

// Set sets memory to a value
func (b *MemoryBlock) Set(value uint8, count uint64) error {
	if b.Addr == nil {
		return fmt.Errorf("invalid memory block")
	}
	if count > b.Size {
		return fmt.Errorf("buffer overflow")
	}
	C.jpp_memory_set(b.Addr, C.uint8_t(value), C.uint64_t(count))
	return nil
}

// Zero zeros out memory
func (b *MemoryBlock) Zero() error {
	if b.Addr == nil {
		return fmt.Errorf("invalid memory block")
	}
	C.jpp_memory_zero(b.Addr, C.uint64_t(b.Size))
	return nil
}

// DMAAllocate allocates DMA-contiguous memory
func DMAAllocate(size uint64) (*MemoryBlock, error) {
	addr := C.jpp_dma_allocate(C.uint64_t(size))
	if addr == nil {
		return nil, fmt.Errorf("DMA allocation failed")
	}
	return &MemoryBlock{
		Addr:   addr,
		Size:   size,
		Region: RegionDMA,
	}, nil
}

// XDNAAllocate allocates XDNA NPU memory
func XDNAAllocate(size uint64, level int) (*MemoryBlock, error) {
	addr := C.jpp_xdna_allocate(C.uint64_t(size), C.uint8_t(level))
	if addr == nil {
		return nil, fmt.Errorf("XDNA allocation failed")
	}
	return &MemoryBlock{
		Addr:   addr,
		Size:   size,
		Region: MemoryRegion(3 + level), // L1=3, L2=4, L3=5
	}, nil
}

// GCStats represents garbage collection statistics
type GCStats struct {
	Total     uint64
	Used      uint64
	Free      uint64
	Largest   uint64
	Fragments uint32
}

// Collect runs the garbage collector
func Collect() {
	C.jpp_gc_collect()
}

// GetGCStats returns garbage collection statistics
func GetGCStats() GCStats {
	var stats GCStats
	C.jpp_gc_get_stats(
		(*C.uint64_t)(unsafe.Pointer(&stats.Total)),
		(*C.uint64_t)(unsafe.Pointer(&stats.Used)),
		(*C.uint64_t)(unsafe.Pointer(&stats.Free)),
		(*C.uint64_t)(unsafe.Pointer(&stats.Largest)),
		(*C.uint32_t)(unsafe.Pointer(&stats.Fragments)),
	)
	return stats
}

// GenerateHardware generates VHDL/Verilog from J++ source
func GenerateHardware(sourceCode string, target TargetPlatform, 
                     language HDLLanguage, topEntity, outputPath string) error {
	sourcePtr := C.CString(sourceCode)
	defer C.free(unsafe.Pointer(sourcePtr))
	
	entityPtr := C.CString(topEntity)
	defer C.free(unsafe.Pointer(entityPtr))
	
	pathPtr := C.CString(outputPath)
	defer C.free(unsafe.Pointer(pathPtr))
	
	result := C.jpp_generate_hardware(
		sourcePtr,
		C.uint64_t(len(sourceCode)),
		C.uint8_t(target),
		C.uint8_t(language),
		entityPtr,
		C.uint64_t(len(topEntity)),
		pathPtr,
		C.uint64_t(len(outputPath)),
	)
	
	if result != 0 {
		return fmt.Errorf("hardware generation failed with error code: %d", result)
	}
	return nil
}

// Init initializes the J++ runtime
func Init() error {
	if C.jpp_runtime_init() != 0 {
		return fmt.Errorf("runtime initialization failed")
	}
	return nil
}

// Shutdown shuts down the J++ runtime
func Shutdown() {
	C.jpp_runtime_shutdown()
}

// GetError returns the last error message
func GetError() string {
	return C.GoString(C.jpp_get_error())
}