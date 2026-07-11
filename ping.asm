bits 64
section .text
global _start

%define SYS_socket    41
%define SYS_sendto    44
%define SYS_recvfrom  45
%define SYS_write      1
%define SYS_exit      60
%define SYS_time      201
%define SYS_clock_gettime 228

%define AF_INET       2
%define SOCK_RAW      3
%define IPPROTO_ICMP  1
%define ICMP_ECHO     8
%define ICMP_ECHOREPLY 0

_start:
    pop     rcx
    cmp     rcx, 2
    jl      .usage
    pop     rdi
    pop     r14

    xor     r15d, r15d
    mov     rsi, r14
    mov     ecx, 4
.parse_ip:
    xor     eax, eax
.digit:
    movzx   edx, byte [rsi]
    cmp     dl, '0'
    jb      .next_oct
    cmp     dl, '9'
    ja      .next_oct
    imul    eax, eax, 10
    sub     edx, '0'
    add     eax, edx
    inc     rsi
    jmp     .digit
.next_oct:
    inc     rsi
    shl     r15d, 8
    and     eax, 0xff
    or      r15d, eax
    dec     ecx
    jnz     .parse_ip
    bswap   r15d

    mov     eax, SYS_socket
    mov     edi, AF_INET
    mov     esi, SOCK_RAW
    mov     edx, IPPROTO_ICMP
    syscall
    test    rax, rax
    js      .sock_err
    mov     r12d, eax

    lea     rdi, [rel pkt]
    mov     byte [rdi], ICMP_ECHO
    mov     byte [rdi+1], 0
    mov     word [rdi+2], 0
    mov     word [rdi+4], 0x0100
    mov     word [rdi+6], 0x0100

    lea     rsi, [rel ping_data]
    lea     rdi, [rel pkt+8]
    mov     ecx, 13
    rep movsb

    lea     rsi, [rel pkt]
    mov     ecx, 21
    xor     eax, eax
.cksum:
    movzx   edx, word [rsi]
    add     eax, edx
    add     rsi, 2
    sub     ecx, 2
    jg      .cksum

    mov     edx, eax
    shr     edx, 16
    and     eax, 0xffff
    add     eax, edx
    not     ax
    lea     rdi, [rel pkt]
    mov     word [rdi+2], ax

    lea     rdi, [rel sa]
    mov     word [rdi], AF_INET
    mov     word [rdi+2], 0
    mov     dword [rdi+4], r15d

    mov     eax, SYS_sendto
    mov     edi, r12d
    lea     rsi, [rel pkt]
    mov     edx, 21
    xor     ecx, ecx
    lea     r8, [rel sa]
    mov     r9d, 16
    syscall
    test    rax, rax
    js      .send_err

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel ping_msg]
    mov     edx, ping_msg_l
    syscall

    mov     eax, SYS_write
    mov     edi, 1
    mov     rsi, r14
    xor     edx, edx
.ips: cmp byte [r14+rdx], 0
    je .ipsd
    inc edx
    jmp .ips
.ipsd:
    syscall
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    syscall

    mov     eax, SYS_recvfrom
    mov     edi, r12d
    lea     rsi, [rel rbuff]
    mov     edx, 256
    xor     ecx, ecx
    xor     r8d, r8d
    xor     r9d, r9d
    syscall
    test    rax, rax
    js      .recv_err

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel reply_msg]
    mov     edx, reply_msg_l
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
.sock_err:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel se]
    mov     edx, se_l
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall
.send_err:
.recv_err:
    mov     eax, SYS_write
    mov     edi, 2
    lea     rsi, [rel ee]
    mov     edx, ee_l
    syscall
    mov     eax, SYS_exit
    mov     edi, 1
    syscall

section .data
mu:        db "usage: ping ip",0x0a
mu_l:      equ $-mu
se:        db "ping: socket failed (need root?)",0x0a
se_l:      equ $-se
ee:        db "ping: send/recv error",0x0a
ee_l:      equ $-ee
ping_msg:  db "PING "
ping_msg_l: equ $-ping_msg
reply_msg: db "Reply received",0x0a
reply_msg_l: equ $-reply_msg
ping_data: db "asmutils ping"
nl:        db 0x0a

section .bss
pkt:   resb 32
sa:    resb 16
rbuff: resb 256

