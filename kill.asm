bits 64
section .text
global _start
%define SYS_kill   62
%define SYS_write   1
%define SYS_exit   60

_start:
    pop     rcx
    cmp     rcx, 2
    jl      .usage
    pop     rdi
    pop     rsi

    mov     r12d, 15
    cmp     byte [rsi], '-'
    jne     .parse_pid
    inc     rsi
    xor     eax, eax
.ps: movzx ecx, byte [rsi]
    sub ecx, '0'
    jb .psd
    cmp ecx, 9
    ja .psd
    imul eax, eax, 10
    add eax, ecx
    inc rsi
    jmp .ps
.psd:
    mov     r12d, eax

    pop     rsi
    jmp     .parse_pid2

.parse_pid:
.parse_pid2:
    xor     eax, eax
.pp: movzx ecx, byte [rsi]
    sub ecx, '0'
    jb .ppd
    cmp ecx, 9
    ja .ppd
    imul eax, eax, 10
    add eax, ecx
    inc rsi
    jmp .pp
.ppd:

    mov     edi, eax
    mov     esi, r12d
    mov     eax, SYS_kill
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
mu:  db "usage: kill [-sig] pid",0x0a
mu_l: equ $-mu
me:  db "kill: failed",0x0a
me_l: equ $-me

