bits 64
section .text
global _start

%define SYS_read   0
%define SYS_write  1
%define SYS_open   2
%define SYS_close  3
%define SYS_ioctl  16
%define SYS_exit   60

%define O_RDONLY 0
%define O_WRONLY 1
%define O_CREAT  0x40
%define O_TRUNC  0x200

%define TCGETS 0x5401
%define TCSETS 0x5402
%define TERMIOS_SZ 36

%define BUF_CAP     65536
%define OUT_CAP     16384
%define SCREEN_ROWS 24
%define SCREEN_COLS 80
%define TEXT_ROWS   (SCREEN_ROWS-1)

%define KEY_UP    1000
%define KEY_DOWN  1001
%define KEY_RIGHT 1002
%define KEY_LEFT  1003

%define CTRL_Q 0x11
%define CTRL_S 0x13

_start:
    pop     rcx
    pop     rdi
    cmp     rcx, 2
    jl      .no_arg
    pop     rsi
    mov     [rel filename_ptr], rsi
    jmp     .try_open
.no_arg:
    mov     qword [rel filename_ptr], 0
    jmp     .after_load

.try_open:
    mov     eax, SYS_open
    mov     rdi, [rel filename_ptr]
    mov     esi, O_RDONLY
    xor     edx, edx
    syscall
    test    rax, rax
    js      .after_load
    mov     r12d, eax
.read_loop:
    mov     eax, SYS_read
    mov     edi, r12d
    lea     rsi, [rel buf]
    add     rsi, [rel buf_len]
    mov     rdx, BUF_CAP
    sub     rdx, [rel buf_len]
    syscall
    test    rax, rax
    jle     .read_done
    add     [rel buf_len], rax
    jmp     .read_loop
.read_done:
    mov     edi, r12d
    mov     eax, SYS_close
    syscall
.after_load:

    call    enable_raw_mode

.main_loop:
    call    render
    call    read_key

    cmp     eax, CTRL_Q
    je      .do_quit
    cmp     eax, CTRL_S
    je      .do_save
    cmp     eax, KEY_UP
    je      .do_up
    cmp     eax, KEY_DOWN
    je      .do_down
    cmp     eax, KEY_LEFT
    je      .do_left
    cmp     eax, KEY_RIGHT
    je      .do_right
    cmp     eax, 0x7f
    je      .do_backspace
    cmp     eax, 0x08
    je      .do_backspace
    cmp     eax, 0x0d
    je      .do_enter
    cmp     eax, 0x20
    jl      .main_loop
    cmp     eax, 0x7e
    jg      .main_loop
    call    insert_char
    jmp     .main_loop

.do_up:
    call    move_up
    jmp     .main_loop
.do_down:
    call    move_down
    jmp     .main_loop
.do_left:
    call    move_left
    jmp     .main_loop
.do_right:
    call    move_right
    jmp     .main_loop
.do_backspace:
    call    do_backspace
    jmp     .main_loop
.do_enter:
    mov     eax, 0x0a
    call    insert_char
    jmp     .main_loop
.do_save:
    call    save_file
    jmp     .main_loop

.do_quit:
    call    disable_raw_mode
    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel esc_clear]
    mov     edx, esc_clear_len
    syscall
    xor     edi, edi
    mov     eax, SYS_exit
    syscall

enable_raw_mode:
    mov     eax, SYS_ioctl
    xor     edi, edi
    mov     esi, TCGETS
    lea     rdx, [rel orig_termios]
    syscall

    lea     rsi, [rel orig_termios]
    lea     rdi, [rel raw_termios]
    mov     ecx, TERMIOS_SZ
    rep     movsb

    mov     eax, [rel raw_termios+0]
    and     eax, ~0x0532
    mov     [rel raw_termios+0], eax

    mov     eax, [rel raw_termios+4]
    and     eax, ~0x0001
    mov     [rel raw_termios+4], eax

    mov     eax, [rel raw_termios+8]
    or      eax, 0x0030
    mov     [rel raw_termios+8], eax

    mov     eax, [rel raw_termios+12]
    and     eax, ~0x800B
    mov     [rel raw_termios+12], eax

    mov     byte [rel raw_termios+23], 1
    mov     byte [rel raw_termios+22], 0

    mov     eax, SYS_ioctl
    xor     edi, edi
    mov     esi, TCSETS
    lea     rdx, [rel raw_termios]
    syscall
    ret

