bits 64
section .text
global _start

%define SYS_read    0
%define SYS_write   1
%define SYS_open    2
%define SYS_close   3
%define SYS_lseek   8
%define SYS_exit    60
%define O_RDWR      2
%define SEEK_SET    0

_start:
    pop     rcx
    cmp     ecx, 4
    jl      .usage
    cmp     ecx, 5
    jg      .usage

    pop     rdi

    pop     r12

    pop     rsi
    call    parse_uint64
    mov     r13, rax

    pop     rsi
    call    parse_uint64
    mov     r14, rax

    mov     byte [ptype], 0x83
    cmp     ecx, 5
    jl      .no_type
    pop     rsi
    call    parse_hex_byte
    mov     [ptype], al
.no_type:

    mov     eax, SYS_open
    mov     rdi, r12
    mov     esi, O_RDWR
    syscall
    test    rax, rax
    js      .err_open
    mov     r15d, eax

    mov     dword [pentry], 0xFFFFFE00
    mov     al, [ptype]
    mov     [pentry+4], al
    mov     dword [pentry+5], 0xFFFFFE
    mov     [pentry+8], r13d
    mov     [pentry+12], r14d

    mov     eax, SYS_lseek
    mov     edi, r15d
    mov     rsi, 0x1BE
    xor     edx, edx
    syscall
    test    rax, rax
    js      .err_io

    mov     eax, SYS_write
    mov     edi, r15d
    lea     rsi, [rel pentry]
    mov     edx, 16
    syscall
    cmp     rax, 16
    jne     .err_io

    mov     eax, SYS_lseek
    mov     edi, r15d
    mov     rsi, 0x1FE
    xor     edx, edx
    syscall
    test    rax, rax
    js      .err_io

    mov     eax, SYS_write
    mov     edi, r15d
    lea     rsi, [rel sig55aa]
    mov     edx, 2
    syscall
    cmp     rax, 2
    jne     .err_io

    mov     eax, SYS_close
    mov     edi, r15d
    syscall

    xor     edi, edi
    mov     eax, SYS_exit
    syscall

.err_open:
    lea     rsi, [rel msg_eopen]
    mov     edx, eo_len
    jmp     .die

.err_io:
    cmp     r15d, 0
    je      .skip_close
    mov     eax, SYS_close
    mov     edi, r15d
    syscall
.skip_close:
    lea     rsi, [rel msg_eio]
    mov     edx, ei_len
    jmp     .die

.usage:
    lea     rsi, [rel msg_usage]
    mov     edx, mu_len

.die:
    mov     edi, 2
    mov     eax, SYS_write
    syscall
    mov     edi, 1
    mov     eax, SYS_exit
    syscall

parse_uint64:
    xor     eax, eax
.lp:
    movzx   ecx, byte [rsi]
    sub     ecx, '0'
    jb      .done
    cmp     ecx, 9
    ja      .done
    imul    rax, rax, 10
    add     rax, rcx
    inc     rsi
    jmp     .lp
.done:
    ret

parse_hex_byte:
    cmp     byte [rsi], '0'
    jne     .go
    cmp     byte [rsi+1], 'x'
    je      .skip0x
    cmp     byte [rsi+1], 'X'
    jne     .go
.skip0x:
    add     rsi, 2
.go:
    xor     eax, eax
.hlp:
    movzx   ecx, byte [rsi]
    test    cl, cl
    jz      .hdone
    cmp     cl, '0'
    jb      .hdone
    cmp     cl, '9'
    jbe     .isdigit
    or      cl, 0x20
    cmp     cl, 'a'
    jb      .hdone
    cmp     cl, 'f'
    ja      .hdone
    sub     cl, 'a' - 10
    jmp     .haccum
.isdigit:
    sub     cl, '0'
.haccum:
    shl     al, 4
    or      al, cl
    inc     rsi
    jmp     .hlp
.hdone:
    ret

section .data
msg_usage: db "uso: part <device> <start_lba> <sectors> [type_hex]", 0x0a
mu_len:    equ $ - msg_usage
msg_eopen: db "part: erro ao abrir o device", 0x0a
eo_len:    equ $ - msg_eopen
msg_eio:   db "part: erro de leitura/escrita no device", 0x0a
ei_len:    equ $ - msg_eio
sig55aa:   db 0x55, 0xAA

section .bss
ptype:  resb 1
pentry: resb 16

