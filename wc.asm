bits 64
section .text
global _start
%define SYS_read   0
%define SYS_write  1
%define SYS_open   2
%define SYS_close  3
%define SYS_exit   60

_start:
    pop     rcx
    pop     rdi
    dec     rcx
    jz      .stdin_only
    pop     rsi
    push    rcx
    push    rsi
    mov     eax, SYS_open
    mov     rdi, rsi
    xor     esi, esi
    syscall
    test    rax, rax
    js      .err
    mov     r12d, eax
    call    do_wc
    mov     eax, SYS_close
    mov     edi, r12d
    syscall
    jmp     .exit

.stdin_only:
    xor     r12d, r12d
    call    do_wc

.exit:
    mov     eax, SYS_exit
    xor     edi, edi
    syscall
.err:
    mov     eax, SYS_exit
    mov     edi, 1
    syscall

do_wc:
    push    rbx
    push    rbp
    xor     r13, r13
    xor     r14, r14
    xor     r15, r15
    xor     ebp, ebp
.rd:
    mov     eax, SYS_read
    mov     edi, r12d
    lea     rsi, [rel buf]
    mov     edx, 4096
    syscall
    test    rax, rax
    jle     .print
    mov     rbx, rax
    add     r15, rax
    xor     ecx, ecx
.scan:
    cmp     rcx, rbx
    jge     .rd
    movzx   eax, byte [rel buf+rcx]
    inc     rcx
    cmp     al, 0x0a
    jne     .not_nl
    inc     r13
.not_nl:

    cmp     al, ' '
    je      .ws
    cmp     al, 0x09
    je      .ws
    cmp     al, 0x0a
    je      .ws
    cmp     al, 0x0d
    je      .ws

    test    ebp, ebp
    jnz     .scan
    inc     r14
    mov     ebp, 1
    jmp     .scan
.ws:
    xor     ebp, ebp
    jmp     .scan

.print:
    mov     rdi, r13
    call    pnum
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel spc]
    mov     edx, 1
    syscall
    mov     rdi, r14
    call    pnum
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel spc]
    mov     edx, 1
    syscall
    mov     rdi, r15
    call    pnum
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    syscall
    pop     rbp
    pop     rbx
    ret

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

section .data
spc: db 0x20
nl: db 0x0a

section .bss
buf:  resb 4096
nbuf: resb 24

