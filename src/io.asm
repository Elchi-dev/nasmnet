bits 64
default rel

%include "sys.inc"

global write_all
global put_str
global put_u64
global put_err

extern str_len
extern u64_to_dec
extern err_name

section .text

write_all:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
.loop:
    test r13, r13
    jz .ok
    mov rax, SYS_WRITE
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    syscall
    test rax, rax
    jle .short
    add r12, rax
    sub r13, rax
    jmp .loop
.short:
    cmp rax, -EINTR
    je .loop
    test rax, rax
    jnz .out
    mov rax, -5
    jmp .out
.ok:
    xor rax, rax
.out:
    pop r13
    pop r12
    pop rbx
    ret

put_str:
    push rbx
    mov rbx, rdi
    mov rdi, rsi
    push rsi
    call str_len
    pop rsi
    mov rdx, rax
    mov rdi, rbx
    call write_all
    pop rbx
    ret

put_u64:
    push rbx
    mov rbx, rdi
    mov rdi, rsi
    lea rsi, [numbuf]
    call u64_to_dec
    mov rdx, rax
    mov rdi, rbx
    lea rsi, [numbuf]
    call write_all
    pop rbx
    ret

put_err:
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    lea rsi, [s_errno]
    call put_str
    mov rdi, rbx
    mov rsi, r12
    call put_u64
    mov rdi, rbx
    lea rsi, [s_open]
    call put_str
    mov rdi, r12
    call err_name
    mov rsi, rax
    mov rdi, rbx
    call put_str
    mov rdi, rbx
    lea rsi, [s_close]
    call put_str
    pop r12
    pop rbx
    ret

section .rodata
s_errno: db "errno ", 0
s_open:  db " (", 0
s_close: db ")", 0

section .bss
numbuf: resb 32
