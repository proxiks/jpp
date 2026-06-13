/* ============================================================================
 * x86_64++.h - J++ x86_64 Architecture Specific Kernel Header
 * Pure Assembly Backend - x86_64 specific operations
 * ============================================================================ */

#ifndef X86_64_PP_H
#define X86_64_PP_H

#include "kernel++.h"

/* ============================================================================
 * x86_64 CPU FEATURES
 * ============================================================================ */

/* CPUID feature flags (EDX from CPUID 1) */
#define CPUID_FPU       (1 << 0)
#define CPUID_VME       (1 << 1)
#define CPUID_DE        (1 << 2)
#define CPUID_PSE       (1 << 3)
#define CPUID_TSC       (1 << 4)
#define CPUID_MSR       (1 << 5)
#define CPUID_PAE       (1 << 6)
#define CPUID_MCE       (1 << 7)
#define CPUID_CX8       (1 << 8)
#define CPUID_APIC      (1 << 9)
#define CPUID_SEP       (1 << 11)
#define CPUID_MTRR      (1 << 12)
#define CPUID_PGE       (1 << 13)
#define CPUID_MCA       (1 << 14)
#define CPUID_CMOV      (1 << 15)
#define CPUID_PAT       (1 << 16)
#define CPUID_PSE36     (1 << 17)
#define CPUID_PSN       (1 << 18)
#define CPUID_CLFLUSH   (1 << 19)
#define CPUID_DS        (1 << 21)
#define CPUID_ACPI      (1 << 22)
#define CPUID_MMX       (1 << 23)
#define CPUID_FXSR      (1 << 24)
#define CPUID_SSE       (1 << 25)
#define CPUID_SSE2      (1 << 26)
#define CPUID_SS        (1 << 27)
#define CPUID_HT        (1 << 28)
#define CPUID_TM        (1 << 29)
#define CPUID_IA64      (1 << 30)
#define CPUID_PBE       (1 << 31)

/* CPUID feature flags (ECX from CPUID 1) */
#define CPUID_SSE3      (1 << 0)
#define CPUID_PCLMUL    (1 << 1)
#define CPUID_DTES64    (1 << 2)
#define CPUID_MONITOR   (1 << 3)
#define CPUID_DS_CPL    (1 << 4)
#define CPUID_VMX       (1 << 5)
#define CPUID_SMX       (1 << 6)
#define CPUID_EST       (1 << 7)
#define CPUID_TM2       (1 << 8)
#define CPUID_SSSE3     (1 << 9)
#define CPUID_CID       (1 << 10)
#define CPUID_FMA       (1 << 12)
#define CPUID_CX16      (1 << 13)
#define CPUID_XTPR      (1 << 14)
#define CPUID_PDCM      (1 << 15)
#define CPUID_PCID      (1 << 17)
#define CPUID_DCA       (1 << 18)
#define CPUID_SSE4_1    (1 << 19)
#define CPUID_SSE4_2    (1 << 20)
#define CPUID_X2APIC    (1 << 21)
#define CPUID_MOVBE     (1 << 22)
#define CPUID_POPCNT    (1 << 23)
#define CPUID_TSC_DEADLINE (1 << 24)
#define CPUID_AES       (1 << 25)
#define CPUID_XSAVE     (1 << 26)
#define CPUID_OSXSAVE   (1 << 27)
#define CPUID_AVX       (1 << 28)
#define CPUID_F16C      (1 << 29)
#define CPUID_RDRAND    (1 << 30)

/* Extended features (EBX from CPUID 7) */
#define CPUID_FSGSBASE  (1 << 0)
#define CPUID_BMI1      (1 << 3)
#define CPUID_HLE       (1 << 4)
#define CPUID_AVX2      (1 << 5)
#define CPUID_SMEP      (1 << 7)
#define CPUID_BMI2      (1 << 8)
#define CPUID_ERMS      (1 << 9)
#define CPUID_INVPCID   (1 << 10)
#define CPUID_RTM       (1 << 11)
#define CPUID_MPX       (1 << 14)
#define CPUID_AVX512F   (1 << 16)
#define CPUID_AVX512DQ  (1 << 17)
#define CPUID_RDSEED    (1 << 18)
#define CPUID_ADX       (1 << 19)
#define CPUID_SMAP      (1 << 20)
#define CPUID_AVX512IFMA (1 << 21)
#define CPUID_CLFLUSHOPT (1 << 23)
#define CPUID_CLWB      (1 << 24)
#define CPUID_AVX512PF  (1 << 26)
#define CPUID_AVX512ER  (1 << 27)
#define CPUID_AVX512CD  (1 << 28)
#define CPUID_SHA       (1 << 29)
#define CPUID_AVX512BW  (1 << 30)
#define CPUID_AVX512VL  (1 << 31)

