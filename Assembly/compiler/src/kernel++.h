/* ============================================================================
 * kernel++.h - J++ Kernel Development Header
 * Pure Assembly Backend - No C Runtime!
 * ============================================================================ */

#ifndef KERNEL_PP_H
#define KERNEL_PP_H

/* ============================================================================
 * KERNEL BUILT-IN TYPES (Hardware-level, no stdlib)
 * ============================================================================ */

typedef unsigned char       uint8;
typedef unsigned short      uint16;
typedef unsigned int        uint32;
typedef unsigned long long  uint64;
typedef signed char         int8;
typedef signed short        int16;
typedef signed int          int32;
typedef signed long long    int64;
typedef uint64              size_t;
typedef uint64              phys_addr;
typedef uint64              virt_addr;
typedef uint64              uintptr;
typedef uint64              ptrdiff_t;

/* Boolean without stdbool.h */
typedef uint8               bool;
#define true  1
#define false 0

/* NULL */
#define NULL ((void*)0)

/* ============================================================================
 * MEMORY ATTRIBUTES
 * ============================================================================ */

/* Fixed physical address - places variable at exact memory location */
#define __at(addr) __attribute__((section(".boot"), used, address(addr)))

/* Volatile for hardware registers */
#define __volatile volatile

/* Aligned memory */
#define __aligned(x) __attribute__((aligned(x)))

/* Packed structure (no padding) */
#define __packed __attribute__((packed))

/* No-return function (for panic, halt) */
#define __noreturn __attribute__((noreturn))

/* Always inline */
#define __forceinline __attribute__((always_inline)) inline

/* No inline */
#define __noinline __attribute__((noinline))

/* Section placement */
#define __section(name) __attribute__((section(name)))

/* Used (prevent removal by linker) */
#define __used __attribute__((used))

/* Weak symbol (can be overridden) */
#define __weak __attribute__((weak))

/* ============================================================================
 * KERNEL SECTIONS
 * ============================================================================ */

/* Boot code - runs before paging, in real/protected mode */
#define boot __section(".boot.text") __used

/* Boot data - initialized before main */
#define bootdata __section(".boot.data") __used

/* Kernel code - main kernel text */
#define kernel __section(".text") __used

/* Kernel data - initialized data */
#define kerneldata __section(".data") __used

/* Kernel BSS - uninitialized data */
#define kernelbss __section(".bss") __used

/* Read-only data */
#define readonly __section(".rodata") __used

/* Per-CPU data section */
#define percpu __section(".percpu") __used

/* DMA-able memory (below 16MB, contiguous) */
#define dma __section(".dma") __aligned(4096) __used

/* Page-aligned */
#define page_aligned __aligned(4096)

/* ============================================================================
 * INTERRUPT HANDLERS
 * ============================================================================ */

/* Interrupt Service Routine (CPU exceptions: divide by zero, page fault, etc.) */
#define isr __attribute__((interrupt)) __used

/* IRQ Handler (hardware interrupts: timer, keyboard, etc.) */
#define irq __attribute__((interrupt)) __used

/* System call handler */
#define syscall_handler __used

/* ============================================================================
 * CPU CONTROL (Inline Assembly Primitives)
 * ============================================================================ */

/* Halt CPU until next interrupt */
static __forceinline void hlt(void) {
    __asm__ __volatile__ ("hlt");
}

/* Halt forever (no return) */
static __noreturn void halt(void) {
    while (1) {
        __asm__ __volatile__ ("cli; hlt");
    }
}

/* Pause (spin-loop hint) */
static __forceinline void pause(void) {
    __asm__ __volatile__ ("pause");
}

/* Enable interrupts */
static __forceinline void sti(void) {
    __asm__ __volatile__ ("sti");
}

/* Disable interrupts */
static __forceinline void cli(void) {
    __asm__ __volatile__ ("cli");
}

/* Interrupt status */
static __forceinline bool interrupts_enabled(void) {
    uint64 flags;
    __asm__ __volatile__ ("pushf; pop %0" : "=r"(flags));
    return (flags & 0x200) != 0;
}

/* ============================================================================
 * I/O PORT OPERATIONS (x86 specific)
 * ============================================================================ */

