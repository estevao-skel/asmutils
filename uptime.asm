bits 64
section .text
global _start
%define SYS_open   2
%define SYS_read   0
%define SYS_close  3
%define SYS_write  1
%define SYS_exit   60

_start:
    mov     eax, SYS_open
    lea     rdi, [rel up_path]
    xor     esi, esi
    syscall
    test    rax, rax
    js      .err
    mov     r12d, eax

    mov     eax, SYS_read
    mov     edi, r12d
    lea     rsi, [rel buf]
    mov     edx, 256
    syscall
    test    rax, rax
    jle     .err

    mov     eax, SYS_close
    mov     edi, r12d
    syscall

    lea     rsi, [rel buf]
    xor     eax, eax
.p:
    movzx   ecx, byte [rsi]
    cmp     cl, '0'
    jb      .pd
    cmp     cl, '9'
    ja      .pd
    imul    eax, eax, 10
    movzx   ecx, byte [rsi]
    sub     ecx, '0'
    add     eax, ecx
    inc     rsi
    jmp     .p
.pd:

    mov     r12d, eax
    xor     edx, edx
    mov     ecx, 86400
    div     ecx
    mov     r13d, eax
    mov     r14d, edx

    mov     eax, r14d
    xor     edx, edx
    mov     ecx, 3600
    div     ecx
    mov     r15d, eax
    mov     ebx, edx

    mov     eax, ebx
    xor     edx, edx
    mov     ecx, 60
    div     ecx

    push    rdx
    push    rax
    push    r15
    push    r13

    lea     rsi, [rel up_msg]
    mov     eax, SYS_write
    mov     edi, 1
    mov     edx, up_len
    syscall

    pop     rdi
    call    punum
    lea     rsi, [rel d_str]
    mov     eax, SYS_write
    mov     edi, 1
    mov     edx, 2
    syscall
    pop     rdi
    call    punum
    lea     rsi, [rel h_str]
    mov     eax, SYS_write
    mov     edi, 1
    mov     edx, 2
    syscall
    pop     rdi
    call    punum
    lea     rsi, [rel m_str]
    mov     eax, SYS_write
    mov     edi, 1
    mov     edx, 2
    syscall
    pop     rdi
    call    punum
    lea     rsi, [rel s_str]
    mov     eax, SYS_write
    mov     edi, 1
    mov     edx, 2
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

punum:
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
up_path: db "/proc/uptime",0
up_msg:  db "up "
up_len:  equ $-up_msg
d_str:   db "d "
h_str:   db "h "
m_str:   db "m "
s_str:   db "s",0x0a
me:      db "uptime: error",0x0a
me_l:    equ $-me

section .bss
buf:  resb 256
nbuf: resb 24

