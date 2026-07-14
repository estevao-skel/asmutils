BITS 64
%define SYS_read     0
%define SYS_write    1
%define SYS_open     2
%define SYS_close    3
%define SYS_socket   41
%define SYS_connect  42
%define SYS_exit     60
%define AF_INET      2
%define SOCK_STREAM  1
%define SOCK_DGRAM   2
%define O_WRONLY     0x0001
%define O_CREAT      0x0040
%define O_TRUNC      0x0200
%define RECVBUF_SIZE 65536
%define DNS_IP0 10
%define DNS_IP1 0
%define DNS_IP2 2
%define DNS_IP3 3
%define DNS_PORT_HI 0x00
%define DNS_PORT_LO 0x35
section .data
s_get:      db "GET "
s_get_len   equ $ - s_get
s_http:     db " HTTP/1.1", 13, 10, "Host: "
s_http_len  equ $ - s_http
s_conn:     db 13, 10, "Connection: close", 13, 10, 13, 10
s_conn_len  equ $ - s_conn
usage_msg:  db "uso: wgetasm <host_ou_ip> <porta> <path> <arquivo_saida>", 10
usage_len   equ $ - usage_msg
err_msg:    db "erro: socket/connect/open falhou", 10
err_len     equ $ - err_msg
err_dns_msg: db "erro: dns falhou", 10
err_dns_len  equ $ - err_dns_msg
dns_query_hdr: db 0x12, 0x34, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
dns_query_hdr_len equ $ - dns_query_hdr
dns_qtype_class: db 0x00, 0x01, 0x00, 0x01
section .bss
g_host      resq 1
g_port      resq 1
g_path      resq 1
g_out       resq 1
ip_bytes    resb 4
port_be     resb 2
sockaddr_in resb 16
sockfd      resq 1
outfd       resq 1
request        resb 4096
request_len    resq 1
recvbuf     resb RECVBUF_SIZE
in_header   resb 1
hdr_state   resb 1
section .text
global _start
parse_ip:
    xor r8, r8
    xor eax, eax
.next_char:
    movzx edx, byte [rsi]
    test dl, dl
    jz .store_last
    cmp dl, '.'
    je .store_octet
    sub dl, '0'
    imul eax, eax, 10
    add eax, edx
    inc rsi
    jmp .next_char
.store_octet:
    mov [ip_bytes + r8], al
    xor eax, eax
    inc r8
    inc rsi
    jmp .next_char
.store_last:
    mov [ip_bytes + r8], al
    ret
parse_port:
    xor eax, eax
.loop:
    movzx edx, byte [rsi]
    test dl, dl
    jz .done
    sub dl, '0'
    imul eax, eax, 10
    add eax, edx
    inc rsi
    jmp .loop
.done:
    mov byte [port_be], ah
    mov byte [port_be+1], al
    ret
strlen:
    xor rcx, rcx
.loop:
    cmp byte [rsi+rcx], 0
    je .done
    inc rcx
    jmp .loop
.done:
    ret
is_literal_ip:
    push rsi
.chk:
    movzx eax, byte [rsi]
    test al, al
    jz .yes
    cmp al, '.'
    je .nextc
    cmp al, '0'
    jl .no
    cmp al, '9'
    jg .no
.nextc:
    inc rsi
    jmp .chk
.yes:
    pop rsi
    mov eax, 1
    ret
.no:
    pop rsi
    xor eax, eax
    ret
skip_name:
.lp:
    movzx eax, byte [rsi]
    test al, al
    jz .null_end
    mov edx, eax
    and dl, 0xC0
    cmp dl, 0xC0
    je .is_ptr
    movzx ecx, al
    inc rsi
    add rsi, rcx
    jmp .lp
.is_ptr:
    add rsi, 2
    ret
.null_end:
    inc rsi
    ret
dns_resolve:
    push rbx
    push r12
    push r13
    push r14
    mov r14, rdi
    lea rdi, [request]
    lea rsi, [dns_query_hdr]
    mov rcx, dns_query_hdr_len
    rep movsb
    mov rsi, r14
