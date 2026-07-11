bits 64
section .text
global _start

%define SYS_read   0
%define SYS_write  1
%define SYS_open   2
%define SYS_close  3
%define SYS_exit   60

_start:

    mov     eax, SYS_open
    lea     rdi, [rel mi_path]
    xor     esi, esi
    syscall
    test    rax, rax
    js      .err
    mov     r12d, eax

    mov     eax, SYS_read
    mov     edi, r12d
    lea     rsi, [rel buf]
    mov     edx, 8192
    syscall
    test    rax, rax
    jle     .err
    mov     [buf_len], eax

    mov     eax, SYS_close
    mov     edi, r12d
    syscall

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel hdr]
    mov     edx, hdr_len
    syscall

    lea     r15, [rel buf]

    lea     rdi, [rel f_total]
    call    find_field
    mov     r12, rax
    lea     rdi, [rel f_free]
    call    find_field
    mov     r13, rax
    lea     rdi, [rel f_avail]
    call    find_field
    mov     r14, rax
    lea     rdi, [rel f_buf]
    call    find_field
    mov     rbx, rax
    lea     rdi, [rel f_cached]
    call    find_field

    push    rax
    push    rbx
    push    r14
    push    r13
    push    r12

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel mem_label]
    mov     edx, 4
    syscall

    mov     ecx, 5
.ploop:
    pop     rdi
    push    rcx
    call    print_num
    pop     rcx
    dec     ecx
    jnz     .ploop

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    syscall

    mov     eax, SYS_exit
    xor     edi, edi
    syscall

.err:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel msg_e]
    mov     edx, me_len
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall

find_field:
    push    rbp
    push    rbx
    mov     rsi, r15

    mov     rbx, rdi
    xor     ecx, ecx
.klen: cmp byte [rbx+rcx], 0
    je .kl_done
    inc ecx
    jmp .klen
.kl_done:

.scan:
    cmp     byte [rsi], 0
    je      .notfound

    push    rsi
    push    rcx
    mov     rdi, rbx
    repe cmpsb
    pop     rcx
    pop     rsi
    je      .found
    inc     rsi
    jmp     .scan
.found:
    add     rsi, rcx

.skip: movzx eax, byte [rsi]
    cmp   al, '0'
    jb    .skip2
    cmp   al, '9'
    jbe   .parse
.skip2: inc rsi
    jmp   .skip
.parse:
    xor     eax, eax
.pd: movzx ecx, byte [rsi]
    sub ecx, '0'
    jb  .pd_done
    cmp ecx, 9
    ja  .pd_done
    imul rax, rax, 10
    add rax, rcx
    inc rsi
    jmp .pd
.pd_done:
    pop     rbx
    pop     rbp
    ret
.notfound:
    xor     eax, eax
    pop     rbx
    pop     rbp
    ret

print_num:
    push    rbx
    lea     rbx, [rel nbuf+19]
    mov     byte [rbx], 0
    dec     rbx
    mov     rax, rdi
    mov     ecx, 10
.nd:
    xor     edx, edx
    div     rcx
    add     dl, '0'
    mov     [rbx], dl
    dec     rbx
    test    rax, rax
    jnz     .nd

    mov     byte [rbx], ' '
    inc     rbx
    dec     rbx

    lea     rdx, [rel nbuf+19]
    sub     rdx, rbx
    mov     rsi, rbx
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    pop     rbx
    ret

section .data
mi_path:  db "/proc/meminfo",0
f_total:  db "MemTotal:",0
f_free:   db "MemFree:",0
f_avail:  db "MemAvailable:",0
f_buf:    db "Buffers:",0
f_cached: db "Cached:",0
hdr:      db "              total        free    available      buffers       cached",0x0a
hdr_len:  equ $ - hdr
mem_label:db "Mem:"
msg_e:    db "free: cannot read /proc/meminfo",0x0a
me_len:   equ $ - msg_e
nl:       db 0x0a

section .bss
buf:     resb 8192
buf_len: resd 1
nbuf:    resb 24

