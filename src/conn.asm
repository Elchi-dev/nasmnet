bits 64
default rel

%include "sys.inc"

global conn_init
global conn_alloc
global conn_free
global conn_ptr
global conn_live

section .text

conn_init:
    xor rcx, rcx
.fill:
    mov [freelist + rcx * 4], ecx
    inc rcx
    cmp rcx, MAX_CONNS
    jb .fill
    mov qword [freetop], MAX_CONNS
    mov qword [livecount], 0
    ret

conn_alloc:
    mov rax, [freetop]
    test rax, rax
    jz .none
    dec rax
    mov [freetop], rax
    mov eax, [freelist + rax * 4]
    inc qword [livecount]
    ret
.none:
    mov rax, -1
    ret

conn_free:
    cmp rdi, MAX_CONNS
    jae .out
    mov rax, [freetop]
    cmp rax, MAX_CONNS
    jae .out
    mov [freelist + rax * 4], edi
    inc rax
    mov [freetop], rax
    dec qword [livecount]
.out:
    ret

conn_ptr:
    cmp rdi, MAX_CONNS
    jae .bad
    mov rax, conn_size
    imul rax, rdi
    lea rdx, [pool]
    add rax, rdx
    ret
.bad:
    xor rax, rax
    ret

conn_live:
    mov rax, [livecount]
    ret

section .bss
align 8
pool:      resb conn_size * MAX_CONNS
freelist:  resd MAX_CONNS
freetop:   resq 1
livecount: resq 1
