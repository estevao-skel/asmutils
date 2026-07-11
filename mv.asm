bits 64
section .text
global _start
%define SYS_rename  82
%define SYS_write    1
%define SYS_exit    60

_start:
    pop     rcx
    cmp     rcx, 3
    jl      .usage
    pop     rdi
    pop     rdi
    pop     rsi
    mov     eax, SYS_rename
    syscall
    test    rax, rax
    js      .err
    mov     eax, SYS_exit
    xor     edi, edi
    syscall
.usage:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel mu]
    mov     edx, mu_l
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall
.err:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel me]
    mov     edx, me_l
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall
section .data
mu:  db "usage: mv src dst",0x0a
mu_l: equ $-mu
me:  db "mv: failed",0x0a
me_l: equ $-me

