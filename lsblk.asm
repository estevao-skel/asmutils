bits 64
section .text
global _start
%define SYS_open      2
%define SYS_read      0
%define SYS_close     3
%define SYS_write     1
%define SYS_getdents64 217
%define SYS_exit      60
%define O_RDONLY      0
%define O_DIRECTORY   0x10000
%define D_RECLEN      16
%define D_TYPE        18
%define D_NAME        19
%define DT_LNK        10
%define DT_DIR         4

_start:
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel hdr]
    mov     edx, hdr_l
    syscall

    mov     eax, SYS_open
    lea     rdi, [rel sb_path]
    mov     esi, O_RDONLY|O_DIRECTORY
    xor     edx, edx
    syscall
    test    rax, rax
    js      .err
    mov     r12d, eax

.rd:
    mov     eax, SYS_getdents64
    mov     edi, r12d
    lea     rsi, [rel dbuf]
    mov     edx, 4096
    syscall
    test    rax, rax
    jle     .done
    mov     rbx, rax
    xor     ecx, ecx

.each:
    cmp     rcx, rbx
    jge     .rd
    lea     rdi, [rel dbuf+rcx]
    movzx   eax, byte [rdi+D_TYPE]
    cmp     al, DT_LNK
    je      .show
    cmp     al, DT_DIR
    jne     .next
    movzx   eax, byte [rdi+D_NAME]
    cmp     al, '.'
    je      .next
.show:

    lea     rsi, [rdi+D_NAME]
    push    rcx
    push    rdi
    xor     edx, edx
.nl: cmp byte [rsi+rdx], 0
    je .nld
    inc edx
    jmp .nl
.nld:
    push    rdx
    push    rsi
    mov     eax, SYS_write
    mov     edi, 1
    syscall

    lea     rdi, [rel path_buf]
    lea     rsi, [rel sb_prefix]
    mov     ecx, sb_prefix_l
    rep movsb
    pop     rsi
    push    rsi
    pop     rdx
    push    rdx
.cp: movzx eax, byte [rsi]
    test al, al
    jz .cpd
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .cp
.cpd:
    lea     rsi, [rel size_suf]
    mov     ecx, 6
    rep movsb
    mov     byte [rdi], 0

    mov     eax, SYS_open
    lea     rdi, [rel path_buf]
    xor     esi, esi
    syscall
    test    rax, rax
    js      .no_size
    mov     r13d, eax
    mov     eax, SYS_read
    mov     edi, r13d
    lea     rsi, [rel sz_buf]
    mov     edx, 32
    syscall
    test    rax, rax
    jle     .no_size

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel spc]
    mov     edx, 1
    syscall

    lea     rsi, [rel sz_buf]
    xor     edx, edx
.szl: cmp byte [rsi+rdx], 0x0a
    je .szld
    cmp byte [rsi+rdx], 0
    je .szld
    inc edx
    jmp .szl
.szld:
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    mov     eax, SYS_close
    mov     edi, r13d
    syscall
    jmp     .after_size
.no_size:
.after_size:
    pop     rdx
    pop     rsi
    pop     rdi
    pop     rcx
    mov     r14, rcx
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    syscall
    mov     rcx, r14

.next:
    movzx   eax, word [rel dbuf+rcx+D_RECLEN]
    add     rcx, rax
    jmp     .each

.done:
    mov     eax, SYS_close
    mov     edi, r12d
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
sb_path:   db "/sys/block",0
sb_prefix: db "/sys/block/"
sb_prefix_l: equ $-sb_prefix
size_suf:  db "/size",0
hdr:       db "NAME              SIZE(512b)",0x0a
hdr_l:     equ $-hdr
nl:        db 0x0a
spc:       db 0x20
me:        db "lsblk: cannot read /sys/block",0x0a
me_l:      equ $-me

section .bss
dbuf:     resb 4096
path_buf: resb 64
sz_buf:   resb 32

