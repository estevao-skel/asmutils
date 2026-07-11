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
    mov     r15, 10
    dec     rcx
    jz      .do_stdin

    mov     rsi, [rsp]
    cmp     byte [rsi], '-'
    jne     .do_file
    movzx   eax, byte [rsi+1]
    cmp     al, '0'
    jb      .do_file
    cmp     al, '9'
    ja      .do_file
    inc     rsi
    xor     eax, eax
.pn:
    movzx   edx, byte [rsi]
    sub     edx, '0'
    jb      .pnd
    cmp     edx, 9
    ja      .pnd
    imul    eax, eax, 10
    add     eax, edx
    inc     rsi
    jmp     .pn
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
    call    do_tail
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
    call    do_tail
.quit:
    mov     eax, SYS_exit
    xor     edi, edi
    syscall

do_tail:
    push    rbp
    push    rbx
    push    r13

    xor     r13d, r13d
.rd:
    mov     eax, SYS_read
    mov     edi, r12d
    lea     rsi, [rel bigbuf]
    add     rsi, r13
    mov     edx, 131072
    sub     edx, r13d
    jle     .process
    syscall
    test    rax, rax
    jle     .process
    add     r13d, eax
    jmp     .rd

.process:
    test    r13d, r13d
    jz      .dt_ret

    mov     rbp, r13
    dec     rbp

    lea     rsi, [rel bigbuf]
    cmp     byte [rsi+rbp], 0x0a
    jne     .scan
    dec     rbp

    mov     rbx, r15
.scan:
    test    rbp, rbp
    jl      .from_start
    cmp     byte [rsi+rbp], 0x0a
    jne     .scan_next
    dec     rbx
    jz      .found_nl
.scan_next:
    dec     rbp
    jmp     .scan

.found_nl:

    inc     rbp
    jmp     .write

.from_start:
    xor     rbp, rbp

.write:

    lea     rsi, [rel bigbuf]
    add     rsi, rbp
    mov     rdx, r13
    sub     rdx, rbp
    mov     eax, SYS_write
    mov     edi, 1
    syscall

.dt_ret:
    pop     r13
    pop     rbx
    pop     rbp
    ret

section .bss
bigbuf: resb 131072