/* ============================================================================
 * x86_64 PAGING STRUCTURES
 * ============================================================================ */

/* PML4 Entry (Page Map Level 4) */
typedef uint64 pml4e;
#define PML4E_ADDR(e)   ((e) & 0x000FFFFFFFFFF000)
#define PML4E_FLAGS(e)  ((e) & 0xFFF)
#define PML4E_PRESENT   PT_PRESENT
#define PML4E_WRITABLE  PT_WRITABLE
#define PML4E_USER      PT_USER
#define PML4E_NX        PT_NX

/* PDPT Entry (Page Directory Pointer Table) */
typedef uint64 pdpte;
#define PDPTE_ADDR(e)   ((e) & 0x000FFFFFFFFFF000)
#define PDPTE_FLAGS(e)  ((e) & 0xFFF)
#define PDPTE_PAGESIZE  PT_PAGESIZE  // 1GB page if set

/* PDE Entry (Page Directory) */
typedef uint64 pde;
#define PDE_ADDR(e)     ((e) & 0x000FFFFFFFFFF000)
#define PDE_FLAGS(e)    ((e) & 0xFFF)
#define PDE_PAGESIZE    PT_PAGESIZE  // 2MB page if set

/* PTE Entry (Page Table) */
typedef uint64 pte;
#define PTE_ADDR(e)     ((e) & 0x000FFFFFFFFFF000)
#define PTE_FLAGS(e)    ((e) & 0xFFF)

/* Page table structures */
struct __packed page_table {
    pte entries[512];
};

struct __packed page_directory {
    pde entries[512];
};

struct __packed page_directory_pointer {
    pdpte entries[512];
};

struct __packed page_map_level4 {
    pml4e entries[512];
};

/* Page table indices from virtual address */
#define PML4_INDEX(vaddr) (((vaddr) >> 39) & 0x1FF)
#define PDPT_INDEX(vaddr) (((vaddr) >> 30) & 0x1FF)
#define PD_INDEX(vaddr)   (((vaddr) >> 21) & 0x1FF)
#define PT_INDEX(vaddr)   (((vaddr) >> 12) & 0x1FF)

/* ============================================================================
 * x86_64 GDT/IDT/TSS
 * ============================================================================ */

/* GDT selectors */
#define GDT_NULL        0x00
#define GDT_KERNEL_CODE 0x08  // Ring 0 code
#define GDT_KERNEL_DATA 0x10  // Ring 0 data
#define GDT_USER_CODE   0x18  // Ring 3 code
#define GDT_USER_DATA   0x20  // Ring 3 data
#define GDT_TSS         0x28  // Task State Segment

/* TSS IO Map size */
#define TSS_IOMAP_SIZE  0x2000  // 8KB for 65536 ports

/* IST (Interrupt Stack Table) indices */
#define IST_NONE        0
#define IST_DOUBLE_FAULT 1
#define IST_NMI         2
#define IST_MCE         3
#define IST_DEBUG       4
#define IST_STACK_FAULT 5
#define IST_GP_FAULT    6
#define IST_PAGE_FAULT  7

/* ============================================================================
 * x86_64 SYSCALL/SYSRET
 * ============================================================================ */

/* STAR MSR (0xC0000081) - SYSCALL/SYSRET segments */
#define MSR_STAR        0xC0000081

/* LSTAR MSR (0xC0000082) - SYSCALL target RIP */
#define MSR_LSTAR       0xC0000082

/* CSTAR MSR (0xC0000083) - Compatibility mode target */
#define MSR_CSTAR       0xC0000083

/* SFMASK MSR (0xC0000084) - RFLAGS mask */
#define MSR_SFMASK      0xC0000084

