// jpp_runtime.zig
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