/* Read byte from port */
static __forceinline uint8 inb(uint16 port) {
    uint8 result;
    __asm__ __volatile__ ("inb %w1, %b0" : "=a"(result) : "Nd"(port));
    return result;
}

/* Write byte to port */
static __forceinline void outb(uint16 port, uint8 data) {
    __asm__ __volatile__ ("outb %b0, %w1" :: "a"(data), "Nd"(port));
}

/* Read word from port */
static __forceinline uint16 inw(uint16 port) {
    uint16 result;
    __asm__ __volatile__ ("inw %w1, %w0" : "=a"(result) : "Nd"(port));
    return result;
}

/* Write word to port */
static __forceinline void outw(uint16 port, uint16 data) {
    __asm__ __volatile__ ("outw %w0, %w1" :: "a"(data), "Nd"(port));
}

/* Read long from port */
static __forceinline uint32 inl(uint16 port) {
    uint32 result;
    __asm__ __volatile__ ("inl %w1, %k0" : "=a"(result) : "Nd"(port));
    return result;
}

/* Write long to port */
static __forceinline void outl(uint16 port, uint32 data) {
    __asm__ __volatile__ ("outl %k0, %w1" :: "a"(data), "Nd"(port));
}

/* I/O wait (small delay) */
static __forceinline void io_wait(void) {
    outb(0x80, 0);  // Unused port, takes ~1us
}

/* Read string from port */
static __forceinline void insb(uint16 port, void *addr, uint32 count) {
    __asm__ __volatile__ ("rep insb" : "+D"(addr), "+c"(count) : "d"(port) : "memory");
}

/* Write string to port */
static __forceinline void outsb(uint16 port, const void *addr, uint32 count) {
    __asm__ __volatile__ ("rep outsb" : "+S"(addr), "+c"(count) : "d"(port) : "memory");
}

/* ============================================================================
 * CONTROL REGISTERS (x86_64)
 * ============================================================================ */

static __forceinline uint64 read_cr0(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%cr0, %0" : "=r"(val));
    return val;
}

static __forceinline void write_cr0(uint64 val) {
    __asm__ __volatile__ ("mov %0, %%cr0" :: "r"(val));
}

static __forceinline uint64 read_cr2(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%cr2, %0" : "=r"(val));
    return val;
}

static __forceinline uint64 read_cr3(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%cr3, %0" : "=r"(val));
    return val;
}

static __forceinline void write_cr3(uint64 val) {
    __asm__ __volatile__ ("mov %0, %%cr3" :: "r"(val) : "memory");
}

static __forceinline uint64 read_cr4(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%cr4, %0" : "=r"(val));
    return val;
}

static __forceinline void write_cr4(uint64 val) {
    __asm__ __volatile__ ("mov %0, %%cr4" :: "r"(val));
}

static __forceinline uint64 read_cr8(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%cr8, %0" : "=r"(val));
    return val;
}

static __forceinline void write_cr8(uint64 val) {
    __asm__ __volatile__ ("mov %0, %%cr8" :: "r"(val));
}

/* ============================================================================
 * MSR (Model Specific Registers)
 * ============================================================================ */

static __forceinline uint64 rdmsr(uint32 msr) {
    uint32 low, high;
    __asm__ __volatile__ ("rdmsr" : "=a"(low), "=d"(high) : "c"(msr));
    return ((uint64)high << 32) | low;
}

static __forceinline void wrmsr(uint32 msr, uint64 val) {
    uint32 low = val & 0xFFFFFFFF;
    uint32 high = val >> 32;
    __asm__ __volatile__ ("wrmsr" :: "a"(low), "d"(high), "c"(msr));
}

/* ============================================================================
 * SEGMENT REGISTERS & GDT/IDT
 * ============================================================================ */

static __forceinline void lgdt(void *base, uint16 limit) {
    struct {
        uint16 limit;
        void *base;
    } __packed gdtr = { limit, base };
    __asm__ __volatile__ ("lgdt %0" :: "m"(gdtr));
}

static __forceinline void lidt(void *base, uint16 limit) {
    struct {
        uint16 limit;
        void *base;
    } __packed idtr = { limit, base };
    __asm__ __volatile__ ("lidt %0" :: "m"(idtr));
}

static __forceinline void ltr(uint16 selector) {
    __asm__ __volatile__ ("ltr %0" :: "r"(selector));
}