/* Kernel GS Base */
#define MSR_KERNEL_GS_BASE  0xC0000102

/* FS Base */
#define MSR_FS_BASE     0xC0000100

/* GS Base */
#define MSR_GS_BASE     0xC0000101

/* EFER MSR (0xC0000080) - Extended Feature Enable Register */
#define MSR_EFER        0xC0000080
#define EFER_SYSCALL    (1 << 0)   // SYSCALL enable
#define EFER_LME        (1 << 8)   // Long Mode Enable
#define EFER_LMA        (1 << 10)  // Long Mode Active
#define EFER_NXE        (1 << 11)  // No-Execute Enable
#define EFER_SVME       (1 << 12)  // Secure Virtual Machine
#define EFER_LMSLE      (1 << 13)  // Long Mode Segment Limit Enable
#define EFER_FFXSR      (1 << 14)  // Fast FXSAVE/FXRSTOR
#define EFER_TCE        (1 << 15)  // Translation Cache Extension

/* ============================================================================
 * x86_64 CPU INITIALIZATION
 * ============================================================================ */

/* Enable PAE (Physical Address Extension) */
static __forceinline void enable_pae(void) {
    write_cr4(read_cr4() | (1 << 5));
}

/* Enable PGE (Page Global Enable) */
static __forceinline void enable_pge(void) {
    write_cr4(read_cr4() | (1 << 7));
}

/* Enable PCE (Performance Monitoring Counter Enable) */
static __forceinline void enable_pce(void) {
    write_cr4(read_cr4() | (1 << 8));
}

/* Enable OSFXSR (FXSAVE/FXRSTOR) */
static __forceinline void enable_osfxsr(void) {
    write_cr4(read_cr4() | (1 << 9));
}

/* Enable OSXMMEXCPT (SSE exceptions) */
static __forceinline void enable_osxmmexcpt(void) {
    write_cr4(read_cr4() | (1 << 10));
}

/* Enable UMIP (User Mode Instruction Prevention) */
static __forceinline void enable_umip(void) {
    write_cr4(read_cr4() | (1 << 11));
}

/* Enable VMXE (Virtual Machine Extensions) */
static __forceinline void enable_vmx(void) {
    write_cr4(read_cr4() | (1 << 13));
}

/* Enable SMXE (Safer Mode Extensions) */
static __forceinline void enable_smx(void) {
    write_cr4(read_cr4() | (1 << 14));
}

/* Enable PCIDE (PCID Enable) */
static __forceinline void enable_pcide(void) {
    write_cr4(read_cr4() | (1 << 17));
}

/* Enable OSXSAVE (XSAVE enable) */
static __forceinline void enable_osxsave(void) {
    write_cr4(read_cr4() | (1 << 18));
}

/* Enable SMEP (Supervisor Mode Execution Prevention) */
static __forceinline void enable_smep(void) {
    write_cr4(read_cr4() | (1 << 20));
}

/* Enable SMAP (Supervisor Mode Access Prevention) */
static __forceinline void enable_smap(void) {
    write_cr4(read_cr4() | (1 << 21));
}

/* Enable PKE (Protection Key Enable) */
static __forceinline void enable_pke(void) {
    write_cr4(read_cr4() | (1 << 22));
}

/* Enable CET (Control-flow Enforcement Technology) */
static __forceinline void enable_cet(void) {
    write_cr4(read_cr4() | (1 << 23));
}

/* Enable PKS (Protection Key for Supervisor) */
static __forceinline void enable_pks(void) {
    write_cr4(read_cr4() | (1 << 24));
}

/* ============================================================================
 * x86_64 LONG MODE
 * ============================================================================ */

/* Enable long mode (set EFER.LME) */
static __forceinline void enable_long_mode(void) {
    uint64 efer = rdmsr(MSR_EFER);
    wrmsr(MSR_EFER, efer | EFER_LME);
}

/* Check if long mode is active */
static __forceinline bool long_mode_active(void) {
    return (rdmsr(MSR_EFER) & EFER_LMA) != 0;
}

/* Enable SYSCALL instruction */
static __forceinline void enable_syscall(void) {
    uint64 efer = rdmsr(MSR_EFER);
    wrmsr(MSR_EFER, efer | EFER_SYSCALL);
}

