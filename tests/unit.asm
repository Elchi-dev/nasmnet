bits 64
default rel

%include "sys.inc"

global _start

extern str_len
extern str_eq
extern parse_u16
extern u64_to_dec
extern err_name
extern put_str
extern put_u64
extern conn_init
extern conn_alloc
extern conn_free
extern conn_ptr
extern conn_live

section .text

_start:
    mov qword [passed], 0
    mov qword [failed], 0

    lea rdi, [t_empty]
    call str_len
    mov rdi, rax
    xor rsi, rsi
    lea rdx, [n_len_empty]
    call expect

    lea rdi, [t_abc]
    call str_len
    mov rdi, rax
    mov rsi, 3
    lea rdx, [n_len_abc]
    call expect

    lea rdi, [t_hello]
    call str_len
    mov rdi, rax
    mov rsi, 11
    lea rdx, [n_len_hello]
    call expect

    lea rdi, [t_abc]
    lea rsi, [t_abc2]
    call str_eq
    mov rdi, rax
    mov rsi, 1
    lea rdx, [n_eq_same]
    call expect

    lea rdi, [t_abc]
    lea rsi, [t_abd]
    call str_eq
    mov rdi, rax
    xor rsi, rsi
    lea rdx, [n_eq_diff]
    call expect

    lea rdi, [t_abc]
    lea rsi, [t_abcd]
    call str_eq
    mov rdi, rax
    xor rsi, rsi
    lea rdx, [n_eq_prefix]
    call expect

    lea rdi, [t_zero]
    call parse_u16
    mov rdi, rax
    xor rsi, rsi
    lea rdx, [n_p_zero]
    call expect

    lea rdi, [t_8080]
    call parse_u16
    mov rdi, rax
    mov rsi, 8080
    lea rdx, [n_p_8080]
    call expect

    lea rdi, [t_65535]
    call parse_u16
    mov rdi, rax
    mov rsi, 65535
    lea rdx, [n_p_max]
    call expect

    lea rdi, [t_padded]
    call parse_u16
    mov rdi, rax
    mov rsi, 80
    lea rdx, [n_p_padded]
    call expect

    lea rdi, [t_65536]
    call parse_u16
    mov rdi, rax
    mov rsi, -1
    lea rdx, [n_p_over]
    call expect

    lea rdi, [t_empty]
    call parse_u16
    mov rdi, rax
    mov rsi, -1
    lea rdx, [n_p_empty]
    call expect

    lea rdi, [t_trail]
    call parse_u16
    mov rdi, rax
    mov rsi, -1
    lea rdx, [n_p_trail]
    call expect

    lea rdi, [t_lead]
    call parse_u16
    mov rdi, rax
    mov rsi, -1
    lea rdx, [n_p_lead]
    call expect

    lea rdi, [t_neg]
    call parse_u16
    mov rdi, rax
    mov rsi, -1
    lea rdx, [n_p_neg]
    call expect

    lea rdi, [t_long]
    call parse_u16
    mov rdi, rax
    mov rsi, -1
    lea rdx, [n_p_long]
    call expect

    lea rdi, [t_space]
    call parse_u16
    mov rdi, rax
    mov rsi, -1
    lea rdx, [n_p_space]
    call expect

    xor rdi, rdi
    lea rsi, [scratch]
    call u64_to_dec
    mov rdi, rax
    mov rsi, 1
    lea rdx, [n_d_zero_len]
    call expect
    lea rdi, [scratch]
    lea rsi, [t_zero]
    call expect_str
    lea rdi, [n_d_zero]
    call report_str

    mov rdi, 8080
    lea rsi, [scratch]
    call u64_to_dec
    mov byte [scratch + rax], 0
    lea rdi, [scratch]
    lea rsi, [t_8080]
    call expect_str
    lea rdi, [n_d_8080]
    call report_str

    mov rdi, -1
    lea rsi, [scratch]
    call u64_to_dec
    mov rdi, rax
    mov rsi, 20
    lea rdx, [n_d_max_len]
    call expect
    mov byte [scratch + 20], 0
    lea rdi, [scratch]
    lea rsi, [t_u64max]
    call expect_str
    lea rdi, [n_d_max]
    call report_str

    mov rdi, 98
    call err_name
    mov rdi, rax
    lea rsi, [t_eaddrinuse]
    call expect_str
    lea rdi, [n_e_known]
    call report_str

    mov rdi, 4242
    call err_name
    mov rdi, rax
    lea rsi, [t_unknown]
    call expect_str
    lea rdi, [n_e_unknown]
    call report_str

    call conn_init
    call conn_live
    mov rdi, rax
    xor rsi, rsi
    lea rdx, [n_c_empty]
    call expect

    call conn_alloc
    mov r12, rax
    cmp r12, 0
    setge al
    movzx rdi, al
    mov rsi, 1
    lea rdx, [n_c_first]
    call expect

    call conn_live
    mov rdi, rax
    mov rsi, 1
    lea rdx, [n_c_one]
    call expect

    call conn_alloc
    mov r13, rax
    cmp r13, r12
    setne al
    movzx rdi, al
    mov rsi, 1
    lea rdx, [n_c_distinct]
    call expect

    mov rdi, r12
    call conn_free
    call conn_live
    mov rdi, rax
    mov rsi, 1
    lea rdx, [n_c_afterfree]
    call expect

    call conn_alloc
    mov rdi, rax
    mov rsi, r12
    lea rdx, [n_c_reuse]
    call expect

    call conn_init
    xor r12, r12
