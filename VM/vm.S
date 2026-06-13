.section .text
    .globl _start
    .globl vm_init
    .globl vm_execute
    .globl vm_push
    .globl vm_pop
    .globl vm_dump_state
    .globl vm_printel
    .globl vm_scanel

    .equ VM_STACK_SIZE,     1048576     # 1MB stack
    .equ VM_HEAP_SIZE,     16777216    # 16MB heap
    .equ VM_NUM_REGS,      16          # R0-R15
    .equ VM_MAX_FRAMES,     1024        # Max call depth
    .equ VM_PAGE_SIZE,      4096        # Page alignment

    .equ OP_NOP,            0
    .equ OP_PUSH,           1
    .equ OP_POP,            2
    .equ OP_DUP,            3
    .equ OP_SWAP,           4
    .equ OP_LOAD,           5
    .equ OP_STORE,          6
    .equ OP_LOADI,          7
    .equ OP_LOADF,          8
    .equ OP_LOADS,          9
    .equ OP_LOADB,          10
    .equ OP_LOADC,          11
    .equ OP_ADD,            12
    .equ OP_SUB,            13
    .equ OP_MUL,            14
    .equ OP_DIV,            15
    .equ OP_MOD,            16
    .equ OP_NEG,            17
    .equ OP_INC,            18
    .equ OP_DEC,            19
    .equ OP_AND,            20
    .equ OP_OR,             21
    .equ OP_XOR,            22
    .equ OP_NOT,            23
    .equ OP_SHL,            24
    .equ OP_SHR,            25
    .equ OP_EQ,             26
    .equ OP_NE,             27
    .equ OP_LT,             28
    .equ OP_GT,             29
    .equ OP_LE,             30
    .equ OP_GE,             31
    .equ OP_LAND,           32
    .equ OP_LOR,            33
    .equ OP_LNOT,           34
    .equ OP_JMP,            35
    .equ OP_JZ,             36
    .equ OP_JNZ,            37
    .equ OP_CALL,           38
    .equ OP_RET,            39
    .equ OP_SYSCALL,        40
    .equ OP_LOAD_MEM,       41
    .equ OP_STORE_MEM,      42
    .equ OP_ALLOC,          43
    .equ OP_FREE,           44
    .equ OP_GET_FIELD,      45
    .equ OP_SET_FIELD,      46
    .equ OP_GET_INDEX,      47
    .equ OP_SET_INDEX,      48
    .equ OP_I2F,            49
    .equ OP_F2I,            50
    .equ OP_I2S,            51
    .equ OP_S2I,            52
    .equ OP_PRINT,          53
    .equ OP_SCAN,            54
    .equ OP_TIMER,           55
    .equ OP_RAND,            56
    .equ OP_TIME,            57
    .equ OP_EXIT,            58

# ============================================================================
# VM VALUE TYPE TAGS
# ============================================================================
    .equ VM_VOID,           0
    .equ VM_INT,            1
    .equ VM_FLOAT,          2
    .equ VM_STRING,         3
    .equ VM_BOOL,            4
    .equ VM_CHAR,            5
    .equ VM_PTR,            6
    .equ VM_ARRAY,           7
    .equ VM_STRUCT,         8

# ============================================================================
# VM STATE STRUCTURE
# ============================================================================
# VM state is stored in memory with this layout:
#   0x0000: RIP (instruction pointer) - 8 bytes
#   0x0008: RSP (stack pointer) - 8 bytes
#   0x0010: RBP (base pointer) - 8 bytes
#   0x0018: Running flag - 8 bytes
#   0x0020: Exit code - 8 bytes
#   0x0028: Frame pointer - 8 bytes
#   0x0030: Code pointer - 8 bytes
#   0x0038: Code size - 8 bytes
#   0x0040: Registers R0-R15 - 16 * 16 bytes = 256 bytes
#   0x0140: Stack - 1MB
#   0x100140: Heap - 16MB
#   0x1100140: Call frames - 1024 * 32 bytes = 32KB
#   0x1108140: Output buffer - 4KB
#   0x1109140: Input buffer - 4KB
#   0x110A140: Total ~17.7MB

    .equ VM_STATE_SIZE,    0x110A140

    .equ OFF_RIP,           0x00
    .equ OFF_RSP,           0x08
    .equ OFF_RBP,           0x10
    .equ OFF_RUNNING,       0x18
    .equ OFF_EXIT_CODE,     0x20
    .equ OFF_FRAME_PTR,     0x28
    .equ OFF_CODE_PTR,      0x30
    .equ OFF_CODE_SIZE,     0x38
    .equ OFF_REGS,          0x40
    .equ OFF_STACK,         0x0140
    .equ OFF_HEAP,          0x100140
    .equ OFF_FRAMES,        0x1100140
    .equ OFF_OUTPUT,        0x1108140
    .equ OFF_INPUT,         0x1109140


    .equ VM_VALUE_SIZE,    16

    .section .data
    .align 8

