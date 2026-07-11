bits 64
section .text
global _start
%define SYS_open   2
%define SYS_close  3
%define SYS_utimensat 280
%define SYS_write  1
%define SYS_exit   60
%define O_WRONLY   1
%define O_CREAT    0x40

_start:
    pop     rcx
    cmp     rcx, 2
    jl      .usage
    pop     rdi
    dec     rcx
.loop:
    pop     rsi
    push    rcx

    mov     eax, SYS_open
    mov     rdi, rsi
    mov     esi, O_WRONLY|O_CREAT
    mov     edx, 0644o
    syscall
    test    rax, rax
    jns     .close
    jmp     .nxt
.close:
    push    rax
    mov     eax, SYS_close
    pop     rdi
    syscall
.nxt:
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
mu:  db "usage: touch file...",0x0a
mu_l: equ $-mu