static __forceinline void lcr3(uint64 val) {
    write_cr3(val);
}

/* Flush TLB for single page */
static __forceinline void invlpg(void *addr) {
    __asm__ __volatile__ ("invlpg (%0)" :: "r"(addr) : "memory");
}

/* Flush entire TLB */
static __forceinline void flush_tlb(void) {
    write_cr3(read_cr3());
}

/* ============================================================================
 * MEMORY BARRIERS & CACHE
 * ============================================================================ */

/* Full memory fence */
static __forceinline void memory_fence(void) {
    __asm__ __volatile__ ("mfence" ::: "memory");
}

/* Load fence */
static __forceinline void load_fence(void) {
    __asm__ __volatile__ ("lfence" ::: "memory");
}

/* Store fence */
static __forceinline void store_fence(void) {
    __asm__ __volatile__ ("sfence" ::: "memory");
}

/* Cache line flush */
static __forceinline void memory_clflush(void *addr) {
    __asm__ __volatile__ ("clflush %0" :: "m"(*(uint8*)addr));
}

/* Cache line flush optimized (CLFLUSHOPT) */
static __forceinline void memory_clflushopt(void *addr) {
    __asm__ __volatile__ ("clflushopt %0" :: "m"(*(uint8*)addr));
}

/* Cache line write back (CLWB) */
static __forceinline void memory_clwb(void *addr) {
    __asm__ __volatile__ (".byte 0x66; clflushopt %0" :: "m"(*(uint8*)addr));
}

/* Prefetch to L1 */
static __forceinline void prefetch_l1(void *addr) {
    __asm__ __volatile__ ("prefetcht0 %0" :: "m"(*(uint8*)addr));
}

/* Prefetch to L2 */
static __forceinline void prefetch_l2(void *addr) {
    __asm__ __volatile__ ("prefetcht1 %0" :: "m"(*(uint8*)addr));
}

/* Prefetch to L3 */
static __forceinline void prefetch_l3(void *addr) {
    __asm__ __volatile__ ("prefetcht2 %0" :: "m"(*(uint8*)addr));
}

/* ============================================================================
 * CPU IDENTIFICATION
 * ============================================================================ */

static __forceinline void cpuid(uint32 code, uint32 *a, uint32 *b, uint32 *c, uint32 *d) {
    __asm__ __volatile__ ("cpuid"
        : "=a"(*a), "=b"(*b), "=c"(*c), "=d"(*d)
        : "a"(code));
}

static __forceinline uint64 read_tsc(void) {
    uint32 low, high;
    __asm__ __volatile__ ("rdtsc" : "=a"(low), "=d"(high));
    return ((uint64)high << 32) | low;
}

static __forceinline uint64 read_tscp(void) {
    uint32 low, high;
    __asm__ __volatile__ ("rdtscp" : "=a"(low), "=d"(high) :: "ecx");
    return ((uint64)high << 32) | low;
}

/* ============================================================================
 * STACK OPERATIONS
 * ============================================================================ */

static __forceinline uint64 read_rsp(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%rsp, %0" : "=r"(val));
    return val;
}

static __forceinline uint64 read_rbp(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%rbp, %0" : "=r"(val));
    return val;
}

static __forceinline void write_rsp(uint64 val) {
    __asm__ __volatile__ ("mov %0, %%rsp" :: "r"(val));
}

/* ============================================================================
 * DEBUG REGISTERS (Hardware breakpoints)
 * ============================================================================ */

static __forceinline uint64 read_dr0(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%dr0, %0" : "=r"(val));
    return val;
}

static __forceinline void write_dr0(uint64 val) {
    __asm__ __volatile__ ("mov %0, %%dr0" :: "r"(val));
}

static __forceinline uint64 read_dr6(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%dr6, %0" : "=r"(val));
    return val;
}

static __forceinline uint64 read_dr7(void) {
    uint64 val;
    __asm__ __volatile__ ("mov %%dr7, %0" : "=r"(val));
    return val;
}

static __forceinline void write_dr7(uint64 val) {
    __asm__ __volatile__ ("mov %0, %%dr7" :: "r"(val));
}

/* ============================================================================
 * APIC (Advanced Programmable Interrupt Controller)
 * ============================================================================ */

