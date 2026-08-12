bits 64
default rel

global err_name

section .text

err_name:
    lea rsi, [errno_table]
.next:
    mov eax, [rsi]
    test eax, eax
    jz .unknown
    cmp eax, edi
    je .hit
    add rsi, 16
    jmp .next
.hit:
    mov rax, [rsi + 8]
    ret
.unknown:
    lea rax, [s_unknown]
    ret

section .rodata

s_eperm:        db "EPERM", 0
s_eintr:        db "EINTR", 0
s_eio:          db "EIO", 0
s_ebadf:        db "EBADF", 0
s_eagain:       db "EAGAIN", 0
s_enomem:       db "ENOMEM", 0
s_eacces:       db "EACCES", 0
s_efault:       db "EFAULT", 0
s_einval:       db "EINVAL", 0
s_enfile:       db "ENFILE", 0
s_emfile:       db "EMFILE", 0
s_epipe:        db "EPIPE", 0
s_enotsock:     db "ENOTSOCK", 0
s_eaddrinuse:   db "EADDRINUSE", 0
s_eaddrnotavail: db "EADDRNOTAVAIL", 0
s_enetdown:     db "ENETDOWN", 0
s_econnaborted: db "ECONNABORTED", 0
s_econnreset:   db "ECONNRESET", 0
s_etimedout:    db "ETIMEDOUT", 0
s_econnrefused: db "ECONNREFUSED", 0
s_unknown:      db "UNKNOWN", 0

align 8
errno_table:
    dd 1,   0
    dq s_eperm
    dd 4,   0
    dq s_eintr
    dd 5,   0
    dq s_eio
    dd 9,   0
    dq s_ebadf
    dd 11,  0
    dq s_eagain
    dd 12,  0
    dq s_enomem
    dd 13,  0
    dq s_eacces
    dd 14,  0
    dq s_efault
    dd 22,  0
    dq s_einval
    dd 23,  0
    dq s_enfile
    dd 24,  0
    dq s_emfile
    dd 32,  0
    dq s_epipe
    dd 88,  0
    dq s_enotsock
    dd 98,  0
    dq s_eaddrinuse
    dd 99,  0
    dq s_eaddrnotavail
    dd 100, 0
    dq s_enetdown
    dd 103, 0
    dq s_econnaborted
    dd 104, 0
    dq s_econnreset
    dd 110, 0
    dq s_etimedout
    dd 111, 0
    dq s_econnrefused
    dd 0,   0
    dq 0
