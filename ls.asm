bits 64
section .text
global _start

%define SYS_write      1
%define SYS_open       2
%define SYS_close      3
%define SYS_stat       4
%define SYS_getdents64 217
%define SYS_exit       60
%define O_RDONLY       0
%define O_DIRECTORY    0x10000

%define D_INO   0
%define D_OFF   8
%define D_RECLEN 16
%define D_TYPE  18
%define D_NAME  19

%define DT_DIR  4
%define DT_LNK  10

_start:
    pop     rcx
    pop     rdi
    dec     rcx
    jz      .do_dot

    pop     rsi
    jmp     .do_path

.do_dot:
    lea     rsi, [rel dot]
.do_path:
    mov     eax, SYS_open
    mov     rdi, rsi
    mov     esi, O_RDONLY|O_DIRECTORY
    xor     edx, edx
    syscall
    test    rax, rax
    js      .err
    mov     r12d, eax

.readdir:
    mov     eax, SYS_getdents64
    mov     edi, r12d
    lea     rsi, [rel dbuf]
    mov     edx, 8192
    syscall
    test    rax, rax
    jle     .done
    mov     rbx, rax
    xor     ecx, ecx

.each:
    cmp     rcx, rbx
    jge     .readdir
    lea     rdi, [rel dbuf+rcx]

    movzx   eax, byte [rdi+D_NAME]
    cmp     al, '.'
    je      .next_entry

    lea     rsi, [rdi+D_NAME]
    xor     edx, edx
.nl: cmp byte [rsi+rdx], 0
    je .nld
    inc edx
    jmp .nl
.nld:

    movzx   eax, byte [rdi+D_TYPE]
    cmp     al, DT_DIR
    jne     .not_dir
    mov     byte [rsi+rdx], '/'
    inc     edx
.not_dir:
    mov     byte [rsi+rdx], 0x0a
    inc     edx
    mov     r13, rcx
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    mov     rcx, r13

.next_entry:
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
dot:  db ".",0
me:   db "ls: error",0x0a
me_l: equ $-me

section .bss
dbuf: resb 8192