#define LAPIC_BASE_MSR 0x1B
#define LAPIC_DEFAULT_BASE 0xFEE00000

static __forceinline uint32 lapic_read(uint32 reg) {
    return *(volatile uint32*)(LAPIC_DEFAULT_BASE + reg);
}

static __forceinline void lapic_write(uint32 reg, uint32 val) {
    *(volatile uint32*)(LAPIC_DEFAULT_BASE + reg) = val;
}

static __forceinline void lapic_eoi(void) {
    lapic_write(0xB0, 0);  // EOI register
}

static __forceinline uint32 lapic_id(void) {
    return lapic_read(0x20) >> 24;
}

/* ============================================================================
 * I/O APIC
 * ============================================================================ */

#define IOAPIC_BASE 0xFEC00000

static __forceinline void ioapic_write(uint32 reg, uint32 val) {
    *(volatile uint32*)IOAPIC_BASE = reg;
    *(volatile uint32*)(IOAPIC_BASE + 0x10) = val;
}

static __forceinline uint32 ioapic_read(uint32 reg) {
    *(volatile uint32*)IOAPIC_BASE = reg;
    return *(volatile uint32*)(IOAPIC_BASE + 0x10);
}

/* ============================================================================
 * PCI CONFIGURATION SPACE
 * ============================================================================ */

static __forceinline uint32 pci_read(uint8 bus, uint8 dev, uint8 func, uint8 offset) {
    uint32 address = (1u << 31) | ((uint32)bus << 16) | ((uint32)dev << 11) | 
                     ((uint32)func << 8) | (offset & 0xFC);
    outl(0xCF8, address);
    return inl(0xCFC);
}

static __forceinline void pci_write(uint8 bus, uint8 dev, uint8 func, uint8 offset, uint32 val) {
    uint32 address = (1u << 31) | ((uint32)bus << 16) | ((uint32)dev << 11) | 
                     ((uint32)func << 8) | (offset & 0xFC);
    outl(0xCF8, address);
    outl(0xCFC, val);
}

/* ============================================================================
 * SPINLOCK (SMP primitive)
 * ============================================================================ */

typedef struct {
    volatile uint32 lock;
} spinlock;

#define SPINLOCK_INIT {0}

static __forceinline void spin_lock(spinlock *sl) {
    while (__sync_lock_test_and_set(&sl->lock, 1)) {
        while (sl->lock) {
            pause();
        }
    }
}

static __forceinline void spin_unlock(spinlock *sl) {
    __sync_lock_release(&sl->lock);
}

static __forceinline bool spin_trylock(spinlock *sl) {
    return __sync_lock_test_and_set(&sl->lock, 1) == 0;
}

/* ============================================================================
 * ATOMIC OPERATIONS
 * ============================================================================ */

static __forceinline uint64 atomic_fetch_add(uint64 *ptr, uint64 val) {
    return __sync_fetch_and_add(ptr, val);
}

static __forceinline uint64 atomic_fetch_sub(uint64 *ptr, uint64 val) {
    return __sync_fetch_and_sub(ptr, val);
}

static __forceinline uint64 atomic_fetch_and(uint64 *ptr, uint64 val) {
    return __sync_fetch_and_and(ptr, val);
}

static __forceinline uint64 atomic_fetch_or(uint64 *ptr, uint64 val) {
    return __sync_fetch_and_or(ptr, val);
}

static __forceinline bool atomic_compare_exchange(uint64 *ptr, uint64 expected, uint64 desired) {
    return __sync_bool_compare_and_swap(ptr, expected, desired);
}

static __forceinline void atomic_store(uint64 *ptr, uint64 val) {
    __sync_lock_test_and_set(ptr, val);
    __sync_lock_release(ptr);
}

/* ============================================================================
 * BIT OPERATIONS
 * ============================================================================ */

static __forceinline uint64 bit_set(uint64 *bitmap, uint64 bit) {
    return __sync_fetch_and_or(bitmap, (1ull << bit));
}

static __forceinline uint64 bit_clear(uint64 *bitmap, uint64 bit) {
    return __sync_fetch_and_and(bitmap, ~(1ull << bit));
}

static __forceinline bool bit_test(uint64 bitmap, uint64 bit) {
    return (bitmap & (1ull << bit)) != 0;
}