disable_raw_mode:
    mov     eax, SYS_ioctl
    xor     edi, edi
    mov     esi, TCSETS
    lea     rdx, [rel orig_termios]
    syscall
    ret

read_key:
.rk_read:
    lea     rsi, [rel keybuf]
    mov     edx, 1
    xor     edi, edi
    mov     eax, SYS_read
    syscall
    test    rax, rax
    jle     .rk_read
    movzx   eax, byte [rel keybuf]
    cmp     al, 0x1b
    jne     .rk_ret

    lea     rsi, [rel keybuf]
    mov     edx, 1
    xor     edi, edi
    mov     eax, SYS_read
    syscall
    test    rax, rax
    jle     .rk_esc_alone
    cmp     byte [rel keybuf], '['
    jne     .rk_esc_alone

    lea     rsi, [rel keybuf]
    mov     edx, 1
    xor     edi, edi
    mov     eax, SYS_read
    syscall
    test    rax, rax
    jle     .rk_esc_alone
    movzx   eax, byte [rel keybuf]
    cmp     al, 'A'
    je      .rk_up
    cmp     al, 'B'
    je      .rk_down
    cmp     al, 'C'
    je      .rk_right
    cmp     al, 'D'
    je      .rk_left
    xor     eax, eax
    ret
.rk_up:
    mov     eax, KEY_UP
    ret
.rk_down:
    mov     eax, KEY_DOWN
    ret
.rk_right:
    mov     eax, KEY_RIGHT
    ret
.rk_left:
    mov     eax, KEY_LEFT
    ret
.rk_esc_alone:
    mov     eax, 0x1b
    ret
.rk_ret:
    ret

scan_cursor:
    xor     r8, r8
    xor     r9, r9
    xor     rax, rax
.sc_loop:
    cmp     rax, [rel cursor_pos]
    jge     .sc_done
    cmp     byte [rel buf+rax], 0x0a
    jne     .sc_notnl
    inc     r8
    xor     r9, r9
    jmp     .sc_next
.sc_notnl:
    inc     r9
.sc_next:
    inc     rax
    jmp     .sc_loop
.sc_done:
    mov     [rel cur_cy], r8
    mov     [rel cur_cx], r9
    ret

get_line_offset:
    xor     rax, rax
    xor     rdx, rdx
.gl_loop:
    cmp     rdx, rdi
    je      .gl_found
.gl_scan:
    cmp     rax, [rel buf_len]
    jge     .gl_nf
    cmp     byte [rel buf+rax], 0x0a
    je      .gl_adv
    inc     rax
    jmp     .gl_scan
.gl_adv:
    inc     rax
    inc     rdx
    jmp     .gl_loop
.gl_found:
    ret
.gl_nf:
    mov     rax, -1
    ret

line_length:
    mov     rcx, rdi
.ll_loop:
    cmp     rcx, [rel buf_len]
    jge     .ll_done
    cmp     byte [rel buf+rcx], 0x0a
    je      .ll_done
    inc     rcx
    jmp     .ll_loop
.ll_done:
    sub     rcx, rdi
    ret

move_left:
    cmp     qword [rel cursor_pos], 0
    je      .ml_ret
    dec     qword [rel cursor_pos]
.ml_ret:
    ret

move_right:
    mov     rax, [rel cursor_pos]
    cmp     rax, [rel buf_len]
    jge     .mr_ret
    inc     qword [rel cursor_pos]
.mr_ret:
    ret

move_up:
    call    scan_cursor
    mov     rax, [rel cur_cy]
    test    rax, rax
    jz      .mu_ret
    dec     rax
    mov     rdi, rax
    call    get_line_offset
    cmp     rax, -1
    je      .mu_ret
    mov     r10, rax
    mov     rdi, rax
    call    line_length
    mov     rax, [rel cur_cx]
    cmp     rax, rcx
    jle     .mu_col_ok
    mov     rax, rcx
.mu_col_ok:
    add     rax, r10
    mov     [rel cursor_pos], rax
