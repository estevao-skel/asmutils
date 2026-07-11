bits 64
section .text
global _start
%define SYS_clock_gettime 228
%define SYS_fork    57
%define SYS_execve  59
%define SYS_wait4   61
%define SYS_write    1
%define SYS_exit    60
%define CLOCK_MONOTONIC 1

_start:
    pop     rcx
    cmp     rcx, 2
    jl      .usage
    pop     rdi
    dec     rcx
    pop     r14

    mov     r15, rsp

    mov     eax, SYS_clock_gettime
    mov     edi, CLOCK_MONOTONIC
    lea     rsi, [rel t_start]
    syscall

    mov     eax, SYS_fork
    syscall
    test    rax, rax
    jz      .child
    js      .err

    mov     r12, rax
    mov     eax, SYS_wait4
    mov     edi, r12d
    lea     rsi, [rel wstat]
    xor     edx, edx
    xor     r10d, r10d
    syscall

    mov     eax, SYS_clock_gettime
    mov     edi, CLOCK_MONOTONIC
    lea     rsi, [rel t_end]
    syscall

    mov     rax, [rel t_end]
    sub     rax, [rel t_start]
    mov     rbx, [rel t_end+8]
    sub     rbx, [rel t_start+8]
    jns     .no_borrow
    dec     rax
    add     rbx, 1000000000
.no_borrow:

    mov     rdi, rax
    call    pnum
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel dot]
    mov     edx, 1
    syscall

    mov     rax, rbx
    mov     rcx, 1000000
    xor     edx, edx
    div     rcx
    mov     rdi, rax
    call    pnum3
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel s_str]
    mov     edx, 2
    syscall

    mov     eax, SYS_exit
    xor     edi, edi
    syscall

.child:

    lea     rdi, [rel argv_buf]
    mov     [rdi], r14
    add     rdi, 8
    mov     rcx, r15
.copy_args:
    mov     rax, [rcx]
    mov     [rdi], rax
    add     rcx, 8
    add     rdi, 8
    test    rax, rax
    jnz     .copy_args

    mov     eax, SYS_execve
    mov     rdi, r14
    lea     rsi, [rel argv_buf]
    lea     rdx, [rel null_env]
    syscall

    mov     eax, SYS_exit
    mov     edi, 127
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
    mov     eax, SYS_exit
    mov     edi, 1
    syscall

pnum:
    push    rbx
    lea     rbx, [rel nbuf+19]
    mov     byte [rbx], 0
    dec     rbx
    mov     rax, rdi
    mov     ecx, 10
.nd:
    xor     edx, edx
    div     rcx
    add     dl, '0'
    mov     [rbx], dl
    dec     rbx
    test    rax, rax
    jnz     .nd
    inc     rbx
    lea     rdx, [rel nbuf+19]
    sub     rdx, rbx
    mov     rsi, rbx
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    pop     rbx
    ret

pnum3:
    push    rbx
    lea     rbx, [rel nbuf3]
    mov     rax, rdi
    cmp     rax, 999
    jbe     .ok
    mov     rax, 999
.ok:
    mov     ecx, 10
    xor     edx, edx
    div     rcx
    add     dl, '0'
    mov     [rbx+2], dl
    xor     edx, edx
    div     rcx
    add     dl, '0'
    mov     [rbx+1], dl
    add     al, '0'
    mov     [rbx], al
    mov     eax, SYS_write
    mov     edi, 1
    mov     rsi, rbx
    mov     edx, 3
    syscall
    pop     rbx
    ret

section .data
mu:    db "usage: time cmd [args]",0x0a
mu_l:  equ $-mu
dot:   db "."
s_str: db "s",0x0a

section .bss
t_start:  resq 2
t_end:    resq 2
wstat:    resd 1
nbuf:     resb 24
nbuf3:    resb 4
argv_buf: resq 64
null_env: resq 1

