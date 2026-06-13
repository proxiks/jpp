; jpp Bootloader

BITS 16
ORG 0x7C00

jmp short start
nop

OEMName:                db 'J++ OS  '
BytesPerSector:        dw 512
SectorsPerCluster:     db 1
ReservedSectors:       dw 1
TotalFATs:             db 2
RootEntries:           dw 224
TotalSectorsSmall:     dw 2880
MediaDescriptor:       db 0xF0
SectorsPerFAT:         dw 9
SectorsPerTrack:       dw 18
NumHeads:              dw 2
HiddenSectors:         dd 0
TotalSectorsLarge:     dd 0
DriveNum:              db 0x00
Reserved1:             db 0x00
BootSignature:         db 0x29
VolumeID:              dd 0x12345678
VolumeLabel:           db 'J++ BOOT   '
FileSystemType:        db 'FAT12   '

; ============================================================================
; BOOTLOADER START
; ============================================================================

start:
    ; Save boot drive
    mov [BootDrive], dl
    
    ; Setup segments
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    
    ; Setup stack at 0x7C00 (grows down)
    mov sp, 0x7C00
    
    ; Clear screen
    mov ax, 0x0003
    int 0x10
    
    ; Print boot message
    mov si, msg_booting
    call print_string_16
    
    ; Enable A20 line
    call enable_a20
    
    ; Load kernel from disk
    mov si, msg_loading
    call print_string_16
    
    call load_kernel
    jc load_error
    
    mov si, msg_ok
    call print_string_16
    
    ; Print memory info
    call print_memory_info
    
    ; Switch to protected mode
    mov si, msg_protmode
    call print_string_16
    
    call enter_protected_mode
    
; ============================================================================
; 16-BIT UTILITY FUNCTIONS
; ============================================================================

; Print string in real mode
; SI = string pointer
print_string_16:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    jmp .loop
.done:
    popa
    ret

; Print hex byte
; AL = byte to print
print_hex_16:
    pusha
    mov cx, 2
    mov bl, al
.loop:
    rol bl, 4
    mov al, bl
    and al, 0x0F
    cmp al, 10
    jl .digit
    add al, 'A' - 10 - '0'
.digit:
    add al, '0'
    mov ah, 0x0E
    int 0x10
    loop .loop
    popa
    ret

; Print newline
print_newline_16:
    pusha
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    popa
    ret

; Enable A20 line using keyboard controller
enable_a20:
    pusha
    
    ; Try BIOS method first
    mov ax, 0x2401
    int 0x15
    jc .keyboard_method
    
    ; Verify A20 is enabled
    call test_a20
    jnc .done
    
.keyboard_method:
    ; Disable keyboard
    call wait_keyboard
    mov al, 0xAD
    out 0x64, al
    
    ; Read output port
    call wait_keyboard
    mov al, 0xD0
    out 0x64, al
    
    call wait_keyboard_data
    in al, 0x60
    push ax
    
    ; Write output port with A20 enabled
    call wait_keyboard
    mov al, 0xD1
    out 0x64, al
    
    call wait_keyboard
    pop ax
    or al, 2
    out 0x60, al
    
    ; Enable keyboard
    call wait_keyboard
    mov al, 0xAE
    out 0x64, al
    
    call wait_keyboard
    
    ; Fast A20 method
    in al, 0x92
    or al, 2
    out 0x92, al
    
.done:
    popa
    ret

wait_keyboard:
    in al, 0x64
    test al, 2
    jnz wait_keyboard
    ret

wait_keyboard_data:
    in al, 0x64
    test al, 1
    jz wait_keyboard_data
    ret

test_a20:
    pusha
    push es
    push ds
    
    xor ax, ax
    mov es, ax
    mov ds, ax
    
    ; Save original values
    mov di, 0x0500
    mov si, 0x0510
    
    mov al, [es:di]
    push ax
    mov al, [ds:si]
    push ax
    
    ; Test wraparound
    mov byte [es:di], 0x00
    mov byte [ds:si], 0xFF
    
    cmp byte [es:di], 0xFF
    
    pop ax
    mov [ds:si], al
    pop ax
    mov [es:di], al
    
    pop ds
    pop es
    popa
    ret

; Load kernel from disk using LBA
load_kernel:
    pusha
    
    ; Try INT 13h AH=42h (Extended Read)
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [BootDrive]
    int 0x13
    jc .chs_method
    cmp bx, 0xAA55
    jne .chs_method
    
    ; Use LBA
    mov si, DAP
    mov ah, 0x42
    mov dl, [BootDrive]
    int 0x13
    jc load_error
    jmp .done
    
