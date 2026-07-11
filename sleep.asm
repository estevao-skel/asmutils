bits 64
section .text
global _start

%define SYS_nanosleep 35
%define SYS_write      1
%define SYS_exit      60

_start:
    pop     rcx
    cmp     rcx, 2
    jl      .usage
    pop     rdi
    pop     rsi

    xor     eax, eax
.parse:
    movzx   ecx, byte [rsi]
    test    cl, cl
    jz      .done
    sub     cl, '0'
    cmp     cl, 9
    ja      .usage
    imul    eax, eax, 10
    movzx   ecx, cl
    add     eax, ecx
    inc     rsi
    jmp     .parse

.done:
    push    0
    push    rax
    mov     rdi, rsp
    xor     esi, esi
    mov     eax, SYS_nanosleep
    syscall
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
mu:   db "usage: sleep seconds", 0x0a
mu_l: equ $-mu