.drain:
    call conn_alloc
    cmp rax, 0
    jl .drained
    inc r12
    cmp r12, MAX_CONNS + 8
    jb .drain
.drained:
    mov rdi, r12
    mov rsi, MAX_CONNS
    lea rdx, [n_c_capacity]
    call expect

    call conn_alloc
    mov rdi, rax
    mov rsi, -1
    lea rdx, [n_c_exhausted]
    call expect

    mov rdi, 7
    call conn_free
    call conn_alloc
    mov rdi, rax
    mov rsi, 7
    lea rdx, [n_c_recycle]
    call expect

    call conn_init
    xor rdi, rdi
    call conn_ptr
    mov r12, rax
    mov rdi, 1
    call conn_ptr
    sub rax, r12
    mov rdi, rax
    mov rsi, conn_size
    lea rdx, [n_c_stride]
    call expect

    mov rdi, MAX_CONNS
    call conn_ptr
    mov rdi, rax
    xor rsi, rsi
    lea rdx, [n_c_bounds]
    call expect

    xor rdi, rdi
    call conn_ptr
    mov dword [rax + conn.fd], 42
    mov qword [rax + conn.len], 99
    mov byte [rax + conn.buf], 'z'
    xor rdi, rdi
    call conn_ptr
    mov edi, [rax + conn.fd]
    mov rsi, 42
    lea rdx, [n_c_field]
    call expect

    xor rdi, rdi
    call conn_ptr
    movzx rdi, byte [rax + conn.buf]
    mov rsi, 'z'
    lea rdx, [n_c_buf]
    call expect

    mov rdi, STDOUT
    lea rsi, [s_nl]
    call put_str
    mov rdi, STDOUT
    mov rsi, [passed]
    call put_u64
    mov rdi, STDOUT
    lea rsi, [s_passed]
    call put_str
    mov rdi, STDOUT
    mov rsi, [failed]
    call put_u64
    mov rdi, STDOUT
    lea rsi, [s_failed]
    call put_str

    mov rdi, [failed]
    test rdi, rdi
    jz .exit
    mov rdi, 1
.exit:
    mov rax, SYS_EXIT_GROUP
    syscall

expect:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    cmp rbx, r12
    jne .bad
    inc qword [passed]
    mov rdi, STDOUT
    lea rsi, [s_ok]
    call put_str
    mov rdi, STDOUT
    mov rsi, r13
    call put_str
    jmp .end
.bad:
    inc qword [failed]
    mov rdi, STDOUT
    lea rsi, [s_fail]
    call put_str
    mov rdi, STDOUT
    mov rsi, r13
    call put_str
    mov rdi, STDOUT
    lea rsi, [s_want]
    call put_str
    mov rdi, STDOUT
    mov rsi, r12
    call put_u64
    mov rdi, STDOUT
    lea rsi, [s_got]
    call put_str
    mov rdi, STDOUT
    mov rsi, rbx
    call put_u64