.chs_method:
    ; Use CHS (Cylinder-Head-Sector)
    ; Load 64 sectors (32KB) starting from sector 2
    mov ah, 0x02
    mov al, 64
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [BootDrive]
    mov bx, KERNEL_LOAD_ADDR
    int 0x13
    jc load_error
    
.done:
    popa
    ret

; Disk Address Packet (DAP)
DAP:
    db 0x10                 ; Size of packet
    db 0                  ; Reserved
    dw 64                 ; Number of sectors to read
    dw KERNEL_LOAD_ADDR   ; Offset
    dw 0                  ; Segment
    dd 1                  ; Start LBA (sector 1, after boot sector)
    dd 0                  ; Upper 32 bits of LBA

; Print memory info using INT 12h and INT 15h
print_memory_info:
    pusha
    
    mov si, msg_memory
    call print_string_16
    
    ; Get conventional memory size (KB)
    int 0x12
    mov [ConvMemory], ax
    
    ; Print low memory
    mov si, msg_low_mem
    call print_string_16
    mov ax, [ConvMemory]
    call print_int_16
    mov si, msg_kb
    call print_string_16
    
    ; Get extended memory using INT 15h AH=88h
    mov ah, 0x88
    int 0x15
    jc .no_ext
    mov [ExtMemory], ax
    
    mov si, msg_ext_mem
    call print_string_16
    mov ax, [ExtMemory]
    call print_int_16
    mov si, msg_kb
    call print_string_16
    jmp .done
    
.no_ext:
    mov si, msg_no_ext
    call print_string_16
    
.done:
    popa
    ret

; Print integer in 16-bit mode
; AX = number
print_int_16:
    pusha
    mov cx, 0
    mov bx, 10
    
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide
    
.print:
    pop ax
    add al, '0'
    mov ah, 0x0E
    int 0x10
    loop .print
    
    popa
    ret

; ============================================================================
; PROTECTED MODE TRANSITION
; ============================================================================

enter_protected_mode:
    ; Disable interrupts
    cli
    
    ; Load GDT
    lgdt [GDT_Descriptor]
    
    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Far jump to 32-bit code
    jmp CODE_SEG:protected_mode_32

; ============================================================================
; GLOBAL DESCRIPTOR TABLE (GDT)
; ============================================================================

GDT_Start:
    ; Null descriptor
    dq 0
    
    ; Code segment (32-bit)
    dw 0xFFFF           ; Limit (bits 0-15)
    dw 0                ; Base (bits 0-15)
    db 0                ; Base (bits 16-23)
    db 10011010b        ; Access byte
    db 11001111b        ; Flags + Limit (bits 16-19)
    db 0                ; Base (bits 24-31)
    
    ; Data segment (32-bit)
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0
    
    ; Code segment (64-bit)
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 10101111b        ; 64-bit flag
    db 0
    
    ; Data segment (64-bit)
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 10101111b
    db 0
GDT_End:

GDT_Descriptor:
    dw GDT_End - GDT_Start - 1
    dd GDT_Start

CODE_SEG equ 0x08
DATA_SEG equ 0x10
CODE_SEG_64 equ 0x18
DATA_SEG_64 equ 0x20

; ============================================================================
; 32-BIT PROTECTED MODE
; ============================================================================

BITS 32

protected_mode_32:
    ; Setup segments
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Setup stack in higher memory
    mov esp, 0x90000
    
    ; Print 32-bit message
    mov esi, msg_32bit
    call print_string_32
    
    ; Check CPUID
    call check_cpuid
    jc no_cpuid
    
    ; Check long mode
    call check_long_mode
    jc no_long_mode
    
    ; Setup paging
    call setup_paging
    
    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    
    ; Enable long mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr
    
    ; Enable paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax
    
    ; Jump to 64-bit code
    jmp CODE_SEG_64:long_mode_64

; 32-bit print string
; ESI = string
print_string_32:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov ebx, 0x0007
    int 0x10
    jmp .loop
.done:
    popa
    ret

; Check CPUID support
check_cpuid:
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21
    push eax
    popfd
    pushfd
    pop eax
    xor eax, ecx
    jz .no_cpuid
    push ecx
    popfd
    clc
    ret
.no_cpuid:
    stc
    ret

; Check long mode support
check_long_mode:
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long_mode
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz .no_long_mode
    clc
    ret
.no_long_mode:
    stc
    ret

