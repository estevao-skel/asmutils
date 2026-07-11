bits 64
section .text
global _start

%define SYS_statfs  137
%define SYS_write     1
%define SYS_exit     60

%define ST_BSIZE    8
%define ST_BLOCKS  16
%define ST_BFREE   24
%define ST_BAVAIL  32

_start:
    pop     rcx
    cmp     rcx, 2
    jl      .usage
    pop     rdi
    pop     r15

    mov     rdi, r15
    lea     rsi, [rel stbuf]
    mov     eax, SYS_statfs
    syscall
    test    rax, rax
    js      .err

    lea     rsi, [rel stbuf]
    mov     r8,  [rsi + ST_BSIZE]
    mov     r9,  [rsi + ST_BLOCKS]
    mov     r10, [rsi + ST_BFREE]
    mov     r11, [rsi + ST_BAVAIL]

    mov     rax, r8
    mul     r9
    shr     rax, 10
    mov     r12, rax

    mov     rax, r8
    mul     r10
    shr     rax, 10
    mov     r13, rax
    mov     r14, r12
    sub     r14, r13

    mov     rax, r8
    mul     r11
    shr     rax, 10
    mov     rbx, rax

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel hdr]
    mov     edx, hdr_len
    syscall

    mov     rsi, r15
    xor     edx, edx
.plen: cmp byte [rsi+rdx], 0
    je .pl_done
    inc edx
    jmp .plen
.pl_done:
    mov     eax, SYS_write
    mov     edi, 1
    syscall

    mov     rdi, r12
    call    pnum
    mov     rdi, r14
    call    pnum
    mov     rdi, rbx
    call    pnum

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
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

pnum:
    push    rbp

    lea     rbp, [rel nbuf+18]
    mov     rax, rdi
    mov     ecx, 10
.nd:
    xor     edx, edx
    div     rcx
    add     dl, '0'
    mov     [rbp], dl
    dec     rbp
    test    rax, rax
    jnz     .nd

    mov     byte [rbp], ' '

    lea     rdx, [rel nbuf+19]
    sub     rdx, rbp
    mov     rsi, rbp
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    pop     rbp
    ret

section .data
hdr:     db "Filesystem       1K-blocks       Used  Available",0x0a
hdr_len: equ $ - hdr
msg_u:   db "usage: df path",0x0a
mu_len:  equ $ - msg_u
msg_e:   db "df: statfs failed",0x0a
me_len:  equ $ - msg_e
nl:      db 0x0a

section .bss
stbuf: resb 120
nbuf:  resb 24

