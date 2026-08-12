bits 64
default rel

global str_len
global u64_to_dec
global parse_u16
global str_eq

section .text

str_len:
    xor rax, rax
.next:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .next
.done:
    ret

u64_to_dec:
    mov rax, rdi
    mov r8, rsi
    lea r9, [rsi + 20]
    mov rcx, 10
    mov r10, r9
.digit:
    xor rdx, rdx
    div rcx
    add dl, '0'
    dec r10
    mov [r10], dl
    test rax, rax
    jnz .digit

    mov rax, r9
    sub rax, r10
    mov rcx, rax
    mov rsi, r10
    mov rdi, r8
.copy:
    test rcx, rcx
    jz .done
    mov dl, [rsi]
    mov [rdi], dl
    inc rsi
    inc rdi
    dec rcx
    jmp .copy
.done:
    ret

str_eq:
    xor rcx, rcx
.next:
    mov al, [rdi + rcx]
    mov dl, [rsi + rcx]
    cmp al, dl
    jne .no
    test al, al
    jz .yes
    inc rcx
    jmp .next
.yes:
    mov rax, 1
    ret
.no:
    xor rax, rax
    ret

parse_u16:
    xor rax, rax
    xor rcx, rcx
    cmp byte [rdi], 0
    je .bad
.next:
    movzx rdx, byte [rdi + rcx]
    test dl, dl
    jz .done
    sub dl, '0'
    cmp dl, 9
    ja .bad
    imul rax, rax, 10
    add rax, rdx
    cmp rax, 65535
    ja .bad
    inc rcx
    cmp rcx, 6
    ja .bad
    jmp .next
.done:
    ret
.bad:
    mov rax, -1
    ret