; Setup identity paging (PML4 → PDPT → PD → PT)
setup_paging:
    ; Clear page tables
    mov edi, PML4_ADDR
    mov ecx, 4096
    xor eax, eax
    rep stosd
    
    ; PML4[0] → PDPT
    mov eax, PDPT_ADDR
    or eax, 0x03        ; Present + Writable
    mov [PML4_ADDR], eax
    
    ; PDPT[0] → PD
    mov eax, PD_ADDR
    or eax, 0x03
    mov [PDPT_ADDR], eax
    
    ; PD[0] → PT
    mov eax, PT_ADDR
    or eax, 0x03
    mov [PD_ADDR], eax
    
    ; Identity map first 2MB (512 pages)
    mov edi, PT_ADDR
    mov eax, 0x03
    mov ecx, 512
.loop:
    mov [edi], eax
    add eax, 0x1000
    add edi, 8
    loop .loop
    
    ; Load PML4 into CR3
    mov eax, PML4_ADDR
    mov cr3, eax
    ret

; ============================================================================
; 64-BIT LONG MODE
; ============================================================================

BITS 64

long_mode_64:
    ; Setup 64-bit segments
    mov ax, DATA_SEG_64
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Setup 64-bit stack
    mov rsp, 0x200000
    
    ; Print 64-bit message
    mov rsi, msg_64bit
    call print_string_64
    
    ; Parse kernel ELF
    mov rdi, KERNEL_LOAD_ADDR
    call parse_elf
    
    ; Jump to kernel
    mov rsi, msg_jumping
    call print_string_64
    
    ; Pass boot info to kernel
    mov rdi, BOOT_INFO_ADDR
    
    ; Call kernel
    call [KernelEntry]
    
    ; Should never reach here
    jmp crash_dump

; 64-bit print string
; RSI = string
print_string_64:
    push rax
    push rdx
    push rdi
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp .loop
.done:
    pop rdi
    pop rdx
    pop rax
    ret

; Parse ELF64 kernel
; RDI = kernel address
parse_elf:
    pusha
    
    ; Check ELF magic
    mov eax, [rdi]
    cmp eax, 0x464C457F       ; \x7FELF
    jne .not_elf
    
    ; Check 64-bit
    mov al, [rdi + 4]
    cmp al, 2
    jne .not_elf
    
    ; Check little endian
    mov al, [rdi + 5]
    cmp al, 1
    jne .not_elf
    
    ; Get entry point
    mov rax, [rdi + 24]       ; e_entry
    mov [KernelEntry], rax
    
    ; Get program header offset
    mov rdx, [rdi + 32]       ; e_phoff
    add rdx, rdi
    
    ; Get number of program headers
    mov cx, [rdi + 56]        ; e_phnum
    
    ; Process each segment
.loop:
    test cx, cx
    jz .done
    dec cx
    
    ; Check if loadable (PT_LOAD = 1)
    mov eax, [rdx]
    cmp eax, 1
    jne .next
    
    ; Copy segment to memory
    mov rsi, [rdx + 8]        ; p_offset
    add rsi, rdi
    mov r8, [rdx + 16]        ; p_vaddr
    mov r9, [rdx + 32]        ; p_filesz
    mov r10, [rdx + 40]       ; p_memsz
    
    ; Copy file content
    mov rcx, r9
    rep movsb
    
    ; Zero remaining memory
    mov rcx, r10
    sub rcx, r9
    test rcx, rcx
    jz .next
    xor al, al
    rep stosb
    
.next:
    add rdx, 56               ; Size of Elf64_Phdr
    jmp .loop
    
.done:
    popa
    ret
    
.not_elf:
    ; Assume flat binary at 0x100000
    mov qword [KernelEntry], 0x100000
    popa
    ret

; ============================================================================
; CRASH DUMP SYSTEM
; ============================================================================

