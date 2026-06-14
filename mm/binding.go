// jpp_runtime.go
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
"""

with open(f"{base}/compiler/runtime/jpp_runtime.go", "w") as f:
    f.write(go_binding)

# ============================================
# 8. ZIG BINDING TO ADA RUNTIME
# ============================================

zig_binding = """// jpp_runtime.zig
// Zig binding to J++ Ada runtime
// Author: Jatin (linuxab)

const std = @import("std");
const c = @cImport({
    @cInclude("jpp_runtime.h");
});

pub const MemoryRegion = enum(u8) {
    kernel = 0,
    user = 1,
    dma = 2,
    xdna_l1 = 3,
    xdna_l2 = 4,
    xdna_l3 = 5,
    device = 6,
};

pub const TargetPlatform = enum(u8) {
    xilinx_artix7 = 0,
    xilinx_kintex7 = 1,
    xilinx_virtex7 = 2,
    xilinx_zynq = 3,
    xilinx_alveo = 4,
    intel_cyclone = 5,
    intel_arria = 6,
    intel_stratix = 7,
    lattice_ecp5 = 8,
    lattice_crosslink = 9,
    custom = 10,
};

pub const HDLLanguage = enum(u8) {
    vhdl = 0,
    verilog = 1,
    systemverilog = 2,
    netlist = 3,
};

pub const AllocError = error{
    OutOfMemory,
    InvalidSize,
    InvalidAlignment,
    RegionFull,
    DoubleFree,
};

pub const HardwareError = error{
    UnsupportedFeature,
    TimingViolation,
    ResourceExhausted,
    ClockDomainError,
    ResetMissing,
    InvalidConstraint,
};

pub const MemoryBlock = struct {
    addr: ?*anyopaque,
    size: u64,
    region: MemoryRegion,
    
    pub fn free(self: *MemoryBlock) AllocError!void {
        if (self.addr == null) return AllocError.DoubleFree;
        c.jpp_heap_deallocate(self.addr.?);
        self.addr = null;
    }
    
    pub fn reallocate(self: *MemoryBlock, new_size: u64) AllocError!void {
        if (self.addr == null) return AllocError.InvalidSize;
        const new_addr = c.jpp_heap_reallocate(self.addr.?, new_size);
        if (new_addr == null) return AllocError.OutOfMemory;
        self.addr = new_addr;
        self.size = new_size;
    }
    
    pub fn set(self: *MemoryBlock, value: u8, count: u64) AllocError!void {
        if (self.addr == null) return AllocError.InvalidSize;
        if (count > self.size) return AllocError.InvalidSize;
        c.jpp_memory_set(self.addr.?, value, count);
    }
    
    pub fn zero(self: *MemoryBlock) AllocError!void {
        if (self.addr == null) return AllocError.InvalidSize;
        c.jpp_memory_zero(self.addr.?, self.size);
    }
};

pub const GCStats = struct {
    total: u64,
    used: u64,
    free: u64,
    largest: u64,
    fragments: u32,
};

/// Initialize J++ runtime
pub fn init() !void {
    if (c.jpp_runtime_init() != 0) {
        return error.RuntimeInitFailed;
    }
}

/// Shutdown J++ runtime
pub fn shutdown() void {
    c.jpp_runtime_shutdown();
}

/// Allocate memory from heap
pub fn allocate(size: u64, align: u64, region: MemoryRegion) AllocError!MemoryBlock {
    const addr = c.jpp_heap_allocate(size, align, @intFromEnum(region));
    if (addr == null) return AllocError.OutOfMemory;
    return MemoryBlock{
        .addr = addr,
        .size = size,
        .region = region,
    };
}

/// Allocate DMA-contiguous memory
pub fn dmaAllocate(size: u64) AllocError!MemoryBlock {
    const addr = c.jpp_dma_allocate(size);
    if (addr == null) return AllocError.OutOfMemory;
    return MemoryBlock{
        .addr = addr,
        .size = size,
        .region = .dma,
    };
}

/// Allocate XDNA NPU memory
pub fn xdnaAllocate(size: u64, level: u2) AllocError!MemoryBlock {
    const addr = c.jpp_xdna_allocate(size, @intCast(level));
    if (addr == null) return AllocError.OutOfMemory;
    return MemoryBlock{
        .addr = addr,
        .size = size,
        .region = @enumFromInt(3 + level),
    };
}

/// Copy memory between blocks
pub fn copy(dest: *MemoryBlock, src: *MemoryBlock, count: u64) AllocError!void {
    if (dest.addr == null or src.addr == null) return AllocError.InvalidSize;
    if (count > dest.size or count > src.size) return AllocError.InvalidSize;
    c.jpp_memory_copy(dest.addr.?, src.addr.?, count);
}

/// Run garbage collector
pub fn gcCollect() void {
    c.jpp_gc_collect();
}

/// Get GC statistics
pub fn gcStats() GCStats {
    var stats: GCStats = undefined;
    c.jpp_gc_get_stats(
        &stats.total,
        &stats.used,
        &stats.free,
        &stats.largest,
        &stats.fragments,
    );
    return stats;
}

/// Generate hardware from J++ source
pub fn generateHardware(
    source_code: []const u8,
    target: TargetPlatform,
    language: HDLLanguage,
    top_entity: []const u8,
    output_path: []const u8,
) HardwareError!void {
    const result = c.jpp_generate_hardware(
        source_code.ptr,
        source_code.len,
        @intFromEnum(target),
        @intFromEnum(language),
        top_entity.ptr,
        top_entity.len,
        output_path.ptr,
        output_path.len,
    );
    if (result != 0) return HardwareError.UnsupportedFeature;
}

/// Get last error message
pub fn getError() []const u8 {
    const ptr = c.jpp_get_error();
    return std.mem.span(ptr);
}

/// Clear error
pub fn clearError() void {
    c.jpp_clear_error();
}