/* Setup SYSCALL/SYSRET segments */
static __forceinline void setup_syscall(uint64 kernel_rip, uint16 kernel_cs, uint16 user_cs) {
    // STAR: [47:32] = user CS, [31:16] = kernel CS
    uint64 star = ((uint64)user_cs << 48) | ((uint64)kernel_cs << 32);
    wrmsr(MSR_STAR, star);
    wrmsr(MSR_LSTAR, kernel_rip);
    wrmsr(MSR_SFMASK, 0x200);  // Mask IF flag
}

/* ============================================================================
 * x86_64 PAGING
 * ============================================================================ */

/* Get current PML4 */
static __forceinline page_map_level4* get_pml4(void) {
    return (page_map_level4*)phys_to_virt(read_cr3() & 0x000FFFFFFFFFF000);
}

/* Set PML4 */
static __forceinline void set_pml4(phys_addr pml4_phys) {
    write_cr3(pml4_phys);
}

/* Create page table entry */
static __forceinline pte make_pte(phys_addr phys, uint64 flags) {
    return (phys & 0x000FFFFFFFFFF000) | (flags & 0xFFF);
}

/* Create page directory entry */
static __forceinline pde make_pde(phys_addr phys, uint64 flags) {
    return (phys & 0x000FFFFFFFFFF000) | (flags & 0xFFF);
}

/* Create PDPT entry */
static __forceinline pdpte make_pdpte(phys_addr phys, uint64 flags) {
    return (phys & 0x000FFFFFFFFFF000) | (flags & 0xFFF);
}

/* Create PML4 entry */
static __forceinline pml4e make_pml4e(phys_addr phys, uint64 flags) {
    return (phys & 0x000FFFFFFFFFF000) | (flags & 0xFFF);
}

/* ============================================================================
 * x86_64 TASK STATE SEGMENT
 * ============================================================================ */

static __forceinline void load_tss(uint16 selector) {
    ltr(selector);
}

static __forceinline void set_kernel_stack(uint64 rsp0) {
    tss_entry *tss = (tss_entry*)phys_to_virt(0);  // TODO: actual TSS address
    tss->rsp0 = rsp0;
}

/* ============================================================================
 * x86_64 CONTEXT SWITCH
 * ============================================================================ */

struct cpu_context {
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
    uint64 rip;
    uint64 cs;
    uint64 rflags;
    uint64 rsp;
    uint64 ss;
};

/* Save context (inline assembly) */
#define save_context(ctx) \
    __asm__ __volatile__ ( \
        "push %%rax\n\t" \
        "mov %0, %%rax\n\t" \
        "mov %%rbx, 0(%%rax)\n\t" \
        "pop %%rbx\n\t" \
        "mov %%rbx, 8(%%rax)\n\t" \
        /* ... more registers ... */ \
        ::: "memory" \
    )

/* Restore context */
#define restore_context(ctx) \
    __asm__ __volatile__ ( \
        "mov %0, %%rax\n\t" \
        "mov 0(%%rax), %%rbx\n\t" \
        /* ... more registers ... */ \
        ::: "memory" \
    )

/* ============================================================================
 * x86_64 INTERRUPT HANDLER MACROS
 * ============================================================================ */

/* ISR stub without error code */
#define ISR_STUB_NOERR(num) \
    __asm__ ( \
        "isr" #num ":\n\t" \
        "push $0\n\t" \
        "push $" #num "\n\t" \
        "jmp isr_common\n\t" \
    )

/* ISR stub with error code */
#define ISR_STUB_ERR(num) \
    __asm__ ( \
        "isr" #num ":\n\t" \
        "push $" #num "\n\t" \
        "jmp isr_common\n\t" \
    )

/* IRQ stub */
#define IRQ_STUB(num) \
    __asm__ ( \
        "irq" #num ":\n\t" \
        "push $0\n\t" \
        "push $" #num "\n\t" \
        "jmp irq_common\n\t" \
    )

/* ============================================================================
 * x86_64 IPI (Inter-Processor Interrupt)
 * ============================================================================ */

#define IPI_VECTOR_PANIC        0xFD
#define IPI_VECTOR_HALT         0xFC
#define IPI_VECTOR_TLB_SHOOTDOWN 0xFB
#define IPI_VECTOR_RESCHEDULE   0xFA
#define IPI_VECTOR_CALL_FUNC    0xF9

