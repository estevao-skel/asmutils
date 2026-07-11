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
    cmp     rcx, 2
    jl      .usage
    pop     rdi
    pop     r14
    xor     r13d, r13d
.plen: cmp byte [r14+r13], 0
    je .pld
    inc r13d
    jmp .plen
.pld:
    dec     rcx
    dec     rcx
    test    rcx, rcx
    jz      .stdin_only
.floop:
    pop     rsi
    push    rcx
    push    rsi
    mov     eax, SYS_open
    mov     rdi, rsi
    xor     esi, esi
    syscall
    test    rax, rax
    js      .fskip
    mov     r12d, eax
    call    dogrep
    mov     eax, SYS_close
    mov     edi, r12d
    syscall
.fskip:
    pop     rsi
    pop     rcx
    dec     rcx
    jnz     .floop
    jmp     .quit
.stdin_only:
    xor     r12d, r12d
    call    dogrep
.quit:
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

dogrep:
    push    rbx
    push    rbp
    xor     ebp, ebp
.rd:
    mov     eax, SYS_read
    mov     edi, r12d
    lea     rsi, [rel ibuf]
    mov     edx, 4096
    syscall
    test    rax, rax
    jle     .fl
    mov     rbx, rax
    xor     ecx, ecx
.pb:
    cmp     rcx, rbx
    jge     .rd
    movzx   eax, byte [rel ibuf+rcx]
    inc     rcx
    cmp     al, 0x0a
    je      .emit
    cmp     ebp, 4094
    jge     .pb
    mov     [rel lb+rbp], al
    inc     ebp
    jmp     .pb
.emit:
    call    tryprint
    xor     ebp, ebp
    jmp     .pb
.fl:
    test    ebp, ebp
    jz      .dret
    call    tryprint
.dret:
    pop     rbp
    pop     rbx
    ret

tryprint:

    test    r13d, r13d
    jz      .tp_yes
    mov     eax, ebp
    sub     eax, r13d
    js      .tp_no
    xor     ecx, ecx
.scan:
    cmp     ecx, eax
    jg      .tp_no
    xor     edx, edx
.cmp:
    cmp     edx, r13d
    jge     .tp_yes
    movzx   esi, byte [rel lb+rcx+rdx]
    movzx   edi, byte [r14+rdx]
    cmp     sil, dil
    jne     .nxt
    inc     edx
    jmp     .cmp
.nxt:
    inc     ecx
    jmp     .scan
.tp_yes:
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel lb]
    mov     edx, ebp
    syscall
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    syscall
.tp_no:
    ret

section .data
mu:  db "usage: grep pat [file]",0x0a
mu_l: equ $-mu
nl: db 0x0a

section .bss
ibuf: resb 4096
lb:   resb 4096

