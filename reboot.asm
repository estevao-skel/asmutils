bits 64
section .text
global _start
%define SYS_reboot  169
%define SYS_write     1
%define SYS_exit     60
%define LINUX_REBOOT_MAGIC1  0xfee1dead
%define LINUX_REBOOT_MAGIC2  672274793
%define LINUX_REBOOT_CMD_RESTART 0x1234567

_start:
    mov     eax, SYS_reboot
    mov     edi, LINUX_REBOOT_MAGIC1
    mov     esi, LINUX_REBOOT_MAGIC2
    mov     edx, LINUX_REBOOT_CMD_RESTART
    xor     ecx, ecx
    syscall

    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel me]
    mov     edx, me_l
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall
section .data
me:  db "reboot: operation not permitted",0x0a
me_l: equ $-me