static __forceinline void send_ipi(uint32 apic_id, uint8 vector) {
    // Wait for ICR to be ready
    while (lapic_read(0x300) & (1 << 12));
    
    // Set destination
    lapic_write(0x310, apic_id << 24);
    
    // Send IPI (fixed delivery, assert, physical destination)
    lapic_write(0x300, vector | 0x4000);
}

static __forceinline void broadcast_ipi(uint8 vector) {
    while (lapic_read(0x300) & (1 << 12));
    lapic_write(0x300, vector | 0x8000);  // All excluding self
}

static __forceinline void broadcast_ipi_all(uint8 vector) {
    while (lapic_read(0x300) & (1 << 12));
    lapic_write(0x300, vector | 0xC000);  // All including self
}

/* ============================================================================
 * x86_64 PCI CONFIGURATION SPACE ACCESS
 * ============================================================================ */

/* PCI Express enhanced configuration (MMIO) */
#define PCI_ECAM_BASE 0xE0000000

static __forceinline uint32 pci_ecam_read(uint8 bus, uint8 dev, uint8 func, uint16 offset) {
    uint64 addr = PCI_ECAM_BASE | ((uint64)bus << 20) | ((uint64)dev << 15) | 
                  ((uint64)func << 12) | offset;
    return *(volatile uint32*)addr;
}

static __forceinline void pci_ecam_write(uint8 bus, uint8 dev, uint8 func, uint16 offset, uint32 val) {
    uint64 addr = PCI_ECAM_BASE | ((uint64)bus << 20) | ((uint64)dev << 15) | 
                  ((uint64)func << 12) | offset;
    *(volatile uint32*)addr = val;
}

/* ============================================================================
 * x86_64 HPET (High Precision Event Timer)
 * ============================================================================ */

#define HPET_BASE 0xFED00000

#define HPET_GEN_CAP    0x00
#define HPET_GEN_CONFIG 0x10
#define HPET_GEN_INT_STATUS 0x20
#define HPET_MAIN_COUNTER 0xF0
#define HPET_TIMER_CONFIG(n) (0x100 + (n) * 0x20)
#define HPET_TIMER_COMPARATOR(n) (0x108 + (n) * 0x20)
#define HPET_TIMER_FSB_ROUTE(n) (0x110 + (n) * 0x20)

static __forceinline uint64 hpet_read(uint32 reg) {
    return *(volatile uint64*)(HPET_BASE + reg);
}

static __forceinline void hpet_write(uint32 reg, uint64 val) {
    *(volatile uint64*)(HPET_BASE + reg) = val;
}

static __forceinline void hpet_enable(void) {
    uint64 cfg = hpet_read(HPET_GEN_CONFIG);
    hpet_write(HPET_GEN_CONFIG, cfg | 1);
}

static __forceinline void hpet_disable(void) {
    uint64 cfg = hpet_read(HPET_GEN_CONFIG);
    hpet_write(HPET_GEN_CONFIG, cfg & ~1);
}

static __forceinline uint64 hpet_counter(void) {
    return hpet_read(HPET_MAIN_COUNTER);
}

/* ============================================================================
 * x86_64 ACPI
 * ============================================================================ */

/* RSDP (Root System Description Pointer) */
struct __packed acpi_rsdp {
    char signature[8];      // "RSD PTR "
    uint8 checksum;
    char oem_id[6];
    uint8 revision;
    uint32 rsdt_addr;       // 32-bit
    uint32 length;          // ACPI 2.0+
    uint64 xsdt_addr;       // 64-bit
    uint8 ext_checksum;
    uint8 reserved[3];
};

/* SDT Header */
struct __packed acpi_sdt_header {
    char signature[4];
    uint32 length;
    uint8 revision;
    uint8 checksum;
    char oem_id[6];
    char oem_table_id[8];
    uint32 oem_revision;
    uint32 creator_id;
    uint32 creator_revision;
};