vm_state:
    .space VM_STATE_SIZE, 0

# Test bytecode - simple program: push 10, push 20, add, print, exit
test_bytecode:
    .quad OP_LOADI, 10, 0, 0          # push 10
    .quad OP_LOADI, 20, 0, 0          # push 20
    .quad OP_ADD, 0, 0, 0              # add
    .quad OP_PRINT, 0, 0, 0            # print result
    .quad OP_EXIT, 0, 0, 0             # exit

test_bytecode_end:

# String constants
msg_vm_init:
    .ascii "J++ VM Initialized\n"
    .equ msg_vm_init_len, . - msg_vm_init

msg_vm_running:
    .ascii "VM Running...\n"
    .equ msg_vm_running_len, . - msg_vm_running

msg_vm_halted:
    .ascii "VM Halted\n"
    .equ msg_vm_halted_len, . - msg_vm_halted

msg_stack_overflow:
    .ascii "ERROR: Stack overflow\n"
    .equ msg_stack_overflow_len, . - msg_stack_overflow

msg_stack_underflow:
    .ascii "ERROR: Stack underflow\n"
    .equ msg_stack_underflow_len, . - msg_stack_underflow

msg_div_zero:
    .ascii "ERROR: Division by zero\n"
    .equ msg_div_zero_len, . - msg_div_zero

msg_unknown_op:
    .ascii "ERROR: Unknown opcode\n"
    .equ msg_unknown_op_len, . - msg_unknown_op

# Number to string conversion buffer
num_buffer:
    .space 32, 0


# Push value to VM stack
.macro VM_PUSH reg
    movq %\reg, %rax
    movq vm_state + OFF_RSP, %rbx
    cmpq $VM_STACK_SIZE, %rbx
    jge stack_overflow
    movq %rax, vm_state + OFF_STACK(,%rbx,8)
    incq vm_state + OFF_RSP
.endm

# Pop value from VM stack
.macro VM_POP reg
    movq vm_state + OFF_RSP, %rbx
    testq %rbx, %rbx
    jz stack_underflow
    decq vm_state + OFF_RSP
    movq vm_state + OFF_STACK(,%rbx,8), %\reg
.endm

# Get VM state field
.macro VM_GET field, reg
    movq vm_state + \field, %\reg
.endm

# Set VM state field
.macro VM_SET field, reg
    movq %\reg, vm_state + \field
.endm

_start:
    # Setup stack
    movq $stack_top, %rsp
    
    # Initialize VM
    call vm_init
    
    # Load test bytecode
    leaq test_bytecode, %rdi
    movq $(test_bytecode_end - test_bytecode), %rsi
    call vm_load_code
    
    # Execute
    call vm_execute
    
    # Print exit code
    movq %rax, %rdi
    call print_int
    
    # Halt
    movq $60, %rax          # sys_exit
    xorq %rdi, %rdi         # exit code 0
    syscall

# ============================================================================
# VM_INIT - Initialize VM state
# ============================================================================
vm_init:
    pushq %rbp
    movq %rsp, %rbp
    
    # Clear VM state
    leaq vm_state, %rdi
    movq $0, %rax
    movq $(VM_STATE_SIZE / 8), %rcx
    cld
    rep stosq
    
    # Print init message
    leaq msg_vm_init, %rsi
    movq $msg_vm_init_len, %rdx
    call print_string
    
    popq %rbp
    ret

