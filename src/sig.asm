bits 64
default rel

%include "sys.inc"

global sig_ignore
global sig_catch

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

; The kernel jumps here when a handler returns. On x86_64 there is no default
; restorer, so a program without libc has to supply this stub itself.
sig_restorer:
    mov rax, SYS_RT_SIGRETURN
    syscall

section .bss
action: resb 32
