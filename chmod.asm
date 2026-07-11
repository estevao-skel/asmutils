bits 64
section .text
global _start

%define SYS_chmod  90
%define SYS_write  1
%define SYS_exit   60

_start:
    pop     rcx
    cmp     rcx, 3
    jl      .usage
    pop     rdi
    pop     rsi
    pop     rdi

    xor     eax, eax
.parse:
    movzx   ecx, byte [rsi]
    test    ecx, ecx
    jz      .do
    sub     ecx, '0'
    js      .do
    cmp     ecx, 7
    jg      .do
    imul    eax, eax, 8
    add     eax, ecx
    inc     rsi
    jmp     .parse
.do:
    mov     esi, eax
    mov     eax, SYS_chmod

    syscall
    test    rax, rax
    js      .err
    mov     eax, SYS_exit
    xor     edi, edi
    syscall
.usage:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel msg_usage]
    mov     edx, msg_usage_len
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall
.err:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel msg_err]
    mov     edx, msg_err_len
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall

section .data
msg_usage:     db "usage: chmod mode file",0x0a
msg_usage_len: equ $ - msg_usage
msg_err:       db "chmod: failed",0x0a
msg_err_len:   equ $ - msg_err