# ============================================================================
# VM_LOAD_CODE - Load bytecode into VM
# ============================================================================
# Arguments:
#   %rdi = pointer to bytecode
#   %rsi = size of bytecode (in instructions * 32 bytes)
vm_load_code:
    pushq %rbp
    movq %rsp, %rbp
    
    # Store code pointer and size
    VM_SET OFF_CODE_PTR, rdi
    VM_SET OFF_CODE_SIZE, rsi
    
    # Reset execution state
    movq $0, %rax
    VM_SET OFF_RIP, rax
    VM_SET OFF_RSP, rax
    VM_SET OFF_RBP, rax
    VM_SET OFF_FRAME_PTR, rax
    movq $1, %rax
    VM_SET OFF_RUNNING, rax
    movq $0, %rax
    VM_SET OFF_EXIT_CODE, rax
    
    popq %rbp
    ret

# ============================================================================
# VM_EXECUTE - Main execution loop
# ============================================================================
vm_execute:
    pushq %rbp
    movq %rsp, %rbp
    
    # Print running message
    leaq msg_vm_running, %rsi
    movq $msg_vm_running_len, %rdx
    call print_string

execute_loop:
    # Check if running
    VM_GET OFF_RUNNING, rax
    testq %rax, %rax
    jz execute_done
    
    # Check RIP bounds
    VM_GET OFF_RIP, rax
    VM_GET OFF_CODE_SIZE, rbx
    cmpq %rbx, %rax
    jge execute_done
    
    # Fetch instruction
    # Each instruction is 32 bytes: opcode(8) + arg1(8) + arg2(8) + arg3(8)
    VM_GET OFF_CODE_PTR, rcx
    movq %rax, %rdx
    shlq $5, %rdx           # Multiply by 32 (instruction size)
    addq %rdx, %rcx
    
    # Load instruction fields
    movq 0(%rcx), %r8       # opcode
    movq 8(%rcx), %r9       # arg1
    movq 16(%rcx), %r10     # arg2
    movq 24(%rcx), %r11     # arg3
    
    # Increment RIP
    incq %rax
    VM_SET OFF_RIP, rax
    
    # Dispatch based on opcode
    cmpq $OP_EXIT, %r8
    je op_exit_handler
    cmpq $OP_NOP, %r8
    je execute_loop
    cmpq $OP_PUSH, %r8
    je op_push_handler
    cmpq $OP_POP, %r8
    je op_pop_handler
    cmpq $OP_DUP, %r8
    je op_dup_handler
    cmpq $OP_SWAP, %r8
    je op_swap_handler
    cmpq $OP_LOAD, %r8
    je op_load_handler
    cmpq $OP_STORE, %r8
    je op_store_handler
    cmpq $OP_LOADI, %r8
    je op_loadi_handler
    cmpq $OP_LOADF, %r8
    je op_loadf_handler
    cmpq $OP_LOADS, %r8
    je op_loads_handler
    cmpq $OP_LOADB, %r8
    je op_loadb_handler
    cmpq $OP_LOADC, %r8
    je op_loadc_handler
    cmpq $OP_ADD, %r8
    je op_add_handler
    cmpq $OP_SUB, %r8
    je op_sub_handler
    cmpq $OP_MUL, %r8
    je op_mul_handler
    cmpq $OP_DIV, %r8
    je op_div_handler
    cmpq $OP_MOD, %r8
    je op_mod_handler
    cmpq $OP_NEG, %r8
    je op_neg_handler
    cmpq $OP_INC, %r8
    je op_inc_handler
    cmpq $OP_DEC, %r8
    je op_dec_handler
    cmpq $OP_AND, %r8
    je op_and_handler
    cmpq $OP_OR, %r8
    je op_or_handler
    cmpq $OP_XOR, %r8
    je op_xor_handler
    cmpq $OP_NOT, %r8
    je op_not_handler
    cmpq $OP_SHL, %r8
    je op_shl_handler
    cmpq $OP_SHR, %r8
    je op_shr_handler
    cmpq $OP_EQ, %r8
    je op_eq_handler
    cmpq $OP_NE, %r8
    je op_ne_handler
    cmpq $OP_LT, %r8
    je op_lt_handler
    cmpq $OP_GT, %r8
    je op_gt_handler
    cmpq $OP_LE, %r8
    je op_le_handler
    cmpq $OP_GE, %r8
    je op_ge_handler
    cmpq $OP_LAND, %r8
    je op_land_handler
    cmpq $OP_LOR, %r8
    je op_lor_handler
    cmpq $OP_LNOT, %r8
    je op_lnot_handler
    cmpq $OP_JMP, %r8
    je op_jmp_handler
    cmpq $OP_JZ, %r8
    je op_jz_handler
    cmpq $OP_JNZ, %r8
    je op_jnz_handler
    cmpq $OP_CALL, %r8
    je op_call_handler
    cmpq $OP_RET, %r8
    je op_ret_handler
    cmpq $OP_SYSCALL, %r8
    je op_syscall_handler
    cmpq $OP_PRINT, %r8
    je op_print_handler
    cmpq $OP_LOAD_MEM, %r8
    je op_load_mem_handler
    cmpq $OP_STORE_MEM, %r8
    je op_store_mem_handler
    
    # Unknown opcode
    leaq msg_unknown_op, %rsi
    movq $msg_unknown_op_len, %rdx
    call print_string
    movq %r8, %rdi
    call print_int
    call print_newline
    jmp execute_done

