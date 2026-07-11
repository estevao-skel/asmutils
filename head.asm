bits 64
section .text
global _start
%define SYS_read  0
%define SYS_write 1
%define SYS_open  2
%define SYS_close 3
%define SYS_exit  60

_start:
    pop     rcx
    pop     rdi
    mov     r15, 10
    dec     rcx
    jz      .do_stdin

    mov     rsi, [rsp]
    cmp     byte [rsi], '-'
    jne     .do_file
    inc     rsi
    xor     eax, eax
.pn: movzx edx, byte [rsi]
    sub edx, '0'
    jb .pnd
    cmp edx, 9
    ja .pnd
    imul eax, eax, 10
    add eax, edx
    inc rsi
    jmp .pn
.pnd:
    mov     r15, rax
    pop     rdi
    dec     rcx
    jz      .do_stdin

.do_file:
    pop     rsi
    push    rcx
    mov     eax, SYS_open
    mov     rdi, rsi
    xor     esi, esi
    syscall
    test    rax, rax
    js      .fskip
    mov     r12d, eax
    call    dohead
    mov     eax, SYS_close
    mov     edi, r12d
    syscall
.fskip:
    pop     rcx
    dec     rcx
    jnz     .do_file
    jmp     .quit

.do_stdin:
    xor     r12d, r12d
    call    dohead
.quit:
    mov     eax, SYS_exit
    xor     edi, edi
    syscall

dohead:
    push    rbx
    push    r13
    mov     r13, r15
.rd:
    test    r13, r13
    jz      .dh_ret
    mov     eax, SYS_read
    mov     edi, r12d
    lea     rsi, [rel buf]
    mov     edx, 4096
    syscall
    test    rax, rax
    jle     .dh_ret
    mov     rbx, rax
    xor     ecx, ecx
    xor     edx, edx
.scan:
    cmp     rcx, rbx
    jge     .write_rest
    movzx   eax, byte [rel buf+rcx]
    inc     rcx
    cmp     al, 0x0a
    jne     .scan
    dec     r13
    jnz     .scan

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel buf]
    mov     rdx, rcx
    syscall
    jmp     .dh_ret
.write_rest:

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel buf]
    mov     rdx, rbx
    syscall
    jmp     .rd
.dh_ret:
    pop     r13
    pop     rbx
    ret

section .bss
buf: resb 4096