static __forceinline uint64 bit_find_first(uint64 bitmap) {
    return __builtin_ctzll(bitmap);
}

/* ============================================================================
 * MEMORY MANAGEMENT PRIMITIVES
 * ============================================================================ */

/* Page size */
#define PAGE_SIZE 4096
#define PAGE_SHIFT 12
#define HUGE_PAGE_SIZE (2 * 1024 * 1024)
#define HUGE_PAGE_SHIFT 21

/* Page round operations */
#define PAGE_ALIGN_UP(addr)   (((addr) + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1))
#define PAGE_ALIGN_DOWN(addr) ((addr) & ~(PAGE_SIZE - 1))
#define PAGE_OFFSET(addr)     ((addr) & (PAGE_SIZE - 1))
#define PAGE_NUMBER(addr)     ((addr) >> PAGE_SHIFT)

/* Physical to virtual (higher half mapping) */
#define KERNEL_VIRT_OFFSET 0xFFFF800000000000
#define phys_to_virt(p) ((void*)((uint64)(p) + KERNEL_VIRT_OFFSET))
#define virt_to_phys(v) ((uint64)(v) - KERNEL_VIRT_OFFSET)

/* ============================================================================
 * PAGE TABLE FLAGS (x86_64)
 * ============================================================================ */

#define PT_PRESENT     (1ull << 0)
#define PT_WRITABLE    (1ull << 1)
#define PT_USER        (1ull << 2)
#define PT_WRITETHROUGH (1ull << 3)
#define PT_CACHEDISABLE (1ull << 4)
#define PT_ACCESSED    (1ull << 5)
#define PT_DIRTY       (1ull << 6)
#define PT_PAGESIZE    (1ull << 7)   // PDE/PDPE only
#define PT_GLOBAL      (1ull << 8)
#define PT_PAT         (1ull << 12)  // Page Attribute Table
#define PT_NX          (1ull << 63)  // No-Execute

/* Cache types */
#define PT_UNCACHED    (PT_CACHEDISABLE)
#define PT_WRITEBACK   (0)
#define PT_WRITECOMBINE (PT_CACHEDISABLE | PT_PAT)

/* ============================================================================
 * GDT/IDT STRUCTURES
 * ============================================================================ */

struct __packed gdt_entry {
    uint16 limit_low;
    uint16 base_low;
    uint8  base_mid;
    uint8  access;
    uint8  granularity;
    uint8  base_high;
};

struct __packed gdt_entry64 {
    uint16 limit_low;
    uint16 base_low;
    uint8  base_mid;
    uint8  access;
    uint8  granularity;
    uint8  base_high;
    uint32 base_upper;
    uint32 reserved;
};

struct __packed idt_entry {
    uint16 offset_low;
    uint16 selector;
    uint8  ist;           // Interrupt Stack Table (0-7)
    uint8  type_attr;     // P(1) | DPL(2) | 0 | Type(4)
    uint16 offset_mid;
    uint32 offset_high;
    uint32 reserved;
};

struct __packed tss_entry {
    uint32 reserved0;
    uint64 rsp0;
    uint64 rsp1;
    uint64 rsp2;
    uint64 reserved1;
    uint64 ist1;
    uint64 ist2;
    uint64 ist3;
    uint64 ist4;
    uint64 ist5;
    uint64 ist6;
    uint64 ist7;
    uint64 reserved2;
    uint16 reserved3;
    uint16 iomap_base;
};

/* GDT access byte */
#define GDT_ACCESS_PRESENT    0x80
#define GDT_ACCESS_DPL0       0x00
#define GDT_ACCESS_DPL3       0x60
#define GDT_ACCESS_SEGMENT    0x10
#define GDT_ACCESS_CODE       0x0A  // Execute/Read
#define GDT_ACCESS_DATA       0x02  // Read/Write
#define GDT_ACCESS_TSS        0x09

/* GDT granularity byte */
#define GDT_GRAN_4K           0x80
#define GDT_GRAN_32BIT        0x40
#define GDT_GRAN_64BIT        0x20
#define GDT_GRAN_LIMIT_HIGH   0x0F