execute_done:
    # Print halted message
    leaq msg_vm_halted, %rsi
    movq $msg_vm_halted_len, %rdx
    call print_string
    
    # Return exit code
    VM_GET OFF_EXIT_CODE, rax
    
    popq %rbp
    ret

; opcode handlers

# OP_EXIT - Stop VM
op_exit_handler:
    movq %r9, %rax          # arg1 = exit code
    VM_SET OFF_EXIT_CODE, rax
    movq $0, %rax
    VM_SET OFF_RUNNING, rax
    jmp execute_loop

# OP_PUSH - Push value to stack
op_push_handler:
    movq %r9, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_POP - Pop value from stack
op_pop_handler:
    VM_POP rax
    jmp execute_loop

# OP_DUP - Duplicate top of stack
op_dup_handler:
    VM_GET OFF_RSP, rax
    testq %rax, %rax
    jz stack_underflow
    movq vm_state + OFF_STACK - 8(,%rax,8), %rbx
    VM_PUSH rbx
    jmp execute_loop

# OP_SWAP - Swap top two stack values
op_swap_handler:
    VM_GET OFF_RSP, rax
    cmpq $2, %rax
    jl stack_underflow
    movq vm_state + OFF_STACK - 8(,%rax,8), %rbx
    movq vm_state + OFF_STACK - 16(,%rax,8), %rcx
    movq %rbx, vm_state + OFF_STACK - 16(,%rax,8)
    movq %rcx, vm_state + OFF_STACK - 8(,%rax,8)
    jmp execute_loop

# OP_LOAD - Load from register
op_load_handler:
    # r9 = register index
    movq %r9, %rbx
    shlq $4, %rbx           # Multiply by 16 (VM_VALUE_SIZE)
    leaq vm_state + OFF_REGS(%rbx), %rcx
    movq 0(%rcx), %rdx      # Type
    movq 8(%rcx), %rsi      # Value
    # Push to stack
    VM_GET OFF_RSP, rax
    cmpq $VM_STACK_SIZE, %rax
    jge stack_overflow
    movq %rdx, vm_state + OFF_STACK(,%rax,8)
    movq %rsi, vm_state + OFF_STACK + 8(,%rax,8)
    addq $2, vm_state + OFF_RSP
    jmp execute_loop

# OP_STORE - Store to register
op_store_handler:
    # r9 = register index
    VM_POP rax              # Pop value (type + value)
    VM_POP rbx
    movq %r9, %rcx
    shlq $4, %rcx
    leaq vm_state + OFF_REGS(%rcx), %rdx
    movq %rbx, 0(%rdx)      # Type
    movq %rax, 8(%rdx)      # Value
    jmp execute_loop

# OP_LOADI - Load integer immediate
op_loadi_handler:
    movq %r9, %rax          # arg1 = immediate value
    VM_PUSH rax
    jmp execute_loop

