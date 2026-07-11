bits 64
section .text
global _start
%define SYS_geteuid  107
%define SYS_open       2
%define SYS_read       0
%define SYS_close      3
%define SYS_write      1
%define SYS_exit      60

_start:
    mov     eax, SYS_geteuid
    syscall
    mov     r12d, eax

    mov     eax, SYS_open
    lea     rdi, [rel pw_path]
    xor     esi, esi
    syscall
    test    rax, rax
    js      .err
    mov     r13d, eax

    mov     eax, SYS_read
    mov     edi, r13d
    lea     rsi, [rel buf]
    mov     edx, 32767
    syscall
    test    rax, rax
    jle     .err
    mov     [buf_len], eax

    mov     eax, SYS_close
    mov     edi, r13d
    syscall

    lea     r14, [rel buf]
    mov     ecx, [buf_len]
.line:

    mov     rbx, r14

    xor     edx, edx
.skip_colon:
    cmp     ecx, 0
    jle     .err
    movzx   eax, byte [r14]
    inc     r14
    dec     ecx
    cmp     al, 0x0a
    je      .next_line
    cmp     al, ':'
    jne     .skip_colon
    inc     edx
    cmp     edx, 2
    jl      .skip_colon

    xor     eax, eax
.puid:
    movzx   esi, byte [r14]
    sub     esi, '0'
    jb      .got_uid
    cmp     esi, 9
    ja      .got_uid
    imul    eax, eax, 10
    add     eax, esi
    inc     r14
    dec     ecx
    jmp     .puid
.got_uid:
    cmp     eax, r12d
    je      .found
.next_line:

    cmp     ecx, 0
    jle     .err
    movzx   eax, byte [r14]
    inc     r14
    dec     ecx
    cmp     al, 0x0a
    jne     .next_line
    jmp     .line

.found:

    mov     rsi, rbx
    xor     edx, edx
.nl2: cmp byte [rsi+rdx], ':'
    je .nl2d
    cmp byte [rsi+rdx], 0x0a
    je .nl2d
    cmp byte [rsi+rdx], 0
    je .nl2d
    inc edx
    jmp .nl2
.nl2d:
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    syscall
    mov     eax, SYS_exit
    xor     edi, edi
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
pw_path: db "/etc/passwd",0
nl:      db 0x0a
me:      db "whoami: cannot determine username",0x0a
me_l:    equ $-me

section .bss
buf:     resb 32768
buf_len: resd 1

