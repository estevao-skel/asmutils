bits 64
section .text
global _start

%define SYS_open   2
%define SYS_write  1
%define SYS_read   0
%define SYS_close  3
%define SYS_lseek  8
%define SYS_exit   60
%define O_RDWR     2
%define O_CREAT    0x40
%define SEEK_SET   0

%define EXT2_MAGIC       0xEF53
%define EXT2_BLOCK_SIZE  1024
%define EXT2_INODE_SIZE  128
%define EXT2_INODES      64
%define EXT2_BLOCKS      1440

_start:
    pop     rcx
    cmp     rcx, 2
    jl      .usage
    pop     rdi
    pop     rdi

    mov     eax, SYS_open
    mov     esi, O_RDWR|O_CREAT
    mov     edx, 0644o
    syscall
    test    rax, rax
    js      .err
    mov     r12d, eax

    mov     eax, SYS_lseek
    mov     edi, r12d
    mov     rsi, 1024
    mov     edx, SEEK_SET
    syscall

    lea     rdi, [rel sb]
    xor     eax, eax
    mov     ecx, 1024
    rep stosb

    lea     rdi, [rel sb]
    mov     dword [rdi+0],  EXT2_BLOCKS
    mov     dword [rdi+4],  EXT2_INODES
    mov     dword [rdi+8],  EXT2_BLOCKS - 5
    mov     dword [rdi+12], EXT2_INODES - 11
    mov     dword [rdi+16], 1
    mov     dword [rdi+20], 0
    mov     dword [rdi+24], 0
    mov     dword [rdi+28], EXT2_BLOCKS
    mov     dword [rdi+32], EXT2_BLOCKS
    mov     dword [rdi+36], EXT2_INODES
    mov     dword [rdi+56], 1
    mov     dword [rdi+60], 1
    mov     word  [rdi+56], EXT2_MAGIC

    mov     word [rdi+56], EXT2_MAGIC
    mov     dword [rdi+76], 0
    mov     word [rdi+80], 0
    mov     word [rdi+82], 0

    mov     eax, SYS_write
    mov     edi, r12d
    lea     rsi, [rel sb]
    mov     edx, 1024
    syscall

    mov     eax, SYS_close
    mov     edi, r12d
    syscall

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel ok_msg]
    mov     edx, ok_len
    syscall

    mov     eax, SYS_exit
    xor     edi, edi
    syscall

.usage:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel mu]
    mov     edx, mu_l
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
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
mu:     db "usage: mke2fs device",0x0a
mu_l:   equ $-mu
me:     db "mke2fs: cannot open device",0x0a
me_l:   equ $-me
ok_msg: db "ext2 superblock written",0x0a
ok_len: equ $-ok_msg

section .bss
sb: resb 1024

