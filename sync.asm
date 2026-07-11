bits 64
section .text
global _start
%define SYS_sync  162
%define SYS_exit   60
_start:
    mov     eax, SYS_sync
    syscall
    mov     eax, SYS_exit
    xor     edi, edi
    syscall

