bits 64
default rel

%include "sys.inc"

global _start

extern put_str
extern put_u64
extern put_err
extern write_all
extern parse_u16
extern str_eq
extern sig_ignore
extern sig_catch

section .text

_start:
    mov r14, [rsp]
    lea r15, [rsp + 8]

    mov rax, 8080
    cmp r14, 1
    jle .have_port

    mov rdi, [r15 + 8]
    call check_flags

    mov rdi, [r15 + 8]
    call parse_u16
    cmp rax, -1
    je .bad_port
    test rax, rax
    jz .bad_port

.have_port:
    mov r13, rax

    mov rdi, SIGPIPE
    call sig_ignore

    mov rdi, SIGINT
    lea rsi, [on_shutdown]
    call sig_catch

    mov rdi, SIGTERM
    lea rsi, [on_shutdown]
    call sig_catch

    mov rax, SYS_SOCKET
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    test rax, rax
    js .socket_failed
    mov r12, rax

    mov rax, SYS_SETSOCKOPT
    mov rdi, r12
    mov rsi, SOL_SOCKET
    mov rdx, SO_REUSEADDR
    lea r10, [one]
    mov r8, 4
    syscall
    test rax, rax
    js .setsockopt_failed

    lea rdi, [addr]
    mov word [rdi + sockaddr_in.sin_family], AF_INET
    mov eax, r13d
    xchg al, ah
    mov [rdi + sockaddr_in.sin_port], ax
    mov dword [rdi + sockaddr_in.sin_addr], 0

    mov rax, SYS_BIND
    mov rdi, r12
    lea rsi, [addr]
    mov rdx, 16
    syscall
    test rax, rax
    js .bind_failed

    mov rax, SYS_LISTEN
    mov rdi, r12
    mov rsi, BACKLOG
    syscall
    test rax, rax
    js .listen_failed

    mov rdi, STDOUT
    lea rsi, [s_listening]
    call put_str
    mov rdi, STDOUT
    mov rsi, r13
    call put_u64
    mov rdi, STDOUT
    lea rsi, [s_nl]
    call put_str

.accept_loop:
    cmp byte [stopping], 0
    jne .shutdown

    mov rax, SYS_ACCEPT
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    syscall
    test rax, rax
    jns .accepted
    cmp rax, -EINTR
    je .accept_loop
    cmp rax, -ECONNABORTED
    je .accept_loop
    lea rsi, [s_accept]
    jmp fail_syscall

.shutdown:
    mov rdi, STDOUT
    lea rsi, [s_stopping]
    call put_str
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    xor rdi, rdi
    jmp exit_now
.accepted:
    mov rbx, rax

    mov rdi, rbx
    call echo_connection

    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    jmp .accept_loop

.bad_port:
    mov rdi, STDERR
    lea rsi, [s_bad_port]
    call put_str
    mov rdi, 1
    jmp exit_now

.socket_failed:
    lea rsi, [s_socket]
    jmp fail_syscall

.setsockopt_failed:
    lea rsi, [s_setsockopt]
    jmp fail_syscall

.bind_failed:
    lea rsi, [s_bind]
    jmp fail_syscall

.listen_failed:
    lea rsi, [s_listen]
    jmp fail_syscall

fail_syscall:
    push rax
    mov rdi, STDERR
    call put_str
    pop rsi
    neg rsi
    mov rdi, STDERR
    call put_err
    mov rdi, STDERR
    lea rsi, [s_nl]
    call put_str
    mov rdi, 2
    jmp exit_now

on_shutdown:
    mov byte [stopping], 1
    ret

echo_connection:
    push rbx
    mov rbx, rdi
.read:
    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [buf]
    mov rdx, BUFSIZE
    syscall
    test rax, rax
    jz .done
    js .maybe_retry
    mov rdx, rax
    mov rdi, rbx
    lea rsi, [buf]
    call write_all
    test rax, rax
    jnz .done
    jmp .read
.maybe_retry:
    cmp rax, -EINTR
    jne .done
    cmp byte [stopping], 0
    je .read
.done:
    pop rbx
    ret

check_flags:
    push rbx
    mov rbx, rdi
    lea rsi, [s_flag_help]
    call str_eq
    test rax, rax
    jnz .help
    mov rdi, rbx
    lea rsi, [s_flag_h]
    call str_eq
    test rax, rax
    jnz .help
    mov rdi, rbx
    lea rsi, [s_flag_version]
    call str_eq
    test rax, rax
    jnz .version
    pop rbx
    ret
.help:
    mov rdi, STDOUT
    lea rsi, [s_usage]
    call put_str
    xor rdi, rdi
    jmp exit_now
.version:
    mov rdi, STDOUT
    lea rsi, [s_version]
    call put_str
    xor rdi, rdi
    jmp exit_now

exit_now:
    mov rax, SYS_EXIT_GROUP
    syscall

section .rodata
s_listening:    db "nasmnetd listening on 0.0.0.0:", 0
s_nl:           db 10, 0
s_bad_port:     db "port must be a number from 1 to 65535", 10, 0
s_socket:       db "socket failed: ", 0
s_setsockopt:   db "setsockopt failed: ", 0
s_bind:         db "bind failed: ", 0
s_listen:       db "listen failed: ", 0
s_accept:       db "accept failed: ", 0
s_stopping:     db "nasmnetd shutting down", 10, 0
s_flag_help:    db "--help", 0
s_flag_h:       db "-h", 0
s_flag_version: db "--version", 0
s_version:      db "nasmnetd 1.1", 10, 0
s_usage:        db "usage: nasmnetd [port]", 10, 10
                db "Echoes back every byte it receives on a TCP connection.", 10
                db "The port defaults to 8080 when no argument is given.", 10, 10
                db "  -h, --help     show this message", 10
                db "      --version  show the version", 10, 0

section .data
one:    dd 1

section .bss
stopping: resb 1
addr:   resb 16
buf:    resb BUFSIZE
