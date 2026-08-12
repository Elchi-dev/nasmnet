bits 64
default rel

%include "sys.inc"

global ep_create
global ep_add
global ep_mod
global ep_del

section .text

ep_create:
    mov rax, SYS_EPOLL_CREATE1
    xor rdi, rdi
    syscall
    ret

; rdi epfd, rsi fd, rdx events, rcx tag
ep_add:
    mov r8, EPOLL_CTL_ADD
    jmp ep_ctl

; rdi epfd, rsi fd, rdx events, rcx tag
ep_mod:
    mov r8, EPOLL_CTL_MOD

ep_ctl:
    lea r9, [evbuf]
    mov [r9], edx
    mov [r9 + 4], rcx
    mov rdx, rsi
    mov rsi, r8
    mov r10, r9
    mov rax, SYS_EPOLL_CTL
    syscall
    ret

; rdi epfd, rsi fd
ep_del:
    mov rdx, rsi
    mov rsi, EPOLL_CTL_DEL
    lea r10, [evbuf]
    mov rax, SYS_EPOLL_CTL
    syscall
    ret

section .bss
align 8
evbuf: resb EV_SIZE
