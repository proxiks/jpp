; ============================================================
; GJC SYSCALL TRAMPOLINE - x86_64 Linux
; Assembly bridge between C VM and Linux kernel
; BSD-2-Clause License
; ============================================================

section .text
global asm_syscall
global asm_jit_compile
global asm_inline_block

; -----------------------------------------------------------
; asm_syscall(int num, ...)
; C calling convention: RDI, RSI, RDX, RCX, R8, R9
; Linux syscall: RAX, RDI, RSI, RDX, R10, R8, R9
; -----------------------------------------------------------
asm_syscall:
    push rbp
    mov rbp, rsp
    
    ; Save registers
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; RDI already has syscall number
    mov rax, rdi
    
    ; Arguments already in correct registers for syscall
    ; RDI = arg1, RSI = arg2, RDX = arg3
    ; R10 = arg4, R8 = arg5, R9 = arg6
    
    ; But we need to move arg4 from RCX to R10
    mov r10, rcx
    
    syscall
    
    ; Restore registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    
    pop rbp
    ret

; -----------------------------------------------------------
; asm_jit_compile(void *code, size_t size)
; Make memory executable and jump to it
; -----------------------------------------------------------
asm_jit_compile:
    push rbp
    mov rbp, rsp
    
    ; code in RDI, size in RSI
    
    ; mprotect(RDI, RSI, PROT_READ | PROT_WRITE | PROT_EXEC)
    mov rax, 10         ; sys_mprotect
    ; RDI already has address
    ; RSI already has size
    mov rdx, 7          ; PROT_READ | PROT_WRITE | PROT_EXEC = 0x1|0x2|0x4
    syscall
    
    ; Jump to code
    mov rax, rdi
    call rax
    
    pop rbp
    ret

; -----------------------------------------------------------
; asm_inline_block(const char *asm_code)
; For now, just a placeholder - real implementation
; would parse and execute assembly strings
; -----------------------------------------------------------
asm_inline_block:
    push rbp
    mov rbp, rsp
    
    ; TODO: Parse assembly string and JIT compile
    ; For now, just return
    
    pop rbp
    ret

; -----------------------------------------------------------
; Disk I/O Syscalls (for J++ physics data logging)
; -----------------------------------------------------------

; sys_open(const char *pathname, int flags, mode_t mode)
global gjc_disk_open
gjc_disk_open:
    mov rax, 2          ; sys_open
    syscall
    ret

; sys_read(int fd, void *buf, size_t count)
global gjc_disk_read
gjc_disk_read:
    mov rax, 0          ; sys_read
    syscall
    ret

; sys_write(int fd, const void *buf, size_t count)
global gjc_disk_write
gjc_disk_write:
    mov rax, 1          ; sys_write
    syscall
    ret

; sys_close(int fd)
global gjc_disk_close
gjc_disk_close:
    mov rax, 3          ; sys_close
    syscall
    ret

; sys_lseek(int fd, off_t offset, int whence)
global gjc_disk_seek
gjc_disk_seek:
    mov rax, 8          ; sys_lseek
    mov r10, rdx        ; whence goes in r10 for syscall
    syscall
    ret

; -----------------------------------------------------------
; Network Syscalls (for J++ server capabilities)
; -----------------------------------------------------------

; sys_socket(int domain, int type, int protocol)
global gjc_net_socket
gjc_net_socket:
    mov rax, 41         ; sys_socket
    syscall
    ret

; sys_bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen)
global gjc_net_bind
gjc_net_bind:
    mov rax, 49         ; sys_bind
    syscall
    ret

; sys_listen(int sockfd, int backlog)
global gjc_net_listen
gjc_net_listen:
    mov rax, 50         ; sys_listen
    syscall
    ret

; sys_accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen)
global gjc_net_accept
gjc_net_accept:
    mov rax, 43         ; sys_accept
    mov r10, rdx
    syscall
    ret

; sys_sendto(int sockfd, const void *buf, size_t len, int flags, ...)
global gjc_net_send
gjc_net_send:
    mov rax, 44         ; sys_sendto
    mov r10, rcx        ; flags
    syscall
    ret

; sys_recvfrom(int sockfd, void *buf, size_t len, int flags, ...)
global gjc_net_recv
gjc_net_recv:
    mov rax, 45         ; sys_recvfrom
    mov r10, rcx        ; flags
    syscall
    ret