.mu_ret:
    ret

move_down:
    call    scan_cursor
    mov     rax, [rel cur_cy]
    inc     rax
    mov     rdi, rax
    call    get_line_offset
    cmp     rax, -1
    je      .md_ret
    mov     r10, rax
    mov     rdi, rax
    call    line_length
    mov     rax, [rel cur_cx]
    cmp     rax, rcx
    jle     .md_col_ok
    mov     rax, rcx
.md_col_ok:
    add     rax, r10
    mov     [rel cursor_pos], rax
.md_ret:
    ret

insert_char:
    mov     r10d, eax
    mov     rax, [rel buf_len]
    cmp     rax, BUF_CAP-1
    jge     .ic_full
    mov     rsi, [rel buf_len]
.ic_shift:
    cmp     rsi, [rel cursor_pos]
    jle     .ic_shift_done
    mov     rax, rsi
    dec     rax
    movzx   edx, byte [rel buf+rax]
    mov     [rel buf+rsi], dl
    dec     rsi
    jmp     .ic_shift
.ic_shift_done:
    mov     rax, [rel cursor_pos]
    mov     [rel buf+rax], r10b
    inc     qword [rel buf_len]
    inc     qword [rel cursor_pos]
    mov     byte [rel modified], 1
.ic_full:
    ret

do_backspace:
    cmp     qword [rel cursor_pos], 0
    je      .bs_ret
    mov     rsi, [rel cursor_pos]
    dec     rsi
.bs_loop:
    mov     rax, [rel buf_len]
    dec     rax
    cmp     rsi, rax
    jge     .bs_loop_done
    mov     rax, rsi
    inc     rax
    movzx   edx, byte [rel buf+rax]
    mov     [rel buf+rsi], dl
    inc     rsi
    jmp     .bs_loop
.bs_loop_done:
    dec     qword [rel buf_len]
    dec     qword [rel cursor_pos]
    mov     byte [rel modified], 1
.bs_ret:
    ret

save_file:
    mov     rdi, [rel filename_ptr]
    test    rdi, rdi
    jz      .sv_ret
    mov     eax, SYS_open
    mov     esi, O_WRONLY|O_CREAT|O_TRUNC
    mov     edx, 0644o
    syscall
    test    rax, rax
    js      .sv_ret
    mov     r12d, eax
    xor     r13, r13
.sv_loop:
    mov     rax, [rel buf_len]
    cmp     r13, rax
    jge     .sv_done
    mov     eax, SYS_write
    mov     edi, r12d
    lea     rsi, [rel buf]
    add     rsi, r13
    mov     rdx, [rel buf_len]
    sub     rdx, r13
    syscall
    test    rax, rax
    jle     .sv_done
    add     r13, rax
    jmp     .sv_loop
.sv_done:
    mov     edi, r12d
    mov     eax, SYS_close
    syscall
    mov     byte [rel modified], 0
.sv_ret:
    ret

append:
    push    rcx
    push    rdi
    lea     rdi, [rel out_buf]
    add     rdi, [rel out_len]
    rep     movsb
    pop     rdi
    pop     rcx
    add     [rel out_len], rcx
    ret

write_num2:
    cmp     eax, 10
    jl      .wn_one
    xor     edx, edx
    mov     ecx, 10
    div     ecx
    add     al, '0'
    mov     [rdi], al
    inc     rdi
    add     dl, '0'
    mov     [rdi], dl
    inc     rdi
    ret
.wn_one:
    add     al, '0'
    mov     [rdi], al
    inc     rdi
    ret

render:
    mov     qword [rel out_len], 0

    call    scan_cursor

    mov     rax, [rel cur_cy]
    cmp     rax, [rel top_line]
    jl      .set_top_up
    mov     rdx, [rel top_line]
    add     rdx, TEXT_ROWS-1
    cmp     rax, rdx
    jg      .set_top_down
    jmp     .top_ok
.set_top_up:
    mov     [rel top_line], rax
    jmp     .top_ok
.set_top_down:
    sub     rax, TEXT_ROWS-1
    mov     [rel top_line], rax
.top_ok:

    lea     rsi, [rel esc_hide]
    mov     rcx, esc_hide_len
    call    append
    lea     rsi, [rel esc_home]
    mov     rcx, esc_home_len
    call    append

    xor     r15, r15
