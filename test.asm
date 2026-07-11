bits 64
section .text
global _start

%define SYS_stat    4
%define SYS_access 21
%define SYS_exit   60

%define F_OK        0
%define S_IFMT   0170000o
%define S_IFDIR  0040000o
%define S_IFREG  0100000o

_start:
    pop     rcx
    pop     rdi
    dec     rcx

    cmp     rcx, 0
    je      .false_exit
    cmp     rcx, 1
    je      .one_arg
    cmp     rcx, 2
    je      .two_arg
    cmp     rcx, 3
    je      .three_arg
    jmp     .false_exit

.one_arg:
    pop     rsi
    movzx   eax, byte [rsi]
    test    al, al
    jz      .false_exit
    jmp     .true_exit

.two_arg:
    pop     rsi
    pop     rdi

    movzx   eax, byte [rsi]
    cmp     al, '-'
    jne     .false_exit
    movzx   eax, byte [rsi+1]
    cmp     al, 'e'
    je      .do_e
    cmp     al, 'f'
    je      .do_f
    cmp     al, 'd'
    je      .do_d
    cmp     al, 'z'
    je      .do_z
    cmp     al, 'n'
    je      .do_n
    jmp     .false_exit

.do_z:
    movzx   eax, byte [rdi]
    test    al, al
    jz      .true_exit
    jmp     .false_exit
.do_n:
    movzx   eax, byte [rdi]
    test    al, al
    jz      .false_exit
    jmp     .true_exit
.do_e:
    mov     eax, SYS_access
    mov     esi, F_OK
    syscall
    test    eax, eax
    jz      .true_exit
    jmp     .false_exit
.do_f:
    lea     rsi, [rel statbuf]
    mov     eax, SYS_stat
    syscall
    test    eax, eax
    js      .false_exit
    mov     eax, [rel statbuf+24]
    and     eax, S_IFMT
    cmp     eax, S_IFREG
    je      .true_exit
    jmp     .false_exit
.do_d:
    lea     rsi, [rel statbuf]
    mov     eax, SYS_stat
    syscall
    test    eax, eax
    js      .false_exit
    mov     eax, [rel statbuf+24]
    and     eax, S_IFMT
    cmp     eax, S_IFDIR
    je      .true_exit
    jmp     .false_exit

.three_arg:
    pop     rsi
    pop     rdx
    pop     rdi

    movzx   eax, byte [rdx]
    cmp     al, '!'
    je      .op_ne
    cmp     al, '='
    je      .op_eq
    jmp     .false_exit

.op_eq:
    call    .streq
    test    eax, eax
    jnz     .true_exit
    jmp     .false_exit
.op_ne:
    call    .streq
    test    eax, eax
    jz      .true_exit
    jmp     .false_exit

.streq:
.se_loop:
    movzx   eax, byte [rsi]
    movzx   ecx, byte [rdi]
    cmp     al, cl
    jne     .se_ne
    test    al, al
    jz      .se_eq
    inc     rsi
    inc     rdi
    jmp     .se_loop
.se_eq:
    mov     eax, 1
    ret
.se_ne:
    xor     eax, eax
    ret

.true_exit:
    xor     edi, edi
    mov     eax, SYS_exit
    syscall
.false_exit:
    mov     edi, 1
    mov     eax, SYS_exit
    syscall

section .bss
statbuf: resb 144

