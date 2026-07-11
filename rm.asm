bits 64
section .text
global _start
%define SYS_unlink  87
%define SYS_write    1
%define SYS_exit    60

_start:
    pop     rcx
    cmp     rcx, 2
    jl      .usage
    pop     rdi
    dec     rcx
.loop:
    pop     rdi
    push    rcx
    mov     eax, SYS_unlink
    syscall
    pop     rcx
    dec     rcx
    jnz     .loop
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
section .data
mu:  db "usage: rm file...",0x0a
mu_l: equ $-mu