.enc_next:
    lea r8, [rdi]
    inc rdi
    xor ecx, ecx
.enc_copy:
    movzx eax, byte [rsi]
    test al, al
    jz .enc_end
    cmp al, '.'
    je .enc_label_done
    mov [rdi], al
    inc rdi
    inc rsi
    inc ecx
    jmp .enc_copy
.enc_label_done:
    mov [r8], cl
    inc rsi
    jmp .enc_next
.enc_end:
    mov [r8], cl
    mov byte [rdi], 0
    inc rdi
    lea rsi, [dns_qtype_class]
    mov rcx, 4
    rep movsb
    mov rax, rdi
    sub rax, request
    mov r13, rax
    mov eax, SYS_socket
    mov edi, AF_INET
    mov esi, SOCK_DGRAM
    xor edx, edx
    syscall
    test rax, rax
    js .fail
    mov r12, rax
    mov word [sockaddr_in], AF_INET
    mov byte [sockaddr_in+2], DNS_PORT_HI
    mov byte [sockaddr_in+3], DNS_PORT_LO
    mov byte [sockaddr_in+4], DNS_IP0
    mov byte [sockaddr_in+5], DNS_IP1
    mov byte [sockaddr_in+6], DNS_IP2
    mov byte [sockaddr_in+7], DNS_IP3
    mov qword [sockaddr_in+8], 0
    mov rdi, r12
    lea rsi, [sockaddr_in]
    mov edx, 16
    mov eax, SYS_connect
    syscall
    test rax, rax
    js .fail_close
    mov rdi, r12
    lea rsi, [request]
    mov rdx, r13
    mov eax, SYS_write
    syscall
    test rax, rax
    js .fail_close
    mov rdi, r12
    lea rsi, [recvbuf]
    mov rdx, RECVBUF_SIZE
    xor eax, eax
    syscall
    test rax, rax
    jle .fail_close
    mov eax, SYS_close
    mov edi, r12d
    syscall
    movzx eax, byte [recvbuf+6]
    shl eax, 8
    movzx ecx, byte [recvbuf+7]
    or eax, ecx
    mov ebx, eax
    lea rsi, [recvbuf+12]
    call skip_name
    add rsi, 4
.ans_loop:
    test ebx, ebx
    jz .not_found
    call skip_name
    movzx eax, byte [rsi]
    shl eax, 8
    movzx edx, byte [rsi+1]
    or eax, edx
    movzx ecx, byte [rsi+8]
    shl ecx, 8
    movzx edx, byte [rsi+9]
    or ecx, edx
    add rsi, 10
    cmp eax, 1
    jne .skip_rdata
    cmp ecx, 4
    jne .skip_rdata
    mov eax, [rsi]
    mov [ip_bytes], eax
    jmp .found
.skip_rdata:
    add rsi, rcx
    dec ebx
    jmp .ans_loop
.found:
    clc
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.not_found:
.fail:
    stc
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.fail_close:
    push rax
    mov eax, SYS_close
    mov edi, r12d
    syscall
    pop rax
    jmp .fail
_start:
    mov rax, [rsp]
    cmp rax, 5
    jl usage_err
    mov rax, [rsp+16]
    mov [g_host], rax
    mov rax, [rsp+24]
    mov [g_port], rax
    mov rax, [rsp+32]
    mov [g_path], rax
    mov rax, [rsp+40]
    mov [g_out], rax
    mov rsi, [g_host]
    call is_literal_ip
    test eax, eax
    jz .need_dns
    mov rsi, [g_host]
    call parse_ip
    jmp .ip_ready
.need_dns:
    mov rdi, [g_host]
    call dns_resolve
    jc dns_fail
