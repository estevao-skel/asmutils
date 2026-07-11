bits 64
section .text
global _start

%define SYS_socket    41
%define SYS_ioctl     16
%define SYS_close      3
%define SYS_write      1
%define SYS_exit      60

%define AF_INET        2
%define SOCK_DGRAM     2
%define SIOCGIFADDR    0x8915
%define SIOCSIFADDR    0x8916
%define SIOCGIFFLAGS   0x8913
%define SIOCSIFFLAGS   0x8914
%define SIOCSIFNETMASK 0x891C
%define SIOCADDRT      0x890B
%define IFF_UP         1

%define IFREQ_SIZE     40
%define IFNAMSIZ       16
%define IF_ADDR_OFF    16

%define RTENTRY_SIZE   120
%define RT_DST_OFF     8
%define RT_GW_OFF      24
%define RT_GENMASK_OFF 40
%define RT_FLAGS_OFF   56
%define RT_DEV_OFF     88

_start:
    pop     rcx
    cmp     rcx, 2
    jl      show_help
    pop     rdi
    pop     rsi
    sub     rcx, 2

    cmp     dword [rsi], 'show'
    je      do_show
    cmp     word [rsi], 'up'
    je      do_up
    cmp     dword [rsi], 'down'
    je      do_down
    cmp     dword [rsi], 'addr'
    je      do_addr
    cmp     dword [rsi], 'rout'
    je      do_route

show_help:
    lea     rsi, [rel help_msg]
    xor     edx, edx
    mov     dl, help_len
    call    writestdout1
    xor     edi, edi
    jmp     exit_now

do_show:
    test    rcx, rcx
    jz      show_lo
    pop     rsi
    jmp     show_iface
show_lo:
    lea     rsi, [rel lo_name]
show_iface:
    call    fill_ifreq
    call    get_sock

    mov     esi, SIOCGIFADDR
    lea     rdx, [rel ifreq]
    call    do_ioctl
    js      err_exit

    lea     rbx, [rel ifreq+IF_ADDR_OFF+4]
    push    4
    pop     r13
show_loop:
    movzx   edi, byte [rbx]
    call    punum
    cmp     r13, 1
    je      show_nl
    lea     rsi, [rel dot]
    jmp     show_sep
show_nl:
    lea     rsi, [rel nl]
show_sep:
    xor     edx, edx
    inc     edx
    call    writestdout1
    inc     rbx
    dec     r13
    jnz     show_loop

    jmp     ok_exit

do_up:
    push    1
    pop     r8
    jmp     updown
do_down:
    xor     r8d, r8d
updown:
    call    needarg
    pop     rsi
    call    fill_ifreq
    call    get_sock

    mov     esi, SIOCGIFFLAGS
    lea     rdx, [rel ifreq]
    call    do_ioctl

    test    r8, r8
    jz      clear_flag
    or      word [rel ifreq+IF_ADDR_OFF], IFF_UP
    jmp     set_flag
clear_flag:
    and     word [rel ifreq+IF_ADDR_OFF], ~IFF_UP
set_flag:
    mov     esi, SIOCSIFFLAGS
    call    do_ioctl
    jmp     ok_exit

do_addr:
    call    needarg
    pop     r14
    dec     rcx
    call    needarg
    pop     r13
    dec     rcx
    xor     r15d, r15d
    test    rcx, rcx
    jz      addr_go
    pop     r15
addr_go:
    mov     rsi, r14
    call    fill_ifreq
    lea     rdi, [rel ifreq+IF_ADDR_OFF+4]
    mov     rsi, r13
    call    parse_ip
    mov     word [rel ifreq+IF_ADDR_OFF], AF_INET

    call    get_sock
    mov     esi, SIOCSIFADDR
    lea     rdx, [rel ifreq]
    call    do_ioctl
    js      err_exit

    test    r15, r15
    jz      ok_exit
    lea     rdi, [rel ifreq+IF_ADDR_OFF+4]
    mov     rsi, r15
    call    parse_ip
    mov     word [rel ifreq+IF_ADDR_OFF], AF_INET
    mov     esi, SIOCSIFNETMASK
    lea     rdx, [rel ifreq]
    call    do_ioctl
    jmp     ok_exit

