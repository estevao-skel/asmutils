bits 64
section .text
global _start
_start:
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rel seq]
    mov     edx, seq_len
    syscall
    mov     eax, 60
    xor     edi, edi
    syscall
section .data
seq:     db 0x1b,"[H",0x1b,"[2J",0x1b,"[3J"
seq_len: equ $ - seq