crash_dump:
    ; Save all registers
    mov [CrashRAX], rax
    mov [CrashRBX], rbx
    mov [CrashRCX], rcx
    mov [CrashRDX], rdx
    mov [CrashRSI], rsi
    mov [CrashRDI], rdi
    mov [CrashRBP], rbp
    mov [CrashRSP], rsp
    mov [CrashR8], r8
    mov [CrashR9], r9
    mov [CrashR10], r10
    mov [CrashR11], r11
    mov [CrashR12], r12
    mov [CrashR13], r13
    mov [CrashR14], r14
    mov [CrashR15], r15
    
    ; Save RIP (return address)
    mov rax, [rsp]
    mov [CrashRIP], rax
    
    ; Save RFLAGS
    pushfq
    pop rax
    mov [CrashRFLAGS], rax
    
    ; Save CR registers
    mov rax, cr0
    mov [CrashCR0], rax
    mov rax, cr2
    mov [CrashCR2], rax
    mov rax, cr3
    mov [CrashCR3], rax
    mov rax, cr4
    mov [CrashCR4], rax
    
    ; Print crash banner
    mov rsi, crash_banner
    call print_string_64
    
    ; Print registers
    mov rsi, crash_rax
    call print_string_64
    mov rax, [CrashRAX]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_rbx
    call print_string_64
    mov rax, [CrashRBX]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_rcx
    call print_string_64
    mov rax, [CrashRCX]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_rdx
    call print_string_64
    mov rax, [CrashRDX]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_rsi
    call print_string_64
    mov rax, [CrashRSI]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_rdi
    call print_string_64
    mov rax, [CrashRDI]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_rbp
    call print_string_64
    mov rax, [CrashRBP]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_rsp
    call print_string_64
    mov rax, [CrashRSP]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_rip
    call print_string_64
    mov rax, [CrashRIP]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_rflags
    call print_string_64
    mov rax, [CrashRFLAGS]
    call print_hex_64
    call print_newline_64
    
    ; Print CR registers
    mov rsi, crash_cr0
    call print_string_64
    mov rax, [CrashCR0]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_cr2
    call print_string_64
    mov rax, [CrashCR2]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_cr3
    call print_string_64
    mov rax, [CrashCR3]
    call print_hex_64
    call print_newline_64
    
    mov rsi, crash_cr4
    call print_string_64
    mov rax, [CrashCR4]
    call print_hex_64
    call print_newline_64
    
    ; Print stack trace
    mov rsi, crash_stack
    call print_string_64
    
    mov rbp, [CrashRBP]
    mov rcx, 10                     ; Max 10 frames
.stack_loop:
    test rbp, rbp
    jz .stack_done
    test rcx, rcx
    jz .stack_done
    dec rcx
    
    ; Print frame address
    mov rax, rbp
    call print_hex_64
    
    mov rsi, crash_arrow
    call print_string_64
    
    ; Print return address
    mov rax, [rbp + 8]
    call print_hex_64
    call print_newline_64
    
    mov rbp, [rbp]
    jmp .stack_loop
    
.stack_done:
    
    ; Print memory dump around RIP
    mov rsi, crash_memory
    call print_string_64
    
    mov rsi, [CrashRIP]
    sub rsi, 32
    call print_memory_dump
    
    ; Halt
    mov rsi, crash_halt
    call print_string_64
    
.halt:
    cli
    hlt
    jmp .halt

; Print 64-bit hex
; RAX = value
print_hex_64:
    push rax
    push rcx
    push rdx
    
    mov rcx, 16
.loop:
    rol rax, 4
    mov rdx, rax
    and rdx, 0x0F
    cmp dl, 10
    jl .digit
    add dl, 'A' - 10 - '0'
.digit:
    add dl, '0'
    push rax
    mov al, dl
    mov ah, 0x0E
    int 0x10
    pop rax
    loop .loop
    
    pop rdx
    pop rcx
    pop rax
    ret

; Print newline
print_newline_64:
    push rax
    mov al, 0x0D
    mov ah, 0x0E
    int 0x10
    mov al, 0x0A
    int 0x10
    pop rax
    ret

; Print memory dump
; RSI = start address
print_memory_dump:
    pusha
    mov rcx, 4                      ; 4 lines
.line_loop:
    push rcx
    
    ; Print address
    mov rax, rsi
    call print_hex_64
    
    mov al, ':'
    mov ah, 0x0E
    int 0x10
    mov al, ' '
    int 0x10
    
    ; Print 16 bytes
    mov rcx, 16
.byte_loop:
    movzx rax, byte [rsi]
    call print_hex_byte
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    inc rsi
    loop .byte_loop
    
    call print_newline_64
    pop rcx
    loop .line_loop
    
    popa
    ret

; Print hex byte
; AL = byte
print_hex_byte:
    push rax
    push rcx
    
    mov cl, al
    shr al, 4
    and al, 0x0F
    cmp al, 10
    jl .digit1
    add al, 'A' - 10 - '0'
.digit1:
    add al, '0'
    mov ah, 0x0E
    int 0x10
    
    mov al, cl
    and al, 0x0F
    cmp al, 10
    jl .digit2
    add al, 'A' - 10 - '0'
.digit2:
    add al, '0'
    int 0x10
    
    pop rcx
    pop rax
    ret