/* MADT (Multiple APIC Description Table) */
#define MADT_TYPE_LOCAL_APIC    0
#define MADT_TYPE_IO_APIC       1
#define MADT_TYPE_INT_SRC_OVERRIDE 2
#define MADT_TYPE_NMI_SRC       3
#define MADT_TYPE_LOCAL_APIC_NMI 4
#define MADT_TYPE_LOCAL_APIC_OVERRIDE 5
#define MADT_TYPE_IO_SAPIC      6
#define MADT_TYPE_LOCAL_SAPIC   7
#define MADT_TYPE_INT_SRC       8
#define MADT_TYPE_LOCAL_X2APIC  9
#define MADT_TYPE_LOCAL_X2APIC_NMI 10

struct __packed madt_entry_header {
    uint8 type;
    uint8 length;
};

struct __packed madt_local_apic {
    madt_entry_header header;
    uint8 acpi_processor_id;
    uint8 apic_id;
    uint32 flags;
};

struct __packed madt_io_apic {
    madt_entry_header header;
    uint8 io_apic_id;
    uint8 reserved;
    uint32 io_apic_addr;
    uint32 global_int_base;
};

/* ============================================================================
 * x86_64 SMP (Symmetric Multi-Processing)
 * ============================================================================ */

#define SMP_TRAMPOLINE_ADDR 0x1000
#define SMP_STACK_SIZE 0x10000  // 64KB per CPU

/* CPU info */
struct cpu_info {
    uint32 apic_id;
    uint32 acpi_id;
    uint32 flags;
    uint64 stack_top;
    uint64 current_thread;
    uint64 idle_thread;
    uint64 syscall_count;
    uint64 interrupt_count;
    uint64 timer_ticks;
    bool online;
    bool bsp;  // Bootstrap processor
};

#define CPU_MAX 256
extern cpu_info cpu_table[CPU_MAX];
extern uint32 cpu_count;

/* Get current CPU info */
static __forceinline cpu_info* current_cpu(void) {
    uint64 gs_base;
    __asm__ __volatile__ ("rdgsbase %0" : "=r"(gs_base));
    return (cpu_info*)gs_base;
}

/* Get current CPU ID */
static __forceinline uint32 cpu_id(void) {
    return current_cpu()->apic_id;
}

/* Check if BSP */
static __forceinline bool is_bsp(void) {
    return current_cpu()->bsp;
}

/* ============================================================================
 * x86_64 VIRTUALIZATION (VMX)
 * ============================================================================ */

#define VMX_BASIC_MSR           0x480
#define VMX_CR0_FIXED0_MSR      0x486
#define VMX_CR0_FIXED1_MSR      0x487
#define VMX_CR4_FIXED0_MSR      0x488
#define VMX_CR4_FIXED1_MSR      0x489
#define VMX_VMCS_ENUM_MSR       0x48A
#define VMX_PROCBASED_CTLS2_MSR 0x48B
#define VMX_EPT_VPID_CAP_MSR   0x48C
#define VMX_TRUE_PINBASED_CTLS_MSR 0x48D
#define VMX_TRUE_PROCBASED_CTLS_MSR 0x48E
#define VMX_TRUE_EXIT_CTLS_MSR  0x48F
#define VMX_TRUE_ENTRY_CTLS_MSR 0x490

/* VMX instructions */
#define vmxon(addr) __asm__ __volatile__ ("vmxon %0" :: "m"(addr) : "cc", "memory")
#define vmxoff() __asm__ __volatile__ ("vmxoff" ::: "cc", "memory")
#define vmclear(addr) __asm__ __volatile__ ("vmclear %0" :: "m"(addr) : "cc", "memory")
#define vmptrld(addr) __asm__ __volatile__ ("vmptrld %0" :: "m"(addr) : "cc", "memory")
#define vmptrst(addr) __asm__ __volatile__ ("vmptrst %0" : "=m"(addr) :: "memory")
#define vmread(field, val) __asm__ __volatile__ ("vmread %1, %0" : "=r"(val) : "r"(field))
#define vmwrite(field, val) __asm__ __volatile__ ("vmwrite %1, %0" :: "r"(val), "r"(field))
#define vmlaunch() __asm__ __volatile__ ("vmlaunch" ::: "cc", "memory")
#define vmresume() __asm__ __volatile__ ("vmresume" ::: "cc", "memory")

/* ============================================================================
 * x86_64 POWER MANAGEMENT
 * ============================================================================ */

/* Halt state */
static __forceinline void cpu_halt(void) {
    __asm__ __volatile__ ("sti; hlt");
}