# OP_LOADF - Load float immediate
op_loadf_handler:
    movq %r9, %rax          # arg1 = float bits
    VM_PUSH rax
    jmp execute_loop

# OP_LOADS - Load string from heap
op_loads_handler:
    # r9 = heap address, r10 = length
    movq %r9, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_LOADB - Load boolean
op_loadb_handler:
    movq %r9, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_LOADC - Load character
op_loadc_handler:
    movq %r9, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_ADD - Add two values
op_add_handler:
    VM_POP rbx              # b
    VM_POP rax              # a
    addq %rbx, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_SUB - Subtract
op_sub_handler:
    VM_POP rbx
    VM_POP rax
    subq %rbx, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_MUL - Multiply
op_mul_handler:
    VM_POP rbx
    VM_POP rax
    imulq %rbx, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_DIV - Divide
op_div_handler:
    VM_POP rbx
    testq %rbx, %rbx
    jz div_zero
    VM_POP rax
    cqo                     # Sign extend RAX into RDX:RAX
    idivq %rbx
    VM_PUSH rax
    jmp execute_loop

# OP_MOD - Modulo
op_mod_handler:
    VM_POP rbx
    testq %rbx, %rbx
    jz div_zero
    VM_POP rax
    cqo
    idivq %rbx
    VM_PUSH rdx             # Remainder
    jmp execute_loop

# OP_NEG - Negate
op_neg_handler:
    VM_POP rax
    negq %rax
    VM_PUSH rax
    jmp execute_loop

# OP_INC - Increment
op_inc_handler:
    VM_POP rax
    incq %rax
    VM_PUSH rax
    jmp execute_loop

# OP_DEC - Decrement
op_dec_handler:
    VM_POP rax
    decq %rax
    VM_PUSH rax
    jmp execute_loop

# OP_AND - Bitwise AND
op_and_handler:
    VM_POP rbx
    VM_POP rax
    andq %rbx, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_OR - Bitwise OR
op_or_handler:
    VM_POP rbx
    VM_POP rax
    orq %rbx, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_XOR - Bitwise XOR
op_xor_handler:
    VM_POP rbx
    VM_POP rax
    xorq %rbx, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_NOT - Bitwise NOT
op_not_handler:
    VM_POP rax
    notq %rax
    VM_PUSH rax
    jmp execute_loop

# OP_SHL - Shift left
op_shl_handler:
    VM_POP rcx              # shift amount
    VM_POP rax
    shlq %cl, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_SHR - Shift right
op_shr_handler:
    VM_POP rcx
    VM_POP rax
    sarq %cl, %rax          # Arithmetic shift right
    VM_PUSH rax
    jmp execute_loop

# OP_EQ - Equal
op_eq_handler:
    VM_POP rbx
    VM_POP rax
    cmpq %rbx, %rax
    sete %al
    movzbq %al, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_NE - Not equal
op_ne_handler:
    VM_POP rbx
    VM_POP rax
    cmpq %rbx, %rax
    setne %al
    movzbq %al, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_LT - Less than
op_lt_handler:
    VM_POP rbx
    VM_POP rax
    cmpq %rbx, %rax
    setl %al
    movzbq %al, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_GT - Greater than
op_gt_handler:
    VM_POP rbx
    VM_POP rax
    cmpq %rbx, %rax
    setg %al
    movzbq %al, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_LE - Less than or equal
op_le_handler:
    VM_POP rbx
    VM_POP rax
    cmpq %rbx, %rax
    setle %al
    movzbq %al, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_GE - Greater than or equal
op_ge_handler:
    VM_POP rbx
    VM_POP rax
    cmpq %rbx, %rax
    setge %al
    movzbq %al, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_LAND - Logical AND
op_land_handler:
    VM_POP rbx
    VM_POP rax
    testq %rax, %rax
    jz .Lland_false
    testq %rbx, %rbx
    jz .Lland_false
    movq $1, %rax
    jmp .Lland_done
.Lland_false:
    movq $0, %rax
.Lland_done:
    VM_PUSH rax
    jmp execute_loop

# OP_LOR - Logical OR
op_lor_handler:
    VM_POP rbx
    VM_POP rax
    testq %rax, %rax
    jnz .Llor_true
    testq %rbx, %rbx
    jnz .Llor_true
    movq $0, %rax
    jmp .Llor_done
