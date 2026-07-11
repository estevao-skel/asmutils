bits 64
section .text
global _start

%define SYS_read   0
%define SYS_write  1
%define SYS_open   2
%define SYS_close  3
%define SYS_exit   60
%define O_RDONLY   0
%define O_WRONLY   1
%define O_CREAT    0x40
%define O_TRUNC    0x200

_start:
    pop     rcx
    mov     r15d, ecx
    pop     rdi

    xor     r12d, r12d
    mov     r13d, 1
    mov     r14, 512
    mov     rbx, -1

    mov     ebp, ecx

    dec     ebp
    jz      .run
.args:
    pop     rsi

    mov     eax, [rsi]
    and     eax, 0xFFFFFF
    cmp     eax, 'if='
    je      .do_if

    cmp     eax, 'of='
    je      .do_of

    lea     rdi, [rel bs_str]
    call    prefix3
    jz      .do_bs

    lea     rdi, [rel ct_str]
    call    prefix5
    jz      .do_count
    jmp     .next_arg

.do_if:
    add     rsi, 3
    mov     eax, SYS_open
    mov     rdi, rsi
    xor     esi, esi
    syscall
    test    rax, rax
    jns     .if_ok
    jmp     .err
.if_ok:
    mov     r12d, eax
    jmp     .next_arg

.do_of:
    add     rsi, 3
    mov     eax, SYS_open
    mov     rdi, rsi
    mov     esi, O_WRONLY|O_CREAT|O_TRUNC
    mov     edx, 0644o
    syscall
    test    rax, rax
    jns     .of_ok
    jmp     .err
.of_ok:
    mov     r13d, eax
    jmp     .next_arg

.do_bs:
    add     rsi, 3
    call    parse_uint64
    mov     r14, rax
    jmp     .next_arg

.do_count:
    add     rsi, 6
    call    parse_uint64
    mov     rbx, rax
    jmp     .next_arg

.next_arg:
    dec     ebp
    jnz     .args

.run:

    cmp     r14, 65536
    ja      .use_fixbuf

.use_fixbuf:
    lea     r9, [rel buf]
    mov     r10, 65536

.loop:
    test    rbx, rbx
    jz      .done

    mov     rdx, r14
    cmp     rdx, r10
    jbe     .rdsz
    mov     rdx, r10
.rdsz:
    mov     eax, SYS_read
    mov     edi, r12d
    mov     rsi, r9
    syscall
    test    rax, rax
    jle     .done

    mov     rdx, rax
    mov     eax, SYS_write
    mov     edi, r13d
    mov     rsi, r9
    syscall
    cmp     rbx, -1
    je      .loop
    dec     rbx
    jmp     .loop

.done:
    cmp     r12d, 0
    je      .skip_close_i
    mov     eax, SYS_close
    mov     edi, r12d
    syscall
.skip_close_i:
    cmp     r13d, 1
    je      .skip_close_o
    mov     eax, SYS_close
    mov     edi, r13d
    syscall
.skip_close_o:
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

prefix3:
    mov     eax, [rsi]
    and     eax, 0xFFFFFF
    mov     ecx, [rdi]
    and     ecx, 0xFFFFFF
    cmp     eax, ecx
    ret

prefix5:

    push    rbx
    mov     eax, [rsi]
    mov     ecx, [rdi]
    cmp     eax, ecx
    jne     .nope
    movzx   eax, word [rsi+4]
    movzx   ecx, word [rdi+4]
    cmp     ax, cx
.nope:
    pop     rbx
    ret

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

section .data
bs_str: db "bs=",0
ct_str: db "count=",0
msg_e:  db "dd: error",0x0a
me_len: equ $ - msg_e

section .bss
buf: resb 65536