/* Sleep state (C-states) */
#define CSTATE_C1 0x01  // Halt
#define CSTATE_C2 0x02  // Stop clock
#define CSTATE_C3 0x03  // Sleep
#define CSTATE_C6 0x06  // Deep sleep
#define CSTATE_C7 0x07  // Deeper sleep

static __forceinline void enter_cstate(uint8 state) {
    // Use MWAIT or HLT with monitor
    uint64 rax = state;
    __asm__ __volatile__ ("mwait" :: "a"(rax), "c"(0));
}

/* Frequency scaling (P-states) */
static __forceinline void set_pstate(uint8 state) {
    wrmsr(0x199, state);  // IA32_PERF_CTL
}

/* ============================================================================
 * x86_64 PERFORMANCE MONITORING
 * ============================================================================ */

#define PERF_EVTSEL0 0x186
#define PERF_EVTSEL1 0x187
#define PERF_CTR0    0xC1
#define PERF_CTR1    0xC2
#define PERF_FIXED_CTR_CTRL 0x38D
#define PERF_FIXED_CTR0 0x309  // Instructions retired
#define PERF_FIXED_CTR1 0x30A  // Core cycles
#define PERF_FIXED_CTR2 0x30B  // Reference cycles

static __forceinline void perf_counter_start(uint32 counter, uint64 event) {
    wrmsr(PERF_EVTSEL0 + counter, event | (1 << 22) | (1 << 16));  // Enable + OS mode
}

static __forceinline uint64 perf_counter_read(uint32 counter) {
    return rdmsr(PERF_CTR0 + counter);
}

static __forceinline void perf_counter_stop(uint32 counter) {
    wrmsr(PERF_EVTSEL0 + counter, 0);
}

/* ============================================================================
 * x86_64 RANDOM NUMBER GENERATION
 * ============================================================================ */

/* RDRAND (hardware random) */
static __forceinline bool rdrand(uint64 *val) {
    uint8 success;
    __asm__ __volatile__ ("rdrand %0; setc %1"
        : "=r"(*val), "=qm"(success));
    return success;
}

/* RDSEED (entropy seed) */
static __forceinline bool rdseed(uint64 *val) {
    uint8 success;
    __asm__ __volatile__ ("rdseed %0; setc %1"
        : "=r"(*val), "=qm"(success));
    return success;
}

/* ============================================================================
 * x86_64 TIMESTAMP COUNTER
 * ============================================================================ */

/* Read TSC with CPUID serialization */
static __forceinline uint64 rdtsc_serialized(void) {
    uint32 eax, edx;
    __asm__ __volatile__ ("cpuid\n\t"
                           "rdtsc\n\t"
                           "mov %%edx, %0\n\t"
                           "mov %%eax, %1\n\t"
                           "cpuid\n\t"
        : "=r"(edx), "=r"(eax)
        :: "eax", "ebx", "ecx", "edx");
    return ((uint64)edx << 32) | eax;
}

/* Invariant TSC (constant rate, not affected by P-states) */
static __forceinline bool invariant_tsc(void) {
    uint32 eax, ebx, ecx, edx;
    cpuid(0x80000007, &eax, &ebx, &ecx, &edx);
    return (edx & (1 << 8)) != 0;
}

/* ============================================================================
 * x86_64 UEFI/GOP FRAMEBUFFER
 * ============================================================================ */

struct framebuffer_info {
    uint64 base;
    uint32 width;
    uint32 height;
    uint32 pitch;
    uint8 bpp;
    uint8 red_mask_size;
    uint8 red_mask_pos;
    uint8 green_mask_size;
    uint8 green_mask_pos;
    uint8 blue_mask_size;
    uint8 blue_mask_pos;
    uint8 reserved_mask_size;
    uint8 reserved_mask_pos;
};

/* Plot pixel in framebuffer */
static __forceinline void fb_putpixel(framebuffer_info *fb, uint32 x, uint32 y, uint32 color) {
    uint32 *pixel = (uint32*)(fb->base + y * fb->pitch + x * (fb->bpp / 8));
    *pixel = color;
}

/* ============================================================================
 * END OF x86_64 HEADER
 * ============================================================================ */

#endif /* X86_64_PP_H */