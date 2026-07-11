bits 64
section .text
global _start

%define SYS_setpriority 141
%define SYS_execve       59
%define SYS_write         1
%define SYS_exit         60

_start:
    pop     rax
    pop     rdi
    mov     rbx, rax

    mov     r12d, 10

    cmp     rax, 2
    jl      .no_flag
    mov     rsi, [rsp]
    cmp     byte [rsi], '-'
    jne     .no_flag
    movzx   ecx, byte [rsi+1]
    cmp     cl, '0'
    jb      .no_flag
    cmp     cl, '9'
    ja      .no_flag

    inc     rsi
    xor     eax, eax
.pn:
    movzx   ecx, byte [rsi]
    sub     ecx, '0'
    jb      .pnd
    cmp     ecx, 9
    ja      .pnd
    imul    eax, eax, 10
    add     eax, ecx
    inc     rsi
    jmp     .pn
.pnd:
    mov     r12d, eax
    pop     rdi
    dec     rbx

.no_flag:

    cmp     rbx, 2
    jl      .usage

    mov     eax, SYS_setpriority
    xor     edi, edi
    xor     esi, esi
    mov     edx, r12d
    syscall

    mov     rdi, [rsp]
    mov     rsi, rsp

    mov     rdx, rsp
.find_envp:
    mov     rax, [rdx]
    add     rdx, 8
    test    rax, rax
    jnz     .find_envp

    mov     eax, SYS_execve
    syscall

    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel me]
    mov     edx, me_l
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
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
mu:   db "usage: nice [-N] cmd [args]",0x0a
mu_l: equ $-mu
me:   db "nice: exec failed",0x0a
me_l: equ $-me

