bits 64
section .text
global _start

%define SYS_read    0
%define SYS_write   1
%define SYS_open    2
%define SYS_close   3
%define SYS_getuid  102
%define SYS_getgid  104
%define SYS_exit    60

_start:
    mov     eax, SYS_getuid
    syscall
    mov     r12d, eax

    mov     eax, SYS_getgid
    syscall
    mov     r13d, eax

    mov     eax, SYS_open
    lea     rdi, [rel pw_path]
    xor     esi, esi
    syscall
    test    rax, rax
    js      .no_pw
    mov     r14d, eax
    mov     eax, SYS_read
    mov     edi, r14d
    lea     rsi, [rel pwbuf]
    mov     edx, 32767
    syscall
    test    rax, rax
    jle     .no_pw
    mov     [pwbuf_len], eax
    mov     eax, SYS_close
    mov     edi, r14d
    syscall

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel s_uid]
    mov     edx, 4
    syscall
    mov     edi, r12d
    call    pnum
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel lp]
    mov     edx, 1
    syscall

    mov     edi, r12d
    mov     esi, 2
    lea     rdx, [rel pwbuf]
    mov     ecx, [pwbuf_len]
    call    lookup_field0
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel rp_gid]
    mov     edx, 6
    syscall

    mov     edi, r13d
    call    pnum
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel lp]
    mov     edx, 1
    syscall

    mov     edi, r13d
    mov     esi, 2
    lea     rdx, [rel pwbuf]
    mov     ecx, [pwbuf_len]
    call    lookup_field0
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel rp_nl]
    mov     edx, 2
    syscall

    mov     eax, SYS_exit
    xor     edi, edi
    syscall

.no_pw:

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel s_uid]
    mov     edx, 4
    syscall
    mov     edi, r12d
    call    pnum
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel rp_gid]
    mov     edx, 6
    syscall
    mov     edi, r13d
    call    pnum
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel rp_nl]
    mov     edx, 2
    syscall
    mov     eax, SYS_exit
    xor     edi, edi
    syscall

lookup_field0:
    push    rbx
    push    rbp
    push    r8
    push    r9
    mov     r8, rdx
    mov     r9d, ecx
    xor     rbx, rbx
.line:
    cmp     rbx, r9
    jge     .notfound

    mov     rbp, rbx

    mov     ecx, esi
.skip_fields:
    test    ecx, ecx
    jz      .at_field
.sf_next:
    cmp     rbx, r9
    jge     .notfound
    movzx   eax, byte [r8+rbx]
    inc     rbx
    cmp     al, 0x0a
    je      .next_line_outer
    cmp     al, ':'
    jne     .sf_next
    dec     ecx
    jnz     .sf_next

.at_field:

    xor     eax, eax
.pf:
    cmp     rbx, r9
    jge     .check
    movzx   edx, byte [r8+rbx]
    sub     edx, '0'
    jb      .check
    cmp     edx, 9
    ja      .check
    imul    eax, eax, 10
    add     eax, edx
    inc     rbx
    jmp     .pf
.check:
    cmp     eax, edi
    jne     .next_line

    lea     rsi, [r8+rbp]
    xor     edx, edx
.f0len:
    cmp     byte [rsi+rdx], ':'
    je      .f0done
    cmp     byte [rsi+rdx], 0x0a
    je      .f0done
    cmp     byte [rsi+rdx], 0
    je      .f0done
    inc     edx
    jmp     .f0len
.f0done:
    pop     r9
    pop     r8
    pop     rbp
    pop     rbx
    ret

.next_line:
.next_line_outer:

.adv:
    cmp     rbx, r9
    jge     .notfound
    movzx   eax, byte [r8+rbx]
    inc     rbx
    cmp     al, 0x0a
    jne     .adv
    jmp     .line

.notfound:
    lea     rsi, [rel qmark]
    mov     edx, 1
    pop     r9
    pop     r8
    pop     rbp
    pop     rbx
    ret

pnum:
    push    rbx
    lea     rbx, [rel nbuf+18]
    mov     eax, edi
    mov     ecx, 10
.nd:
    xor     edx, edx
    div     ecx
    add     dl, '0'
    dec     rbx
    mov     [rbx], dl
    test    eax, eax
    jnz     .nd

    lea     rdx, [rel nbuf+18]
    sub     rdx, rbx
    mov     rsi, rbx
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    pop     rbx
    ret

section .data
pw_path: db "/etc/passwd",0
s_uid:   db "uid="
lp:      db "("
rp_gid:  db ") gid="
rp_nl:   db ")",0x0a
qmark:   db "?"

section .bss
pwbuf:     resb 32768
pwbuf_len: resd 1
nbuf:      resb 24