.ip_ready:
    mov rsi, [g_port]
    call parse_port
    mov word [sockaddr_in], AF_INET
    mov ax, [port_be]
    mov [sockaddr_in+2], ax
    mov eax, [ip_bytes]
    mov [sockaddr_in+4], eax
    mov qword [sockaddr_in+8], 0
    mov eax, SYS_socket
    mov edi, AF_INET
    mov esi, SOCK_STREAM
    xor edx, edx
    syscall
    test rax, rax
    js fail
    mov [sockfd], rax
    mov rdi, [sockfd]
    lea rsi, [sockaddr_in]
    mov edx, 16
    mov eax, SYS_connect
    syscall
    test rax, rax
    js fail
    mov rdi, request
    mov rsi, s_get
    mov rcx, s_get_len
    rep movsb
    mov rsi, [g_path]
    call strlen
    rep movsb
    mov rsi, s_http
    mov rcx, s_http_len
    rep movsb
    mov rsi, [g_host]
    call strlen
    rep movsb
    mov rsi, s_conn
    mov rcx, s_conn_len
    rep movsb
    mov rax, rdi
    sub rax, request
    mov [request_len], rax
    mov rdi, [sockfd]
    mov rsi, request
    mov rdx, [request_len]
    mov eax, SYS_write
    syscall
    mov rdi, [g_out]
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0644o
    mov eax, SYS_open
    syscall
    test rax, rax
    js fail
    mov [outfd], rax
    mov byte [in_header], 1
    mov byte [hdr_state], 0
read_loop:
    mov rdi, [sockfd]
    mov rsi, recvbuf
    mov rdx, RECVBUF_SIZE
    xor eax, eax
    syscall
    test rax, rax
    jle read_done
    mov r15, rax
    cmp byte [in_header], 0
    je write_full
    mov rsi, recvbuf
    mov rcx, r15
    movzx edx, byte [hdr_state]
scan_loop:
    test rcx, rcx
    jz scan_no_match_this_round
    movzx eax, byte [rsi]
    inc rsi
    dec rcx
    cmp edx, 0
    je .s0
    cmp edx, 1
    je .s1
    cmp edx, 2
    je .s2
    jmp .s3
.s0:
    cmp al, 13
    jne .r0
    mov edx, 1
    jmp scan_loop
.r0:
    xor edx, edx
    jmp scan_loop
.s1:
    cmp al, 10
    jne .r1
    mov edx, 2
    jmp scan_loop
.r1:
    cmp al, 13
    jne .r1b
    mov edx, 1
    jmp scan_loop
.r1b:
    xor edx, edx
    jmp scan_loop
.s2:
    cmp al, 13
    jne .r2
    mov edx, 3
    jmp scan_loop
.r2:
    cmp al, 13
    jne .r2b
    mov edx, 1
    jmp scan_loop
.r2b:
    xor edx, edx
    jmp scan_loop
.s3:
    cmp al, 10
    jne .r3
    mov byte [in_header], 0
    test rcx, rcx
    jz scan_done
    mov rdi, [outfd]
    mov rdx, rcx
    mov eax, SYS_write
    syscall
    jmp scan_done
.r3:
    cmp al, 13
    jne .r3b
    mov edx, 1
    jmp scan_loop
.r3b:
    xor edx, edx
    jmp scan_loop
scan_no_match_this_round:
    mov [hdr_state], dl
    jmp read_loop
scan_done:
    jmp read_loop
write_full:
    mov rdi, [outfd]
    mov rsi, recvbuf
    mov rdx, r15
    mov eax, SYS_write
    syscall
    jmp read_loop
read_done:
    mov rdi, [sockfd]
    mov eax, SYS_close
    syscall
    mov rdi, [outfd]
    mov eax, SYS_close
    syscall
    xor edi, edi
    mov eax, SYS_exit
    syscall
fail:
    mov rdi, 2
    mov rsi, err_msg
    mov rdx, err_len
    mov eax, SYS_write
    syscall
    mov edi, 1
    mov eax, SYS_exit
    syscall
dns_fail:
    mov rdi, 2
    mov rsi, err_dns_msg
    mov rdx, err_dns_len
    mov eax, SYS_write
    syscall
    mov edi, 1
    mov eax, SYS_exit
    syscall
usage_err:
    mov rdi, 2
    mov rsi, usage_msg
    mov rdx, usage_len
    mov eax, SYS_write
    syscall
    mov edi, 1
    mov eax, SYS_exit
    syscall
