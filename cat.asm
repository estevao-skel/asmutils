bits 64
section .text
global _start

%define SYS_read   0
%define SYS_write  1
%define SYS_open   2
%define SYS_close  3
%define SYS_exit   60
%define BUFSIZE    4096

_start:
    mov     [rsp_save], rsp
    pop     rcx
    pop     r15
    dec     rcx
    jnz     .files

    mov     r12d, 0
    call    .dump
    jmp     .exit

.files:
    pop     rsi
    push    rcx
    push    rsi
    mov     eax, SYS_open
    mov     rdi, rsi
    xor     esi, esi
    xor     edx, edx
    syscall
    test    rax, rax
    js      .next
    mov     r12d, eax
    call    .dump
    mov     eax, SYS_close
    mov     edi, r12d
    syscall
.next:
    pop     rsi
    pop     rcx
    dec     rcx
    jnz     .files

.exit:
    mov     eax, SYS_exit
    xor     edi, edi
    syscall

.dump:
    lea     rsi, [rel buf]
    mov     edx, BUFSIZE
.read:
    mov     eax, SYS_read
    mov     edi, r12d
    syscall
    test    rax, rax
    jle     .done
    mov     rdx, rax
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel buf]
    syscall
    jmp     .read
.done:
    ret

section .bss
rsp_save: resq 1
buf:      resb 4096

