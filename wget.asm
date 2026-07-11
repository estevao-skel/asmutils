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
%define O_WRONLY     0x0001
%define O_CREAT      0x0040
%define O_TRUNC      0x0200
%define RECVBUF_SIZE 65536
section .data
s_get:      db "GET "
s_get_len   equ $ - s_get
s_http:     db " HTTP/1.1", 13, 10, "Host: "
s_http_len  equ $ - s_http
s_conn:     db 13, 10, "Connection: close", 13, 10, 13, 10
s_conn_len  equ $ - s_conn
usage_msg:  db "uso: wgetasm <ip> <porta> <host> <path> <arquivo_saida>", 10
usage_len   equ $ - usage_msg
err_msg:    db "erro: socket/connect/open falhou", 10
err_len     equ $ - err_msg
section .bss
g_ip        resq 1
g_port      resq 1
g_host      resq 1
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
_start:
    mov rax, [rsp]
    cmp rax, 6
    jl usage_err
    mov rax, [rsp+16]
    mov [g_ip], rax
    mov rax, [rsp+24]
    mov [g_port], rax
    mov rax, [rsp+32]
    mov [g_host], rax
    mov rax, [rsp+40]
    mov [g_path], rax
    mov rax, [rsp+48]
    mov [g_out], rax
    mov rsi, [g_ip]
    call parse_ip
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
usage_err:
    mov rdi, 2
    mov rsi, usage_msg
    mov rdx, usage_len
    mov eax, SYS_write
    syscall
    mov edi, 1
    mov eax, SYS_exit
    syscall

