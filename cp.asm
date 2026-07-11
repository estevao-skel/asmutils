bits 64
section .text
global _start

%define SYS_read   0
%define SYS_write  1
%define SYS_open   2
%define SYS_close  3
%define SYS_exit   60
%define O_RDONLY   0
%define O_WRONLY   1
%define O_CREAT    0x40
%define O_TRUNC    0x200
%define BUFSIZE    4096

_start:
    pop     rcx
    cmp     rcx, 3
    jl      .usage
    pop     rdi
    pop     rsi
    pop     rdx

    mov     eax, SYS_open
    mov     rdi, rsi
    xor     esi, esi
    syscall
    test    rax, rax
    js      .err
    mov     r12d, eax

    mov     eax, SYS_open
    mov     rdi, rdx
    mov     esi, O_WRONLY|O_CREAT|O_TRUNC
    mov     edx, 0644o
    syscall
    test    rax, rax
    js      .err
    mov     r13d, eax

.loop:
    mov     eax, SYS_read
    mov     edi, r12d
    lea     rsi, [rel buf]
    mov     edx, BUFSIZE
    syscall
    test    rax, rax
    jle     .done
    mov     r14, rax
    mov     eax, SYS_write
    mov     edi, r13d
    lea     rsi, [rel buf]
    mov     rdx, r14
    syscall
    jmp     .loop

.done:
    mov     eax, SYS_close
    mov     edi, r12d
    syscall
    mov     eax, SYS_close
    mov     edi, r13d
    syscall
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
msg_u:  db "usage: cp src dst",0x0a
mu_len: equ $ - msg_u
msg_e:  db "cp: error",0x0a
me_len: equ $ - msg_e

section .bss
buf: resb 4096

