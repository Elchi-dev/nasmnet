bits 64
default rel

%include "sys.inc"

global sig_ignore
global sig_catch
global sig_block
global sig_unblock

section .text

sig_ignore:
    mov rsi, SIG_IGN

sig_catch:
    lea rdx, [action]
    mov [rdx], rsi
    mov qword [rdx + 8], SA_RESTORER
    lea rax, [sig_restorer]
    mov [rdx + 16], rax
    mov qword [rdx + 24], 0

    mov rsi, rdx
    xor rdx, rdx
    mov r10, 8
    mov rax, SYS_RT_SIGACTION
    syscall
    ret

sig_block:
    mov [maskbuf], rdi
    mov rdi, SIG_BLOCK
    jmp sig_mask

sig_unblock:
    mov [maskbuf], rdi
    mov rdi, SIG_UNBLOCK

sig_mask:
    lea rsi, [maskbuf]
    xor rdx, rdx
    mov r10, 8
    mov rax, SYS_RT_SIGPROCMASK
    syscall
    ret

; The kernel jumps here when a handler returns. On x86_64 there is no default
; restorer, so a program without libc has to supply this stub itself.
sig_restorer:
    mov rax, SYS_RT_SIGRETURN
    syscall

section .bss
action:  resb 32
maskbuf: resq 1