do_route:
    call    needarg
    pop     r14
    dec     rcx
    call    needarg
    pop     r13

    lea     rdi, [rel rtentry]
    xor     eax, eax
    xor     ecx, ecx
    mov     cl, RTENTRY_SIZE
    rep stosb

    mov     word [rel rtentry+RT_DST_OFF], AF_INET
    mov     word [rel rtentry+RT_GENMASK_OFF], AF_INET
    mov     word [rel rtentry+RT_GW_OFF], AF_INET
    lea     rdi, [rel rtentry+RT_GW_OFF+4]
    mov     rsi, r13
    call    parse_ip
    mov     word [rel rtentry+RT_FLAGS_OFF], 3
    lea     rax, [rel rtentry+RT_DEV_OFF]
    mov     [rax], r14

    call    get_sock
    mov     esi, SIOCADDRT
    lea     rdx, [rel rtentry]
    call    do_ioctl
    js      err_exit

ok_exit:
    mov     eax, SYS_close
    mov     edi, r12d
    syscall
    xor     edi, edi
exit_now:
    mov     eax, SYS_exit
    syscall

err_exit:
    mov     eax, SYS_write
    push    2
    pop     rdi
    lea     rsi, [rel errmsg]
    xor     edx, edx
    mov     dl, err_l
    syscall
    push    1
    pop     rdi
    jmp     exit_now


needarg:
    test    rcx, rcx
    jz      show_help
    ret

fill_ifreq:
    push    rsi
    lea     rdi, [rel ifreq]
    xor     eax, eax
    xor     ecx, ecx
    mov     cl, IFREQ_SIZE
    rep stosb
    pop     rsi
    lea     rdi, [rel ifreq]
    xor     ecx, ecx
    mov     cl, IFNAMSIZ-1
fi_cp:
    movzx   eax, byte [rsi]
    test    al, al
    jz      fi_done
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jnz     fi_cp
fi_done:
    ret

parse_ip:
    xor     ecx, ecx
pi_octet:
    xor     eax, eax
pi_digit:
    movzx   edx, byte [rsi]
    cmp     dl, '0'
    jl      pi_octet_done
    cmp     dl, '9'
    jg      pi_octet_done
    imul    eax, eax, 10
    sub     dl, '0'
    movzx   edx, dl
    add     eax, edx
    inc     rsi
    jmp     pi_digit
pi_octet_done:
    mov     [rdi+rcx], al
    inc     rcx
    cmp     byte [rsi], '.'
    jne     pi_end
    inc     rsi
    cmp     rcx, 4
    jl      pi_octet
pi_end:
    ret

get_sock:
    mov     eax, SYS_socket
    mov     edi, AF_INET
    mov     esi, SOCK_DGRAM
    xor     edx, edx
    syscall
    test    eax, eax
    js      err_exit
    mov     r12d, eax
    ret

do_ioctl:
    mov     eax, SYS_ioctl
    mov     edi, r12d
    syscall
    ret

writestdout1:
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    ret

punum:
    push    rbx
    lea     rbx, [rel nbuf+19]
    mov     byte [rbx], 0
    dec     rbx
    mov     rax, rdi
    xor     ecx, ecx
    mov     cl, 10
nd:
    xor     edx, edx
    div     rcx
    add     dl, '0'
    mov     [rbx], dl
    dec     rbx
    test    rax, rax
    jnz     nd
    inc     rbx
    lea     rdx, [rel nbuf+19]
    sub     rdx, rbx
    mov     rsi, rbx
    call    writestdout1
    pop     rbx
    ret

section .data
help_msg: db "show up down addr route <if>",0x0a
help_len: equ $-help_msg
lo_name:  db "lo",0
errmsg:   db "err",0x0a
err_l:    equ $-errmsg
dot:      db "."
nl:       db 0x0a

section .bss
ifreq:   resb IFREQ_SIZE
rtentry: resb RTENTRY_SIZE
nbuf:    resb 24

