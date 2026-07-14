bits 64
section .text
global _start

%define SYS_read    0
%define SYS_write   1
%define SYS_open    2
%define SYS_close   3
%define SYS_lseek   8
%define SYS_sync    162
%define SYS_exit    60
%define O_RDONLY    0
%define O_RDWR      2
%define SEEK_SET    0
%define STDIN       0
%define STDOUT      1
%define STDERR      2

_start:
    pop     rcx
    cmp     ecx, 3
    jl      .usage
    cmp     ecx, 4
    jg      .usage
    pop     rdi
    pop     r12
    pop     r13

    mov     byte [has_override], 0
    cmp     ecx, 4
    jl      .no_override
    pop     rsi
    movzx   eax, byte [rsi]
    mov     [override_letter], al
    mov     byte [has_override], 1
.no_override:

    mov     rdi, r12
    mov     rsi, r13
    call    strs_equal
    test    eax, eax
    jnz     .same_dev

    call    do_warn_and_confirm
    test    eax, eax
    jz      .cancelled

    mov     eax, SYS_open
    mov     rdi, r12
    xor     esi, esi
    syscall
    test    rax, rax
    js      .eopen_src
    mov     r14d, eax

    mov     edi, r14d
    lea     rsi, [rel buf]
    mov     rdx, 512
    call    read_exact
    test    eax, eax
    jnz     .eio

    cmp     byte [buf+0x1FE], 0x55
    jne     .badmbr
    cmp     byte [buf+0x1FF], 0xAA
    jne     .badmbr

    movzx   eax, byte [buf+0x1BE+4]
    test    eax, eax
    jz      .badpart
    mov     eax, [buf+0x1BE+8]
    mov     r15, rax
    mov     eax, [buf+0x1BE+12]
    test    eax, eax
    jz      .badpart
    add     r15, rax

    mov     eax, SYS_open
    mov     rdi, r13
    mov     esi, O_RDWR
    syscall
    test    rax, rax
    js      .eopen_dst
    mov     ebx, eax

    mov     eax, SYS_lseek
    mov     edi, r14d
    xor     esi, esi
    xor     edx, edx
    syscall
    test    rax, rax
    js      .eio

.copy_lp:
    test    r15, r15
    jz      .copy_done
    mov     r8, r15
    cmp     r8, 128
    jbe     .chunk_ok
    mov     r8, 128
.chunk_ok:
    mov     edi, r14d
    lea     rsi, [rel buf]
    mov     rdx, r8
    shl     rdx, 9
    call    read_exact
    test    eax, eax
    jnz     .eio

    mov     edi, ebx
    lea     rsi, [rel buf]
    mov     rdx, r8
    shl     rdx, 9
    call    write_exact
    test    eax, eax
    jnz     .eio

    sub     r15, r8
    jmp     .copy_lp
.copy_done:

    mov     eax, SYS_close
    mov     edi, r14d
    syscall

    call    try_patch_cmdline

    mov     eax, SYS_sync
    syscall

    mov     eax, SYS_close
    mov     edi, ebx
    syscall

    lea     rsi, [rel msg_ok]
    mov     edx, mok_len
    mov     edi, STDOUT
    call    wr

    xor     edi, edi
    mov     eax, SYS_exit
    syscall

.same_dev:
    lea     rsi, [rel msg_same]
    mov     edx, msame_len
    jmp     .die

.cancelled:
    lea     rsi, [rel msg_cancel]
    mov     edx, mcanc_len
    jmp     .die

.badmbr:
    lea     rsi, [rel msg_badmbr]
    mov     edx, mbmbr_len
    jmp     .die

.badpart:
    lea     rsi, [rel msg_badpart]
    mov     edx, mbpart_len
    jmp     .die

.eopen_src:
    lea     rsi, [rel msg_eopen_src]
    mov     edx, meos_len
    jmp     .die

.eopen_dst:
    mov     eax, SYS_close
    mov     edi, r14d
    syscall
    lea     rsi, [rel msg_eopen_dst]
    mov     edx, meod_len
    jmp     .die

.eio:
    lea     rsi, [rel msg_eio]
    mov     edx, meio_len
    jmp     .die

.usage:
    lea     rsi, [rel msg_usage]
    mov     edx, musg_len

.die:
    mov     edi, STDERR
    call    wr
    mov     edi, 1
    mov     eax, SYS_exit
    syscall

do_warn_and_confirm:
    lea     rsi, [rel msg_warn1]
    mov     edx, mw1_len
    mov     edi, STDOUT
    call    wr

    mov     rsi, r13
    call    strlen0
    mov     edi, STDOUT
    call    wr

    lea     rsi, [rel msg_warn2]
    mov     edx, mw2_len
    mov     edi, STDOUT
    call    wr

    mov     eax, SYS_read
    xor     edi, edi
    lea     rsi, [rel confirm_buf]
    mov     edx, 8
    syscall
    cmp     rax, 4
    jl      .no
    cmp     byte [confirm_buf], 's'
    jne     .no
    cmp     byte [confirm_buf+1], 'i'
    jne     .no
    cmp     byte [confirm_buf+2], 'm'
    jne     .no
    cmp     byte [confirm_buf+3], 0x0A
    jne     .no
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

try_patch_cmdline:
    cmp     byte [has_override], 0
    jne     .tp_override

    mov     rsi, r13
    call    strlen0
    test    edx, edx
    jz      .tp_done
    mov     rax, r13
    add     rax, rdx
    dec     rax
    movzx   ecx, byte [rax]
    cmp     cl, 'a'
    jb      .tp_done
    cmp     cl, 'z'
    ja      .tp_done
    mov     [dstletter], cl
    jmp     .tp_have_letter

