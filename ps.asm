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
%define DT_DIR        4

_start:

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel hdr]
    mov     edx, hdr_l
    syscall

    mov     eax, SYS_open
    lea     rdi, [rel proc_path]
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

    movzx   eax, byte [rdi+D_TYPE]
    cmp     al, DT_DIR
    jne     .next

    lea     rsi, [rdi+D_NAME]
    movzx   eax, byte [rsi]
    cmp     al, '1'
    jb      .next
    cmp     al, '9'
    ja      .next

    push    rcx
    push    rdi

    lea     rdi, [rel path_buf]
    lea     rsi, [rel proc_stat_pre]

    mov     ecx, 6
    rep movsb
    pop     rsi
    push    rsi
    lea     rsi, [rsi+D_NAME]

.cp: movzx eax, byte [rsi]
    test    al, al
    jz .cp_done
    mov     [rdi], al
    inc     rsi
    inc     rdi
    jmp     .cp
.cp_done:

    lea     rsi, [rel stat_suf]
    mov     ecx, 5
    rep movsb
    mov     byte [rdi], 0

    mov     eax, SYS_open
    lea     rdi, [rel path_buf]
    xor     esi, esi
    syscall
    test    rax, rax
    js      .pop_next
    mov     r13d, eax

    mov     eax, SYS_read
    mov     edi, r13d
    lea     rsi, [rel stat_buf]
    mov     edx, 512
    syscall
    test    rax, rax
    jle     .pop_close

    mov     eax, SYS_close
    mov     edi, r13d
    syscall

    lea     rsi, [rel stat_buf]

    xor     edx, edx
.ppid: cmp byte [rsi+rdx], ' '
    je .ppid_d
    inc edx
    jmp .ppid
.ppid_d:
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel spc]
    mov     edx, 1
    syscall

    lea     rsi, [rel stat_buf]
    xor     ecx, ecx
.find_lp: cmp byte [rsi+rcx], '('
    je .found_lp
    inc ecx
    jmp .find_lp
.found_lp:
    inc     rcx
    lea     rsi, [rel stat_buf+rcx]
    xor     edx, edx
.find_rp: cmp byte [rsi+rdx], ')'
    je .found_rp
    inc edx
    jmp .find_rp
.found_rp:
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    syscall

    jmp     .pop_next
.pop_close:
    mov     eax, SYS_close
    mov     edi, r13d
    syscall
.pop_next:
    pop     rdi
    pop     rcx
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
    mov     eax, SYS_exit
    mov     edi, 1
    syscall

section .data
proc_path:    db "/proc",0
proc_stat_pre: db "/proc/",0
stat_suf:     db "/stat",0
hdr:          db "PID  COMM",0x0a
hdr_l:        equ $-hdr
nl:           db 0x0a
spc:           db 0x20

section .bss
dbuf:     resb 8192
path_buf: resb 64
stat_buf: resb 512