; ============================================================================
; ERROR HANDLERS
; ============================================================================

load_error:
    mov si, msg_load_error
    call print_string_16
    jmp halt_16

no_cpuid:
    mov si, msg_no_cpuid
    call print_string_16
    jmp halt_16

no_long_mode:
    mov si, msg_no_long_mode
    call print_string_16
    jmp halt_16

halt_16:
    cli
.halt:
    hlt
    jmp .halt

; ============================================================================
; DATA SECTION
; ============================================================================

section .data

msg_booting:
    db "J++ Bootloader v1.0", 0x0D, 0x0A, 0

msg_loading:
    db "Loading kernel...", 0

msg_ok:
    db " [OK]", 0x0D, 0x0A, 0

msg_protmode:
    db "Entering protected mode...", 0x0D, 0x0A, 0

msg_32bit:
    db "32-bit protected mode active", 0x0D, 0x0A, 0

msg_64bit:
    db "64-bit long mode active", 0x0D, 0x0A, 0

msg_jumping:
    db "Jumping to kernel...", 0x0D, 0x0A, 0

msg_memory:
    db "Memory: ", 0

msg_low_mem:
    db "Low: ", 0

msg_ext_mem:
    db " Extended: ", 0

msg_kb:
    db " KB", 0x0D, 0x0A, 0

msg_no_ext:
    db "No extended memory", 0x0D, 0x0A, 0

msg_load_error:
    db "ERROR: Failed to load kernel", 0x0D, 0x0A, 0

msg_no_cpuid:
    db "ERROR: CPUID not supported", 0x0D, 0x0A, 0

msg_no_long_mode:
    db "ERROR: Long mode not supported", 0x0D, 0x0A, 0

; Crash dump messages
crash_banner:
    db 0x0D, 0x0A
    db "========================================", 0x0D, 0x0A
    db "         KERNEL CRASH DUMP", 0x0D, 0x0A
    db "========================================", 0x0D, 0x0A, 0

crash_rax:
    db "RAX: ", 0

crash_rbx:
    db "RBX: ", 0

crash_rcx:
    db "RCX: ", 0

crash_rdx:
    db "RDX: ", 0

crash_rsi:
    db "RSI: ", 0

crash_rdi:
    db "RDI: ", 0

crash_rbp:
    db "RBP: ", 0

crash_rsp:
    db "RSP: ", 0

crash_rip:
    db "RIP: ", 0

crash_rflags:
    db "RFLAGS: ", 0

crash_cr0:
    db "CR0: ", 0

crash_cr2:
    db "CR2: ", 0

crash_cr3:
    db "CR3: ", 0

crash_cr4:
    db "CR4: ", 0

crash_stack:
    db 0x0D, 0x0A, "Stack Trace:", 0x0D, 0x0A, 0

crash_arrow:
    db " -> ", 0

crash_memory:
    db 0x0D, 0x0A, "Memory at RIP-32:", 0x0D, 0x0A, 0

crash_halt:
    db 0x0D, 0x0A, "System halted.", 0x0D, 0x0A, 0

; ============================================================================
; BSS SECTION - Uninitialized Data
; ============================================================================

section .bss

BootDrive:
    resb 1

ConvMemory:
    resw 1

ExtMemory:
    resw 1

KernelEntry:
    resq 1

; Crash dump register storage
CrashRAX:
    resq 1
CrashRBX:
    resq 1
CrashRCX:
    resq 1
CrashRDX:
    resq 1
CrashRSI:
    resq 1
CrashRDI:
    resq 1
CrashRBP:
    resq 1
CrashRSP:
    resq 1
CrashR8:
    resq 1
CrashR9:
    resq 1
CrashR10:
    resq 1
CrashR11:
    resq 1
CrashR12:
    resq 1
CrashR13:
    resq 1
CrashR14:
    resq 1
CrashR15:
    resq 1
CrashRIP:
    resq 1
CrashRFLAGS:
    resq 1
CrashCR0:
    resq 1
CrashCR2:
    resq 1
CrashCR3:
    resq 1
CrashCR4:
    resq 1

; Page tables (must be page-aligned)
align 4096
PML4_ADDR:
    resq 512

PDPT_ADDR:
    resq 512

PD_ADDR:
    resq 512

PT_ADDR:
    resq 512

; Boot info structure
align 16
BOOT_INFO_ADDR:
    resq 1

; Kernel load address
KERNEL_LOAD_ADDR equ 0x100000

; ============================================================================
; BOOT SIGNATURE
; ============================================================================

times 510-($-$$) db 0
dw 0xAA55