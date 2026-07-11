bits 64
section .text
global _start
%define SYS_mount  165
%define SYS_write    1
%define SYS_exit    60

_start:
    pop     rcx
    cmp     rcx, 4
    jl      .usage
    pop     rdi
    pop     r12
    pop     r13
    pop     r14

    mov     eax, SYS_mount
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    xor     ecx, ecx
    xor     r8d, r8d
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
mu:  db "usage: mount src tgt fstype",0x0a
mu_l: equ $-mu
me:  db "mount: failed",0x0a
me_l: equ $-me