.Llor_true:
    movq $1, %rax
.Llor_done:
    VM_PUSH rax
    jmp execute_loop

# OP_LNOT - Logical NOT
op_lnot_handler:
    VM_POP rax
    testq %rax, %rax
    setz %al
    movzbq %al, %rax
    VM_PUSH rax
    jmp execute_loop

# OP_JMP - Unconditional jump
op_jmp_handler:
    movq %r9, %rax          # arg1 = target address
    VM_SET OFF_RIP, rax
    jmp execute_loop

# OP_JZ - Jump if zero
op_jz_handler:
    VM_POP rax
    testq %rax, %rax
    jnz .Ljz_skip
    movq %r9, %rax
    VM_SET OFF_RIP, rax
.Ljz_skip:
    jmp execute_loop

# OP_JNZ - Jump if not zero
op_jnz_handler:
    VM_POP rax
    testq %rax, %rax
    jz .Ljnz_skip
    movq %r9, %rax
    VM_SET OFF_RIP, rax
.Ljnz_skip:
    jmp execute_loop

# OP_CALL - Call function
op_call_handler:
    # Save frame
    VM_GET OFF_FRAME_PTR, rax
    cmpq $VM_MAX_FRAMES, %rax
    jge stack_overflow
    
    # Store return address (current RIP)
    VM_GET OFF_RIP, rbx
    movq %rbx, vm_state + OFF_FRAMES(,%rax,8)
    
    # Store base pointer
    VM_GET OFF_RBP, rbx
    movq %rbx, vm_state + OFF_FRAMES + 8(,%rax,8)
    
    incq %rax
    VM_SET OFF_FRAME_PTR, rax
    
    # Set new base pointer
    VM_GET OFF_RSP, %rbx
    VM_SET OFF_RBP, rbx
    
    # Jump to function
    movq %r9, %rax
    VM_SET OFF_RIP, rax
    jmp execute_loop

# OP_RET - Return from function
op_ret_handler:
    VM_GET OFF_FRAME_PTR, rax
    testq %rax, %rax
    jz execute_done
    
    decq %rax
    VM_SET OFF_FRAME_PTR, rax
    
    # Restore RIP
    movq vm_state + OFF_FRAMES(,%rax,8), %rbx
    VM_SET OFF_RIP, rbx
    
    # Restore RBP
    movq vm_state + OFF_FRAMES + 8(,%rax,8), %rbx
    VM_SET OFF_RBP, rbx
    
    jmp execute_loop

# OP_SYSCALL - System call / built-in
op_syscall_handler:
    # r9 = function name ptr, r10 = name length, r11 = num args
    # For now, just handle printel
    movq %r9, %rdi
    movq %r10, %rsi
    call vm_printel
    jmp execute_loop

# OP_PRINT - Print top of stack
op_print_handler:
    VM_POP rax
    movq %rax, %rdi
    call print_int
    call print_newline
    jmp execute_loop

# OP_LOAD_MEM - Load from memory
op_load_mem_handler:
    VM_POP rax              # address
    movzbq vm_state + OFF_HEAP(,%rax,1), %rbx
    VM_PUSH rbx
    jmp execute_loop

# OP_STORE_MEM - Store to memory
op_store_mem_handler:
    VM_POP rax              # address
    VM_POP rbx              # value
    movb %bl, vm_state + OFF_HEAP(,%rax,1)
    jmp execute_loop

; it handles errors.

stack_overflow:
    leaq msg_stack_overflow, %rsi
    movq $msg_stack_overflow_len, %rdx
    call print_string
    movq $1, %rax
    VM_SET OFF_EXIT_CODE, rax
    movq $0, %rax
    VM_SET OFF_RUNNING, rax
    jmp execute_done

stack_underflow:
    leaq msg_stack_underflow, %rsi
    movq $msg_stack_underflow_len, %rdx
    call print_string
    movq $1, %rax
    VM_SET OFF_EXIT_CODE, rax
    movq $0, %rax
    VM_SET OFF_RUNNING, rax
    jmp execute_done

