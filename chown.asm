bits 64
section .text
global _start

%define SYS_chown   92
%define SYS_write    1
%define SYS_exit    60

parse_uint:
    xor     eax, eax
.lp:
    movzx   ecx, byte [rsi]
    sub     ecx, '0'
    jb      .done
    cmp     ecx, 9
    ja      .done
    imul    eax, eax, 10
    add     eax, ecx
    inc     rsi
    jmp     .lp
.done:
    ret

_start:
    pop     rcx
    cmp     rcx, 3
    jl      .usage
    pop     rdi
    pop     rsi
    pop     rdi

    push    rdi

    push    rsi
    xor     eax, eax
    mov     r12, -1
    mov     rbx, rsi

    call    parse_uint
    mov     r13d, eax

    movzx   ecx, byte [rsi]
    cmp     ecx, ':'
    jne     .nogrp
    inc     rsi
    call    parse_uint
    mov     r12d, eax
.nogrp:
    pop     rsi

    pop     rdi
    mov     eax, SYS_chown
    mov     esi, r13d
    mov     edx, r12d
    syscall
    test    rax, rax
    js      .err

    mov     eax, SYS_exit
    xor     edi, edi
    syscall

.usage:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel msg_u]
    mov     edx, mu_len
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall

.err:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel msg_e]
    mov     edx, me_len
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall

section .data
msg_u:  db "usage: chown owner[:group] file",0x0a
mu_len: equ $ - msg_u
msg_e:  db "chown: failed",0x0a
me_len: equ $ - msg_e