.draw_loop:
    cmp     r15, TEXT_ROWS
    jge     .draw_done

    mov     rdi, [rel top_line]
    add     rdi, r15
    call    get_line_offset
    cmp     rax, -1
    je      .row_clear

    mov     rdi, rax
    push    rax
    call    line_length
    pop     rax
    cmp     rcx, SCREEN_COLS
    jle     .len_ok
    mov     rcx, SCREEN_COLS
.len_ok:
    lea     rsi, [rel buf]
    add     rsi, rax
    call    append

.row_clear:
    lea     rsi, [rel esc_clreol]
    mov     rcx, esc_clreol_len
    call    append
    lea     rsi, [rel crlf]
    mov     rcx, crlf_len
    call    append

    inc     r15
    jmp     .draw_loop
.draw_done:

    call    render_status
    call    position_cursor

    lea     rsi, [rel esc_show]
    mov     rcx, esc_show_len
    call    append

    mov     eax, SYS_write
    mov     edi, 1
    lea     rsi, [rel out_buf]
    mov     rdx, [rel out_len]
    syscall
    ret

render_status:
    mov     rdi, [rel filename_ptr]
    test    rdi, rdi
    jnz     .rs_have_name
    lea     rsi, [rel noname_str]
    mov     rcx, noname_len
    call    append
    jmp     .rs_after_name
.rs_have_name:
    mov     rsi, rdi
    xor     rcx, rcx
.rs_strlen:
    cmp     byte [rsi+rcx], 0
    je      .rs_strlen_done
    inc     rcx
    jmp     .rs_strlen
.rs_strlen_done:
    call    append
.rs_after_name:
    cmp     byte [rel modified], 0
    je      .rs_no_mod
    lea     rsi, [rel mod_str]
    mov     rcx, mod_len
    call    append
.rs_no_mod:
    lea     rsi, [rel hint_str]
    mov     rcx, hint_len
    call    append
    lea     rsi, [rel esc_clreol]
    mov     rcx, esc_clreol_len
    call    append
    ret

position_cursor:
    lea     rdi, [rel pos_tmp]
    mov     byte [rdi], 0x1b
    mov     byte [rdi+1], '['
    add     rdi, 2

    mov     rax, [rel cur_cy]
    sub     rax, [rel top_line]
    inc     rax
    call    write_num2

    mov     byte [rdi], ';'
    inc     rdi

    mov     rax, [rel cur_cx]
    cmp     rax, SCREEN_COLS-1
    jle     .pc_col_ok
    mov     rax, SCREEN_COLS-1
.pc_col_ok:
    inc     rax
    call    write_num2

    mov     byte [rdi], 'H'
    inc     rdi

    lea     rsi, [rel pos_tmp]
    mov     rcx, rdi
    sub     rcx, rsi
    call    append
    ret

section .data
esc_hide:       db 0x1b,"[?25l"
esc_hide_len    equ $-esc_hide
esc_show:       db 0x1b,"[?25h"
esc_show_len    equ $-esc_show
esc_home:       db 0x1b,"[H"
esc_home_len    equ $-esc_home
esc_clreol:     db 0x1b,"[K"
esc_clreol_len  equ $-esc_clreol
esc_clear:      db 0x1b,"[2J",0x1b,"[H"
esc_clear_len   equ $-esc_clear
crlf:           db 0x0d,0x0a
crlf_len        equ $-crlf
noname_str:     db "[sem nome]"
noname_len      equ $-noname_str
mod_str:        db " [+]"
mod_len         equ $-mod_str
hint_str:       db "  ^S salvar  ^Q sair"
hint_len        equ $-hint_str

section .bss
filename_ptr:  resq 1
buf:           resb BUF_CAP
buf_len:       resq 1
cursor_pos:    resq 1
top_line:      resq 1
modified:      resb 1
cur_cy:        resq 1
cur_cx:        resq 1
out_buf:       resb OUT_CAP
out_len:       resq 1
pos_tmp:       resb 32
keybuf:        resb 1
orig_termios:  resb TERMIOS_SZ
raw_termios:   resb TERMIOS_SZ