div_zero:
    leaq msg_div_zero, %rsi
    movq $msg_div_zero_len, %rdx
    call print_string
    movq $1, %rax
    VM_SET OFF_EXIT_CODE, rax
    movq $0, %rax
    VM_SET OFF_RUNNING, rax
    jmp execute_done

vm_printel:
    pushq %rbp
    movq %rsp, %rbp
    
    # For now, just print the format string directly
    call print_string
    
    popq %rbp
    ret

# VM_SCANEL - Formatted input (simplified)
vm_scanel:
    pushq %rbp
    movq %rsp, %rbp
    
    # Read from stdin
    movq $0, %rax           # sys_read
    movq $0, %rdi           # stdin
    leaq vm_state + OFF_INPUT, %rsi
    movq $4096, %rdx        # buffer size
    syscall
    
    popq %rbp
    ret

# ============================================================================
# VM_DUMP_STATE - Print VM state for debugging
# ============================================================================
vm_dump_state:
    pushq %rbp
    movq %rsp, %rbp
    
    # Print RIP
    leaq msg_rip, %rsi
    movq $msg_rip_len, %rdx
    call print_string
    VM_GET OFF_RIP, rdi
    call print_int
    call print_newline
    
    # Print RSP
    leaq msg_rsp, %rsi
    movq $msg_rsp_len, %rdx
    call print_string
    VM_GET OFF_RSP, rdi
    call print_int
    call print_newline
    
    # Print top of stack
    leaq msg_stack_top, %rsi
    movq $msg_stack_top_len, %rdx
    call print_string
    VM_GET OFF_RSP, rax
    testq %rax, %rax
    jz .Ldump_empty
    movq vm_state + OFF_STACK - 8(,%rax,8), %rdi
    call print_int
    call print_newline
    jmp .Ldump_done
.Ldump_empty:
    leaq msg_empty, %rsi
    movq $msg_empty_len, %rdx
    call print_string
.Ldump_done:
    
    popq %rbp
    ret

print_string:
    pushq %rax
    pushq %rdi
    movq $1, %rax           # sys_write
    movq $1, %rdi          
    syscall
    popq %rdi
    popq %rax
    ret

# PRINT_INT - Print integer to stdout
# Arguments:
#   %rdi = integer to print
print_int:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rax
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rsi
    pushq %rdi
    
    movq %rdi, %rax
    movq $num_buffer, %rsi
    addq $31, %rsi          # End of buffer
    movb $0, (%rsi)
    
    # Handle negative
    movq $0, %rbx
    testq %rax, %rax
    jns .Lpi_positive
    negq %rax
    movq $1, %rbx
.Lpi_positive:
    
    movq $10, %rcx
.Lpi_loop:
    xorq %rdx, %rdx
    divq %rcx
    decq %rsi
    addq $'0', %rdx
    movb %dl, (%rsi)
    testq %rax, %rax
    jnz .Lpi_loop
    
    # Add minus sign if negative
    testq %rbx, %rbx
    jz .Lpi_print
    decq %rsi
    movb $'-', (%rsi)
.Lpi_print:
    # Calculate length
    leaq num_buffer, %rdx
    addq $31, %rdx
    subq %rsi, %rdx
    
    # Print
    movq %rsi, %rsi
    call print_string
    
    popq %rdi
    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    popq %rax
    popq %rbp
    ret

# PRINT_NEWLINE - Print newline
print_newline:
    pushq %rsi
    pushq %rdx
    leaq newline_char, %rsi
    movq $1, %rdx
    call print_string
    popq %rdx
    popq %rsi
    ret

# ============================================================================
# DATA SECTION - String constants for debugging
# ============================================================================
    .section .data

msg_rip:
    .ascii "RIP: "
    .equ msg_rip_len, . - msg_rip

msg_rsp:
    .ascii "RSP: "
    .equ msg_rsp_len, . - msg_rsp

msg_stack_top:
    .ascii "Stack top: "
    .equ msg_stack_top_len, . - msg_stack_top

msg_empty:
    .ascii "(empty)\n"
    .equ msg_empty_len, . - msg_empty

newline_char:
    .ascii "\n"

; bss section 

    .section .bss
    .align 16

stack_bottom:
    .space 16384            # 16KB stack
stack_top:
