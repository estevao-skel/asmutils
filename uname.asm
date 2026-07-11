bits 64
section .text
global _start
%define SYS_uname  63
%define SYS_write   1
%define SYS_exit   60

%define UTS_LEN  65

_start:
    lea     rdi, [rel ubuf]
    mov     eax, SYS_uname
    syscall

    pop     rcx
    pop     rdi
    dec     rcx
    jz      .all

    pop     rsi
    cmp     byte [rsi], '-'
    jne     .all
    inc     rsi
.flags:
    movzx   eax, byte [rsi]
    inc     rsi
    test    al, al
    jz      .nl_exit
    cmp     al, 'a'
    je      .all
    cmp     al, 's'
    je      .sysname
    cmp     al, 'n'
    je      .nodename
    cmp     al, 'r'
    je      .release
    cmp     al, 'v'
    je      .version
    cmp     al, 'm'
    je      .machine
    jmp     .flags

.all:
    lea     rsi, [rel ubuf]
    call    pfield
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel spc]
    mov     edx, 1
    syscall
    lea     rsi, [rel ubuf+UTS_LEN]
    call    pfield
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel spc]
    mov     edx, 1
    syscall
    lea     rsi, [rel ubuf+UTS_LEN*2]
    call    pfield
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel spc]
    mov     edx, 1
    syscall
    lea     rsi, [rel ubuf+UTS_LEN*3]
    call    pfield
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel spc]
    mov     edx, 1
    syscall
    lea     rsi, [rel ubuf+UTS_LEN*4]
    call    pfield
    jmp     .nl_exit

.sysname:  lea rsi, [rel ubuf]
    call    pfield
    jmp     .nl_exit
.nodename: lea rsi, [rel ubuf+UTS_LEN]
    call    pfield
    jmp     .nl_exit
.release:  lea rsi, [rel ubuf+UTS_LEN*2]
    call    pfield
    jmp     .nl_exit
.version:  lea rsi, [rel ubuf+UTS_LEN*3]
    call    pfield
    jmp     .nl_exit
.machine:  lea rsi, [rel ubuf+UTS_LEN*4]
    call    pfield

.nl_exit:
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    syscall
    mov     eax, SYS_exit
    xor     edi, edi
    syscall

pfield:
    xor     edx, edx
.l: cmp byte [rsi+rdx], 0
    je .ld
    inc edx
    jmp .l
.ld:
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    ret

section .data
nl: db 0x0a
spc: db 0x20

section .bss
ubuf: resb 390

