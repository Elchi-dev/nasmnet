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
extern sig_block
extern sig_unblock
extern conn_init
extern conn_alloc
extern conn_free
extern conn_ptr
extern ep_create
extern ep_add
extern ep_mod
extern ep_del

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

    mov rax, SYS_FCNTL
    mov rdi, r12
    mov rsi, F_SETFL
    mov rdx, O_NONBLOCK
    syscall
    test rax, rax
    js .fcntl_failed

    call ep_create
    test rax, rax
    js .epoll_failed
    mov r14, rax
    mov [epfd], rax

    call conn_init

    mov rdi, r14
    mov rsi, r12
    mov rdx, EPOLLIN
    mov rcx, LISTEN_TAG
    call ep_add
    test rax, rax
    js .epoll_failed

    mov rdi, STDOUT
    lea rsi, [s_listening]
    call put_str
    mov rdi, STDOUT
    mov rsi, r13
    call put_u64
    mov rdi, STDOUT
    lea rsi, [s_nl]
    call put_str

.event_loop:
    mov rdi, STOPMASK
    call sig_block

    cmp byte [stopping], 0
    jne .shutdown

    mov rax, SYS_EPOLL_PWAIT
    mov rdi, r14
    lea rsi, [events]
    mov rdx, MAX_EVENTS
    mov r10, -1
    lea r8, [emptymask]
    mov r9, 8
    syscall
    mov r15, rax

    mov rdi, STOPMASK
    call sig_unblock

    test r15, r15
    jle .event_loop

    xor rbx, rbx
.next_event:
    cmp rbx, r15
    jae .event_loop

    imul rax, rbx, EV_SIZE
    lea rax, [events + rax]
    mov r13d, [rax]
    mov rbp, [rax + 4]

    cmp rbp, LISTEN_TAG
    je .incoming

    mov rdi, rbp
    mov rsi, r13
    call serve_event
    inc rbx
    jmp .next_event

.incoming:
    call accept_ready
    inc rbx
    jmp .next_event

.shutdown:
    mov rdi, STDOUT
    lea rsi, [s_stopping]
    call put_str

    xor rbx, rbx
.close_each:
    mov rdi, rbx
    call conn_ptr
    mov edi, [rax + conn.fd]
    test edi, edi
    jz .close_next
    mov rax, SYS_CLOSE
    syscall
.close_next:
    inc rbx
    cmp rbx, MAX_CONNS
    jb .close_each

    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    xor rdi, rdi
    jmp exit_now

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

.fcntl_failed:
    lea rsi, [s_fcntl]
    jmp fail_syscall

.epoll_failed:
    lea rsi, [s_epoll]
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

accept_ready:
    push rbx
    push r13
.again:
    mov rax, SYS_ACCEPT4
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    mov r10, SOCK_NONBLOCK
    syscall
    test rax, rax
    js .done
    mov r13, rax

    call conn_alloc
    test rax, rax
    js .no_room
    mov rbx, rax

    mov rdi, rbx
    call conn_ptr
    mov [rax + conn.fd], r13d
    mov dword [rax + conn.state], CONN_READING
    mov qword [rax + conn.off], 0
    mov qword [rax + conn.len], 0

    mov rdi, [epfd]
    mov rsi, r13
    mov rdx, EPOLLIN | EPOLLRDHUP
    mov rcx, rbx
    call ep_add
    test rax, rax
    js .add_failed
    jmp .again

.add_failed:
    mov rdi, rbx
    call conn_ptr
    mov dword [rax + conn.fd], 0
    mov rdi, rbx
    call conn_free

.no_room:
    mov rax, SYS_CLOSE
    mov rdi, r13
    syscall
    jmp .again

.done:
    pop r13
    pop rbx
    ret

serve_event:
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    call conn_ptr
    mov rbx, rax

    test r13d, EPOLLERR | EPOLLHUP
    jnz .close

    cmp dword [rbx + conn.state], CONN_WRITING
    je .writable

    test r13d, EPOLLIN | EPOLLRDHUP
    jz .done

    mov rax, SYS_READ
    mov edi, [rbx + conn.fd]
    lea rsi, [rbx + conn.buf]
    mov rdx, BUFSIZE
    syscall
    test rax, rax
    jz .close
    js .read_failed
    mov [rbx + conn.len], rax
    mov qword [rbx + conn.off], 0
    jmp .flush

.read_failed:
    cmp rax, -EAGAIN
    je .done
    cmp rax, -EINTR
    je .done
    jmp .close

.writable:
    test r13d, EPOLLOUT
    jz .done

.flush:
    mov rax, SYS_WRITE
    mov edi, [rbx + conn.fd]
    lea rsi, [rbx + conn.buf]
    add rsi, [rbx + conn.off]
    mov rdx, [rbx + conn.len]
    sub rdx, [rbx + conn.off]
    syscall
    test rax, rax
    js .write_failed
    add [rbx + conn.off], rax
    mov rax, [rbx + conn.off]
    cmp rax, [rbx + conn.len]
    jb .want_out

    cmp dword [rbx + conn.state], CONN_READING
    je .done
    mov dword [rbx + conn.state], CONN_READING
    mov rdi, [epfd]
    mov esi, [rbx + conn.fd]
    mov rdx, EPOLLIN | EPOLLRDHUP
    mov rcx, r12
    call ep_mod
    jmp .done

.want_out:
    cmp dword [rbx + conn.state], CONN_WRITING
    je .done
    mov dword [rbx + conn.state], CONN_WRITING
    mov rdi, [epfd]
    mov esi, [rbx + conn.fd]
    mov rdx, EPOLLOUT
    mov rcx, r12
    call ep_mod
    jmp .done

.write_failed:
    cmp rax, -EAGAIN
    je .want_out
    cmp rax, -EINTR
    je .flush
    jmp .close

.close:
    mov rdi, [epfd]
    mov esi, [rbx + conn.fd]
    call ep_del
    mov rax, SYS_CLOSE
    mov edi, [rbx + conn.fd]
    syscall
    mov dword [rbx + conn.fd], 0
    mov rdi, r12
    call conn_free

.done:
    pop r13
    pop r12
    pop rbx
    ret

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
s_fcntl:        db "fcntl failed: ", 0
s_epoll:        db "epoll setup failed: ", 0
s_stopping:     db "nasmnetd shutting down", 10, 0
s_flag_help:    db "--help", 0
s_flag_h:       db "-h", 0
s_flag_version: db "--version", 0
s_version:      db "nasmnetd 1.1.2", 10, 0
s_usage:        db "usage: nasmnetd [port]", 10, 10
                db "Echoes back every byte it receives on a TCP connection.", 10
                db "The port defaults to 8080 when no argument is given.", 10, 10
                db "  -h, --help     show this message", 10
                db "      --version  show the version", 10, 0

section .data
one:    dd 1

section .bss
stopping:  resb 1
align 8
emptymask: resq 1
epfd:      resq 1
events:    resb EV_SIZE * MAX_EVENTS
addr:   resb 16
buf:    resb BUFSIZE
