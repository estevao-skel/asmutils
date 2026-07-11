bits 64
section .text
global _start
_start:
    pop     rcx
    pop     rdi
    dec     rcx
    jz      .newline
.loop:
    pop     rsi
    push    rcx
    mov     rdi, rsi
    xor     ecx, ecx
.sl: cmp byte [rdi+rcx],0
    je      .gl
    inc     ecx
    jmp     .sl
.gl:mov     edx, ecx
    mov     eax, 1
    mov     edi, 1
    syscall
    pop     rcx
    dec     rcx
    jz      .newline
    push    rcx
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rel spc]
    mov     edx, 1
    syscall
    pop     rcx
    jmp     .loop
.newline:
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    syscall
    mov     eax, 60
    xor     edi, edi
    syscall
section .data
nl: db 0x0a
spc: db 0x20