.tp_override:
    movzx   eax, byte [override_letter]
    mov     [dstletter], al

.tp_have_letter:
    mov     eax, SYS_lseek
    mov     edi, ebx
    mov     rsi, 512
    xor     edx, edx
    syscall
    test    rax, rax
    js      .tp_done

    mov     edi, ebx
    lea     rsi, [rel buf]
    mov     rdx, 8192
    call    read_exact
    test    eax, eax
    jnz     .tp_done

    lea     rdi, [rel buf]
    mov     ecx, 8192 - 16
    lea     rsi, [rel magic]
.tp_scan:
    test    ecx, ecx
    jz      .tp_done
    mov     al, [rdi]
    cmp     al, [rsi]
    jne     .tp_next
    push    rcx
    push    rdi
    push    rsi
    mov     ecx, 16
.tp_cmp:
    mov     al, [rsi]
    cmp     al, [rdi]
    jne     .tp_cmpfail
    inc     rsi
    inc     rdi
    dec     ecx
    jnz     .tp_cmp
    pop     rsi
    pop     rdi
    pop     rcx
    add     rdi, 16
    jmp     .tp_found
.tp_cmpfail:
    pop     rsi
    pop     rdi
    pop     rcx
.tp_next:
    inc     rdi
    dec     ecx
    jmp     .tp_scan

.tp_found:

    mov     r9, rdi
    mov     ecx, 128 - 7
    lea     rsi, [rel devsd]
.tp_scan2:
    test    ecx, ecx
    jz      .tp_done
    mov     al, [r9]
    cmp     al, [rsi]
    jne     .tp_next2
    push    rcx
    push    r9
    push    rsi
    mov     ecx, 7
.tp_cmp2:
    mov     al, [rsi]
    cmp     al, [r9]
    jne     .tp_cmpfail2
    inc     rsi
    inc     r9
    dec     ecx
    jnz     .tp_cmp2
    pop     rsi
    pop     r9
    pop     rcx
    add     r9, 7
    movzx   eax, byte [dstletter]
    mov     [r9], al
    jmp     .tp_write
.tp_cmpfail2:
    pop     rsi
    pop     r9
    pop     rcx
.tp_next2:
    inc     r9
    dec     ecx
    jmp     .tp_scan2

.tp_write:
    mov     eax, SYS_lseek
    mov     edi, ebx
    mov     rsi, 512
    xor     edx, edx
    syscall
    test    rax, rax
    js      .tp_done

    mov     edi, ebx
    lea     rsi, [rel buf]
    mov     rdx, 8192
    call    write_exact

    lea     rsi, [rel msg_patched]
    mov     edx, mpat_len
    mov     edi, STDOUT
    call    wr
.tp_done:
    ret

read_exact:
.re_lp:
    test    rdx, rdx
    jz      .re_ok
    mov     eax, SYS_read
    syscall
    test    rax, rax
    jle     .re_err
    add     rsi, rax
    sub     rdx, rax
    jmp     .re_lp
.re_ok:
    xor     eax, eax
    ret
.re_err:
    mov     eax, 1
    ret

write_exact:
.we_lp:
    test    rdx, rdx
    jz      .we_ok
    mov     eax, SYS_write
    syscall
    test    rax, rax
    jle     .we_err
    add     rsi, rax
    sub     rdx, rax
    jmp     .we_lp
.we_ok:
    xor     eax, eax
    ret
.we_err:
    mov     eax, 1
    ret

wr:
    mov     eax, SYS_write
    syscall
    ret

strlen0:
    xor     edx, edx
.sl:
    cmp     byte [rsi+rdx], 0
    je      .sld
    inc     edx
    jmp     .sl
.sld:
    ret

strs_equal:
.se_lp:
    mov     cl, [rdi]
    cmp     cl, [rsi]
    jne     .se_ne
    test    cl, cl
    jz      .se_eq
    inc     rdi
    inc     rsi
    jmp     .se_lp
.se_eq:
    mov     eax, 1
    ret
.se_ne:
    xor     eax, eax
    ret

section .data
msg_usage:     db "uso install <src> <dst> [letra]", 0x0a
musg_len:      equ $ - msg_usage
msg_warn1:     db "aviso apaga tudo em ", 0
mw1_len:       equ $ - msg_warn1 - 1
msg_warn2:     db " sim p/ confirmar ", 0
mw2_len:       equ $ - msg_warn2 - 1
msg_cancel:    db 0x0a, "cancelado", 0x0a
mcanc_len:     equ $ - msg_cancel
msg_same:      db "install src == dst, abortado", 0x0a
msame_len:     equ $ - msg_same
msg_badmbr:    db "install mbr invalido", 0x0a
mbmbr_len:     equ $ - msg_badmbr
msg_badpart:   db "install part1 vazia", 0x0a
mbpart_len:    equ $ - msg_badpart
msg_eopen_src: db "install erro abrir src", 0x0a
meos_len:      equ $ - msg_eopen_src
msg_eopen_dst: db "install erro abrir dst", 0x0a
meod_len:      equ $ - msg_eopen_dst
msg_eio:       db "install erro io", 0x0a
meio_len:      equ $ - msg_eio
msg_ok:        db "install ok", 0x0a
mok_len:       equ $ - msg_ok
msg_patched:   db "cmdline ajustada", 0x0a
mpat_len:      equ $ - msg_patched
magic:         db "GATINIT_CMDLINE!"
devsd:         db "/dev/sd"

section .bss
confirm_buf:     resb 8
dstletter:       resb 1
override_letter: resb 1
has_override:    resb 1
buf:             resb 65536