.end:
    mov rdi, STDOUT
    lea rsi, [s_nl]
    call put_str
    pop r13
    pop r12
    pop rbx
    ret

expect_str:
    call str_eq
    mov [last_result], rax
    ret

report_str:
    push rbx
    mov rbx, rdi
    cmp qword [last_result], 0
    je .bad
    inc qword [passed]
    mov rdi, STDOUT
    lea rsi, [s_ok]
    call put_str
    jmp .name
.bad:
    inc qword [failed]
    mov rdi, STDOUT
    lea rsi, [s_fail]
    call put_str
.name:
    mov rdi, STDOUT
    mov rsi, rbx
    call put_str
    mov rdi, STDOUT
    lea rsi, [s_nl]
    call put_str
    pop rbx
    ret

section .rodata
t_empty:        db 0
t_abc:          db "abc", 0
t_abc2:         db "abc", 0
t_abd:          db "abd", 0
t_abcd:         db "abcd", 0
t_hello:        db "hello world", 0
t_zero:         db "0", 0
t_8080:         db "8080", 0
t_65535:        db "65535", 0
t_65536:        db "65536", 0
t_padded:       db "00080", 0
t_trail:        db "12abc", 0
t_lead:         db "abc12", 0
t_neg:          db "-1", 0
t_long:         db "1234567", 0
t_space:        db "80 ", 0
t_u64max:       db "18446744073709551615", 0
t_eaddrinuse:   db "EADDRINUSE", 0
t_unknown:      db "UNKNOWN", 0

n_len_empty:    db "str_len of an empty string", 0
n_len_abc:      db "str_len of a short string", 0
n_len_hello:    db "str_len across a space", 0
n_eq_same:      db "str_eq on identical strings", 0
n_eq_diff:      db "str_eq on a differing last byte", 0
n_eq_prefix:    db "str_eq rejects a prefix", 0
n_p_zero:       db "parse_u16 accepts zero", 0
n_p_8080:       db "parse_u16 of 8080", 0
n_p_max:        db "parse_u16 of 65535", 0
n_p_padded:     db "parse_u16 ignores leading zeros", 0
n_p_over:       db "parse_u16 rejects 65536", 0
n_p_empty:      db "parse_u16 rejects an empty string", 0
n_p_trail:      db "parse_u16 rejects trailing letters", 0
n_p_lead:       db "parse_u16 rejects leading letters", 0
n_p_neg:        db "parse_u16 rejects a minus sign", 0
n_p_long:       db "parse_u16 rejects seven digits", 0
n_p_space:      db "parse_u16 rejects a trailing space", 0
n_d_zero_len:   db "u64_to_dec writes one byte for zero", 0
n_d_zero:       db "u64_to_dec of zero", 0
n_d_8080:       db "u64_to_dec of 8080", 0
n_d_max_len:    db "u64_to_dec writes twenty bytes for the maximum", 0
n_d_max:        db "u64_to_dec of the largest u64", 0
n_e_known:      db "err_name maps 98 to EADDRINUSE", 0
n_e_unknown:    db "err_name falls back for an unlisted code", 0
n_c_empty:      db "conn_init leaves no live slots", 0
n_c_first:      db "conn_alloc hands out a usable index", 0
n_c_one:        db "conn_live counts one slot", 0
n_c_distinct:   db "conn_alloc does not hand out the same slot twice", 0
n_c_afterfree:  db "conn_free drops the live count", 0
n_c_reuse:      db "a freed slot is handed out again", 0
n_c_capacity:   db "the table holds exactly MAX_CONNS slots", 0
n_c_exhausted:  db "conn_alloc reports -1 when full", 0
n_c_recycle:    db "a slot freed while full becomes available", 0
n_c_stride:     db "slots are one conn_size apart", 0
n_c_bounds:     db "conn_ptr rejects an index past the end", 0
n_c_field:      db "a field written to a slot reads back", 0
n_c_buf:        db "the slot buffer is writable", 0

s_ok:           db "  ok   ", 0
s_fail:         db "  FAIL ", 0
s_want:         db " want ", 0
s_got:          db " got ", 0
s_nl:           db 10, 0
s_passed:       db " passed, ", 0
s_failed:       db " failed", 10, 0

section .bss
passed:         resq 1
failed:         resq 1
last_result:    resq 1
scratch:        resb 64