/* IDT type attributes */
#define IDT_TYPE_INTERRUPT    0x0E  // Interrupt gate
#define IDT_TYPE_TRAP         0x0F  // Trap gate
#define IDT_TYPE_SYSCALL      0x0E  // System call
#define IDT_PRESENT           0x80
#define IDT_DPL0              0x00
#define IDT_DPL3              0x60

/* ============================================================================
 * STACK FRAME (Interrupt context)
 * ============================================================================ */

struct __packed stack_frame {
    uint64 r15;
    uint64 r14;
    uint64 r13;
    uint64 r12;
    uint64 r11;
    uint64 r10;
    uint64 r9;
    uint64 r8;
    uint64 rbp;
    uint64 rdi;
    uint64 rsi;
    uint64 rdx;
    uint64 rcx;
    uint64 rbx;
    uint64 rax;
    uint64 err_code;      // For exceptions with error code
    uint64 rip;
    uint64 cs;
    uint64 rflags;
    uint64 rsp;
    uint64 ss;
};

/* ============================================================================
 * KERNEL ASSERT & PANIC
 * ============================================================================ */

#define KERNEL_ASSERT(cond) \
    do { if (!(cond)) kernel_panic("Assertion failed: " #cond, __FILE__, __LINE__); } while(0)

#define KERNEL_PANIC(msg) \
    kernel_panic(msg, __FILE__, __LINE__)

/* Implemented in kernel main */
extern void kernel_panic(const char *msg, const char *file, int line) __noreturn;

/* ============================================================================
 * VGA TEXT MODE (Early console)
 * ============================================================================ */

#define VGA_BUFFER 0xB8000
#define VGA_WIDTH 80
#define VGA_HEIGHT 25
#define VGA_COLOR(bg, fg) ((bg) << 4 | (fg))

enum vga_color {
    VGA_BLACK = 0,
    VGA_BLUE = 1,
    VGA_GREEN = 2,
    VGA_CYAN = 3,
    VGA_RED = 4,
    VGA_MAGENTA = 5,
    VGA_BROWN = 6,
    VGA_LIGHT_GREY = 7,
    VGA_DARK_GREY = 8,
    VGA_LIGHT_BLUE = 9,
    VGA_LIGHT_GREEN = 10,
    VGA_LIGHT_CYAN = 11,
    VGA_LIGHT_RED = 12,
    VGA_LIGHT_MAGENTA = 13,
    VGA_LIGHT_BROWN = 14,
    VGA_WHITE = 15,
};

/* ============================================================================
 * SERIAL PORT (COM1/COM2 for early debugging)
 * ============================================================================ */

#define COM1 0x3F8
#define COM2 0x2F8
#define COM3 0x3E8
#define COM4 0x2E8

#define SERIAL_DATA(port)     (port)
#define SERIAL_INT_EN(port)   ((port) + 1)
#define SERIAL_FIFO(port)     ((port) + 2)
#define SERIAL_LINE(port)     ((port) + 3)
#define SERIAL_MODEM(port)    ((port) + 4)
#define SERIAL_LINE_STAT(port) ((port) + 5)

/* ============================================================================
 * PIT TIMER (Programmable Interval Timer)
 * ============================================================================ */

#define PIT_FREQ 1193182
#define PIT_CHANNEL0 0x40
#define PIT_CHANNEL1 0x41
#define PIT_CHANNEL2 0x42
#define PIT_COMMAND  0x43

#define PIT_MODE_SQUARE_WAVE 0x36
#define PIT_MODE_RATE_GEN    0x34

/* ============================================================================
 * KEYBOARD SCAN CODES
 * ============================================================================ */

#define KB_DATA_PORT 0x60
#define KB_STATUS_PORT 0x64
#define KB_COMMAND_PORT 0x64

#define KB_STATUS_OUT_FULL 0x01
#define KB_STATUS_IN_FULL  0x02

/* ============================================================================
 * MULTIBOOT (GRUB compatibility)
 * ============================================================================ */

#define MULTIBOOT_MAGIC 0x1BADB002
#define MULTIBOOT_FLAGS_ALIGN     0x00000001
#define MULTIBOOT_FLAGS_MEMINFO   0x00000002
#define MULTIBOOT_FLAGS_VIDINFO   0x00000004
#define MULTIBOOT_FLAGS_AOUT      0x00010000

#define MULTIBOOT_CHECKSUM(flags) -(MULTIBOOT_MAGIC + (flags))

struct __packed multiboot_header {
    uint32 magic;
    uint32 flags;
    uint32 checksum;
    uint32 header_addr;
    uint32 load_addr;
    uint32 load_end_addr;
    uint32 bss_end_addr;
    uint32 entry_addr;
    uint32 mode_type;
    uint32 width;
    uint32 height;
    uint32 depth;
};

struct __packed multiboot_info {
    uint32 flags;
    uint32 mem_lower;
    uint32 mem_upper;
    uint32 boot_device;
    uint32 cmdline;
    uint32 mods_count;
    uint32 mods_addr;
    uint32 syms[4];
    uint32 mmap_length;
    uint32 mmap_addr;
    uint32 drives_length;
    uint32 drives_addr;
    uint32 config_table;
    uint32 bootloader_name;
    uint32 apm_table;
    uint32 vbe_control_info;
    uint32 vbe_mode_info;
    uint32 vbe_mode;
    uint32 vbe_interface_seg;
    uint32 vbe_interface_off;
    uint32 vbe_interface_len;
    uint64 framebuffer_addr;
    uint32 framebuffer_pitch;
    uint32 framebuffer_width;
    uint32 framebuffer_height;
    uint8  framebuffer_bpp;
    uint8  framebuffer_type;
    uint32 color_info[6];
};

/* ============================================================================
 * MEMORY MAP (from bootloader)
 * ============================================================================ */

struct __packed memory_map_entry {
    uint32 size;
    uint64 base;
    uint64 length;
    uint32 type;
};

#define MEMORY_TYPE_AVAILABLE  1
#define MEMORY_TYPE_RESERVED   2
#define MEMORY_TYPE_ACPI       3
#define MEMORY_TYPE_NVS        4
#define MEMORY_TYPE_BAD        5

/* ============================================================================
 * DMA (Direct Memory Access)
 * ============================================================================ */

#define DMA_CHANNEL0 0x00
#define DMA_CHANNEL1 0x01
#define DMA_CHANNEL2 0x02
#define DMA_CHANNEL3 0x03
#define DMA_CHANNEL4 0xC0
#define DMA_CHANNEL5 0xC1
#define DMA_CHANNEL6 0xC2
#define DMA_CHANNEL7 0xC3

#define DMA_REG_MASK    0x0A
#define DMA_REG_MODE    0x0B
#define DMA_REG_CLEAR   0x0C
#define DMA_REG_TEMP    0x0D
#define DMA_REG_MASTER  0xD8

#define DMA_MODE_READ   0x44
#define DMA_MODE_WRITE  0x48
#define DMA_MODE_SINGLE 0x40
#define DMA_MODE_AUTO   0x50
#define DMA_MODE_DOWN   0x00
#define DMA_MODE_UP     0x20

/* ============================================================================
 * KERNEL MAIN DECLARATION
 * ============================================================================ */

extern void kernel_main(void);
extern void kernel_early(void);

/* ============================================================================
 * UTILITY FUNCTIONS (Implemented in kernel)
 * ============================================================================ */

extern void *memset(void *dst, int val, size_t len);
extern void *memcpy(void *dst, const void *src, size_t len);
extern void *memmove(void *dst, const void *src, size_t len);
extern int memcmp(const void *a, const void *b, size_t len);
extern size_t strlen(const char *s);
extern int strcmp(const char *a, const char *b);
extern char *strcpy(char *dst, const char *src);
extern char *strncpy(char *dst, const char *src, size_t n);
extern int atoi(const char *s);
extern void itoa(int val, char *buf, int base);
extern void uitoa(uint64 val, char *buf, int base);

/* Early print (before full console) */
extern void early_print(const char *s);
extern void early_print_hex(uint64 val);
extern void early_print_dec(uint64 val);
extern void early_clear(void);
extern void early_setpos(int x, int y);
extern void early_setcolor(uint8 color);

/* Full kernel print */
extern void kprint(const char *fmt, ...);
extern void kprint_hex(uint64 val);
extern void kprint_dec(uint64 val);
extern void kprint_bin(uint64 val);

/* ============================================================================
 * END OF KERNEL HEADER
 * ============================================================================ */

#endif /* KERNEL_PP_H */