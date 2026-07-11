bits 64

%define SYS_read      0
%define SYS_write     1
%define SYS_open      2
%define SYS_close     3
%define SYS_lseek     8
%define SYS_fork      57
%define SYS_execve    59
%define SYS_exit      60
%define SYS_wait4     61
%define SYS_pipe      22
%define SYS_dup       32
%define SYS_dup2      33
%define SYS_chdir     80
%define SYS_getcwd    79

%define O_RDONLY   0
%define O_WRONLY   1
%define O_CREAT    0x40
%define O_TRUNC    0x200
%define O_APPEND   0x400

%define STDIN  0
%define STDOUT 1
%define STDERR 2

%define MAX_ARGS   64
%define MAX_CMDS   16
%define BUF_SIZE   4096

section .text
global _start

_start:
    pop     rcx
    pop     rdi
    dec     rcx
    jz      .interactive

    pop     rsi
    mov     eax, SYS_open
    mov     rdi, rsi
    xor     esi, esi
    syscall
    test    rax, rax
    js      .err_open
    mov     [script_fd], eax
    mov     byte [is_script], 1
    jmp     .main_loop

.err_open:
    lea     rsi, [rel msg_nofile]
    mov     edx, msg_nofile_l
    call    errw
    mov     eax, SYS_exit
    mov     edi, 1
    syscall

.interactive:
    mov     dword [script_fd], 0
    mov     byte [is_script], 0

.main_loop:
    cmp     byte [is_script], 0
    jne     .read_line
    mov     edi, STDOUT
    lea     rsi, [rel prompt]
    mov     edx, 2
    call    wr

.read_line:
    call    readline
    cmp     rax, -1
    je      .eof

    lea     rdi, [rel linebuf]
    call    exec_line
    jmp     .main_loop

.eof:
    movzx   edi, byte [last_exit]
    mov     eax, SYS_exit
    syscall

readline:
    push    rbx
    xor     ebx, ebx
    movzx   edx, byte [is_script]
    test    edx, edx
    jz      .src_stdin
    mov     r8d, [script_fd]
    jmp     .rd
.src_stdin:
    xor     r8d, r8d
.rd:
    mov     eax, SYS_read
    mov     edi, r8d
    lea     rsi, [rel charbuf]
    mov     edx, 1
    syscall
    test    rax, rax
    jle     .rd_eof
    movzx   eax, byte [rel charbuf]
    cmp     al, 0x0a
    je      .rd_done
    cmp     al, 0x0d
    je      .rd
    cmp     ebx, BUF_SIZE-2
    jge     .rd
    mov     [rel linebuf+rbx], al
    inc     ebx
    jmp     .rd
.rd_done:
    mov     byte [rel linebuf+rbx], 0
    mov     rax, rbx
    pop     rbx
    ret
.rd_eof:
    test    ebx, ebx
    jz      .ret_eof
    mov     byte [rel linebuf+rbx], 0
    mov     rax, rbx
    pop     rbx
    ret
.ret_eof:
    mov     rax, -1
    pop     rbx
    ret

parse_and_exec:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r15, rdi
    call    skip_ws_r15

    cmp     word [r15], 'cd'
    jne     .not_cd
    movzx   eax, byte [r15+2]
    test    al, al
    jz      .cd_home
    cmp     al, ' '
    je      .cd_arg
    cmp     al, 0x09
    je      .cd_arg
    jmp     .not_cd
.cd_arg:
    lea     r15, [r15+3]
    call    skip_ws_r15
    mov     rdi, r15
    call    scan_word_r15
    jmp     .do_chdir
.cd_home:
    lea     rdi, [rel slash]
.do_chdir:
    mov     eax, SYS_chdir
    syscall
    test    rax, rax
    jns     .pae_ret
    mov     byte [last_exit], 1
    lea     rsi, [rel msg_cdfail]
    mov     edx, msg_cdfail_l
    call    errw
    jmp     .pae_ret
.not_cd:

    lea     rdi, [rel exit_str]
    call    has_prefix
    jne     .not_exit
    mov     byte [last_exit], 0
    xor     edi, edi
    mov     eax, SYS_exit
    syscall
.not_exit:

    mov     byte [bg_flag], 0
    xor     r12d, r12d
    mov     r13, r15
    mov     rbx, r15

.split:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .split_end
    cmp     al, '|'
    je      .split_here
    cmp     al, '&'
    jne     .split_next
    mov     byte [rbx], 0
    mov     byte [bg_flag], 1
    jmp     .split_end
.split_next:
    inc     rbx
    jmp     .split
.split_here:
    mov     byte [rbx], 0
    mov     [rel cmd_ptrs + r12*8], r13
    inc     r12
    cmp     r12, MAX_CMDS-1
    jge     .split_end
    inc     rbx
.skip_pipe_ws:
    movzx   eax, byte [rbx]
    cmp     al, ' '
    je      .spw1
    cmp     al, 0x09
    jne     .spw_done
.spw1:
    inc     rbx
    jmp     .skip_pipe_ws
.spw_done:
    mov     r13, rbx
    jmp     .split

.split_end:
    mov     [rel cmd_ptrs + r12*8], r13
    inc     r12

    cmp     r12, 1
    je      .single_stage
    call    exec_pipeline
    jmp     .pae_ret
.single_stage:
    mov     rsi, [rel cmd_ptrs]
    call    exec_cmd

.pae_ret:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

exec_pipeline:
    push    rbx
    push    rbp
    push    r13
    push    r14

    lea     rbp, [r12-1]

    xor     r14d, r14d
.mk_pipes:
    cmp     r14, rbp
    jge     .pipes_made
    lea     rdi, [rel pipes + r14*8]
    mov     eax, SYS_pipe
    syscall
    inc     r14
    jmp     .mk_pipes
.pipes_made:

    xor     r13d, r13d
.fork_loop:
    cmp     r13, r12
    jge     .parent_wait

    mov     eax, SYS_fork
    syscall
    test    rax, rax
    jz      .in_child
    mov     [rel pids + r13*8], rax
    inc     r13
    jmp     .fork_loop

.in_child:

    test    r13, r13
    jz      .no_in
    mov     rax, r13
    dec     rax
    lea     rdi, [rel pipes + rax*8]
    mov     edi, [rdi]
    xor     esi, esi
    mov     eax, SYS_dup2
    syscall
.no_in:

    lea     rax, [r13+1]
    cmp     rax, r12
    jge     .no_out
    lea     rdi, [rel pipes + r13*8]
    mov     edi, [rdi+4]
    mov     esi, STDOUT
    mov     eax, SYS_dup2
    syscall
.no_out:

    call    close_all_pipes
    mov     rsi, [rel cmd_ptrs + r13*8]
    call    exec_cmd
    movzx   edi, byte [last_exit]
    mov     eax, SYS_exit
    syscall

.parent_wait:
    call    close_all_pipes
    xor     r13d, r13d
.wloop:
    cmp     r13, r12
    jge     .ep_ret
    mov     edi, [rel pids + r13*8]
    mov     eax, SYS_wait4
    lea     rsi, [rel wstat]
    xor     edx, edx
    xor     r10d, r10d
    syscall
    movzx   eax, word [rel wstat]
    test    al, al
    jnz     .wnext
    movzx   eax, word [rel wstat]
    shr     eax, 8
    mov     [last_exit], al
.wnext:
    inc     r13
    jmp     .wloop
.ep_ret:
    pop     r14
    pop     r13
    pop     rbp
    pop     rbx
    ret

close_all_pipes:
    xor     r10, r10
.cap_loop:
    cmp     r10, rbp
    jge     .cap_done
    lea     rdi, [rel pipes + r10*8]
    mov     edi, [rdi]
    mov     eax, SYS_close
    syscall
    lea     rdi, [rel pipes + r10*8]
    mov     edi, [rdi+4]
    mov     eax, SYS_close
    syscall
    inc     r10
    jmp     .cap_loop
.cap_done:
    ret

exec_cmd:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r15, rsi
    call    skip_ws_r15
    xor     r12d, r12d
    xor     r13, r13
    xor     r14, r14
    mov     byte [append_mode], 0

.tok_loop:
    movzx   eax, byte [r15]
    test    al, al
    jz      .tok_done
    cmp     al, ' '
    je      .tok_ws
    cmp     al, 0x09
    je      .tok_ws
    cmp     al, '<'
    je      .tok_redir_in
    cmp     al, '>'
    je      .tok_redir_out
    cmp     al, '"'
    je      .tok_dquote
    cmp     al, 0x27
    je      .tok_squote

    call    record_arg
.bw_scan:
    movzx   eax, byte [r15]
    test    al, al
    jz      .bw_end_nul
    cmp     al, ' '
    je      .bw_end
    cmp     al, 0x09
    je      .bw_end
    cmp     al, '<'
    je      .bw_end
    cmp     al, '>'
    je      .bw_end
    inc     r15
    jmp     .bw_scan
.bw_end_nul:
    call    subst_last_arg
    jmp     .tok_done
.bw_end:
    mov     byte [r15], 0
    inc     r15
    call    subst_last_arg
    jmp     .tok_loop
.tok_ws:
    inc     r15
    jmp     .tok_loop

.tok_dquote:
    inc     r15
    call    record_arg
.dq_scan:
    movzx   eax, byte [r15]
    test    al, al
    jz      .tok_done
    cmp     al, '"'
    je      .dq_end
    inc     r15
    jmp     .dq_scan
.dq_end:
    mov     byte [r15], 0
    inc     r15
    jmp     .tok_loop

.tok_squote:
    inc     r15
    call    record_arg
.sq_scan:
    movzx   eax, byte [r15]
    test    al, al
    jz      .tok_done
    cmp     al, 0x27
    je      .sq_end
    inc     r15
    jmp     .sq_scan
.sq_end:
    mov     byte [r15], 0
    inc     r15
    jmp     .tok_loop

.tok_redir_in:
    inc     r15
    call    skip_ws_r15
    mov     r13, r15
    call    scan_word_r15
    jmp     .tok_loop

.tok_redir_out:
    inc     r15
    movzx   eax, byte [r15]
    cmp     al, '>'
    jne     .ro_single
    inc     r15
    mov     byte [append_mode], 1
.ro_single:
    call    skip_ws_r15
    mov     r14, r15
    call    scan_word_r15
    jmp     .tok_loop

.tok_done:
    mov     qword [rel argv_buf + r12*8], 0
    test    r12, r12
    jz      .ec_ret

    mov     rdi, [rel argv_buf]

    cmp     dword [rdi], 'echo'
    jne     .chk_pwd
    cmp     byte [rdi+4], 0
    jne     .chk_pwd
    xor     r8d, r8d
    jmp     .builtin_with_redir
.chk_pwd:
    cmp     dword [rdi], 'pwd'
    jne     .chk_true
    cmp     byte [rdi+3], 0
    jne     .chk_true
    mov     r8d, 1
    jmp     .builtin_with_redir
.chk_true:
    cmp     dword [rdi], 'true'
    jne     .chk_false
    cmp     byte [rdi+4], 0
    jne     .chk_false
    mov     r8d, 2
    jmp     .builtin_with_redir
.chk_false:
    cmp     dword [rdi], 'fals'
    jne     .external
    cmp     byte [rdi+4], 'e'
    jne     .external
    cmp     byte [rdi+5], 0
    jne     .external
    mov     r8d, 3

.builtin_with_redir:

    mov     dword [saved_stdin], -1
    mov     dword [saved_stdout], -1

    call    open_redirs
    test    eax, eax
    jnz     .open_fail

    cmp     dword [redir_in_fd], -1
    je      .bw_no_in
    xor     edi, edi
    mov     eax, SYS_dup
    syscall
    mov     [saved_stdin], eax
    mov     edi, [redir_in_fd]
    xor     esi, esi
    mov     eax, SYS_dup2
    syscall
    mov     edi, [redir_in_fd]
    mov     eax, SYS_close
    syscall
.bw_no_in:
    cmp     dword [redir_out_fd], -1
    je      .bw_no_out
    mov     edi, STDOUT
    mov     eax, SYS_dup
    syscall
    mov     [saved_stdout], eax
    mov     edi, [redir_out_fd]
    mov     esi, STDOUT
    mov     eax, SYS_dup2
    syscall
    mov     edi, [redir_out_fd]
    mov     eax, SYS_close
    syscall
.bw_no_out:

    cmp     r8d, 0
    jne     .bwd_pwd
    call    do_echo
    jmp     .builtin_restore
.bwd_pwd:
    cmp     r8d, 1
    jne     .bwd_true
    call    do_pwd
    jmp     .builtin_restore
.bwd_true:
    cmp     r8d, 2
    jne     .bwd_false
    mov     byte [last_exit], 0
    jmp     .builtin_restore
.bwd_false:
    mov     byte [last_exit], 1

.builtin_restore:
    cmp     dword [saved_stdin], -1
    je      .br_no_in
    mov     edi, [saved_stdin]
    xor     esi, esi
    mov     eax, SYS_dup2
    syscall
    mov     edi, [saved_stdin]
    mov     eax, SYS_close
    syscall
.br_no_in:
    cmp     dword [saved_stdout], -1
    je      .br_no_out
    mov     edi, [saved_stdout]
    mov     esi, STDOUT
    mov     eax, SYS_dup2
    syscall
    mov     edi, [saved_stdout]
    mov     eax, SYS_close
    syscall
.br_no_out:
    jmp     .ec_ret

.external:
    call    open_redirs
    test    eax, eax
    jnz     .open_fail

    mov     eax, SYS_fork
    syscall
    test    rax, rax
    jz      .ext_child
    js      .ext_fork_fail

    mov     r8, rax
    cmp     dword [redir_in_fd], -1
    je      .pf_no_in
    mov     edi, [redir_in_fd]
    mov     eax, SYS_close
    syscall
.pf_no_in:
    cmp     dword [redir_out_fd], -1
    je      .pf_no_out
    mov     edi, [redir_out_fd]
    mov     eax, SYS_close
    syscall
.pf_no_out:
    cmp     byte [bg_flag], 0
    jne     .ec_ret
    mov     edi, r8d
    mov     eax, SYS_wait4
    lea     rsi, [rel wstat]
    xor     edx, edx
    xor     r10d, r10d
    syscall
    movzx   eax, word [rel wstat]
    test    al, al
    jnz     .ec_ret
    movzx   eax, word [rel wstat]
    shr     eax, 8
    mov     [last_exit], al
    jmp     .ec_ret

.ext_fork_fail:
    mov     byte [last_exit], 1
    jmp     .ec_ret

.ext_child:
    cmp     dword [redir_in_fd], -1
    je      .ec_no_in
    mov     edi, [redir_in_fd]
    xor     esi, esi
    mov     eax, SYS_dup2
    syscall
    mov     edi, [redir_in_fd]
    mov     eax, SYS_close
    syscall
.ec_no_in:
    cmp     dword [redir_out_fd], -1
    je      .ec_no_out
    mov     edi, [redir_out_fd]
    mov     esi, STDOUT
    mov     eax, SYS_dup2
    syscall
    mov     edi, [redir_out_fd]
    mov     eax, SYS_close
    syscall
.ec_no_out:
    mov     rdi, [rel argv_buf]
    lea     rsi, [rel argv_buf]
    lea     rdx, [rel null_envp]
    mov     eax, SYS_execve
    syscall

    mov     rdi, [rel argv_buf]
    call    has_slash
    test    eax, eax
    jz      .exec_fail

    xor     r9d, r9d
.try_bin:
    cmp     r9, 3
    jge     .exec_fail
    lea     rdi, [rel pathbuf]
    mov     rsi, [rel path_table + r9*8]
    movzx   ecx, byte [rel path_lens + r9]
    rep movsb
    call    copy_cmd
    lea     rdi, [rel pathbuf]
    lea     rsi, [rel argv_buf]
    lea     rdx, [rel null_envp]
    mov     eax, SYS_execve
    syscall
    inc     r9
    jmp     .try_bin

.exec_fail:
    lea     rsi, [rel msg_notfound]
    mov     edx, msg_notfound_l
    call    errw
    mov     edi, 127
    mov     eax, SYS_exit
    syscall

.open_fail:
    mov     byte [last_exit], 1
    lea     rsi, [rel msg_openfail]
    mov     edx, msg_openfail_l
    call    errw
    jmp     .ec_ret

.ec_ret:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

scan_word_r15:
.sw_scan:
    movzx   eax, byte [r15]
    test    al, al
    jz      .sw_end
    cmp     al, ' '
    je      .sw_end
    cmp     al, 0x09
    je      .sw_end
    inc     r15
    jmp     .sw_scan
.sw_end:
    mov     byte [r15], 0
    inc     r15
    ret

record_arg:
    cmp     r12, MAX_ARGS-1
    jge     .ra_skip
    lea     rdi, [rel argv_buf + r12*8]
    mov     [rdi], r15
    inc     r12
.ra_skip:
    ret

do_echo:
    push    rbx
    push    rbp
    mov     rbp, r12
    dec     rbp
    mov     rbx, 1
.echo_loop:
    test    rbp, rbp
    jz      .echo_nl
    mov     rsi, [rel argv_buf + rbx*8]
    call    strlen0
.echo_have_len:
    mov     edi, STDOUT
    call    wr
    dec     rbp
    jz      .echo_nl
    mov     edi, STDOUT
    lea     rsi, [rel spc]
    mov     edx, 1
    call    wr
    inc     rbx
    jmp     .echo_loop
.echo_nl:
    mov     edi, STDOUT
    lea     rsi, [rel nl]
    mov     edx, 1
    call    wr
    mov     byte [last_exit], 0
    pop     rbp
    pop     rbx
    ret

do_pwd:
    mov     eax, SYS_getcwd
    lea     rdi, [rel cwdbuf]
    mov     rsi, 512
    syscall
    test    rax, rax
    jle     .dp_ret
    lea     rsi, [rel cwdbuf]
    call    strlen0
.pwd_have:
    mov     edi, STDOUT
    call    wr
    mov     edi, STDOUT
    lea     rsi, [rel nl]
    mov     edx, 1
    call    wr
    mov     byte [last_exit], 0
.dp_ret:
    ret

skip_ws_rsi:
.lp:
    movzx   eax, byte [rsi]
    cmp     al, ' '
    je      .s
    cmp     al, 0x09
    jne     .done
.s:
    inc     rsi
    jmp     .lp
.done:
    ret

skip_ws_r15:
    mov     rsi, r15
    call    skip_ws_rsi
    mov     r15, rsi
    ret

has_prefix:
    push    rsi
    push    rcx
    mov     rsi, r15
.lp:
    movzx   eax, byte [rdi]
    test    al, al
    jz      .match
    movzx   ecx, byte [rsi]
    cmp     al, cl
    jne     .nomatch
    inc     rdi
    inc     rsi
    jmp     .lp
.match:
    pop     rcx
    pop     rsi
    xor     eax, eax
    ret
.nomatch:
    pop     rcx
    pop     rsi
    mov     eax, 1
    ret

copy_cmd:
    mov     rsi, [rel argv_buf]
.cc_loop:
    movzx   eax, byte [rsi]
    test    al, al
    jz      .cc_done
    mov     [rdi], al
    inc     rsi
    inc     rdi
    jmp     .cc_loop
.cc_done:
    mov     byte [rdi], 0
    ret

errw:
    mov     edi, STDERR
    jmp     wr

strlen0:
    xor     edx, edx
.sl_loop:
    cmp     byte [rsi+rdx], 0
    je      .sl_done
    inc     edx
    jmp     .sl_loop
.sl_done:
    ret

wr:
    mov     eax, SYS_write
    syscall
    ret

has_slash:
    push    rsi
    mov     rsi, rdi
.lp:
    movzx   eax, byte [rsi]
    test    al, al
    jz      .none
    cmp     al, '/'
    je      .found
    inc     rsi
    jmp     .lp
.found:
    pop     rsi
    xor     eax, eax
    ret
.none:
    pop     rsi
    mov     eax, 1
    ret

open_redirs:
    mov     dword [redir_in_fd], -1
    mov     dword [redir_out_fd], -1

    test    r13, r13
    jz      .or_no_in
    mov     eax, SYS_open
    mov     rdi, r13
    xor     esi, esi
    syscall
    test    rax, rax
    js      .or_fail
    mov     [redir_in_fd], eax
.or_no_in:
    test    r14, r14
    jz      .or_no_out
    mov     eax, SYS_open
    mov     rdi, r14
    cmp     byte [append_mode], 0
    je      .or_trunc
    mov     esi, O_WRONLY|O_CREAT|O_APPEND
    jmp     .or_doopen
.or_trunc:
    mov     esi, O_WRONLY|O_CREAT|O_TRUNC
.or_doopen:
    mov     edx, 0644o
    syscall
    test    rax, rax
    js      .or_fail
    mov     [redir_out_fd], eax
.or_no_out:
    xor     eax, eax
    ret
.or_fail:
    mov     eax, 1
    ret

exec_line:
    push    r12
    push    r13
    push    r14

    mov     r12, rdi
    mov     r13b, 1
    call    .el_check_block

.el_scan:
    movzx   eax, byte [r14]
    test    al, al
    jz      .el_last
    cmp     al, ';'
    je      .el_semi
    cmp     al, '&'
    je      .el_amp
    cmp     al, '|'
    je      .el_pipe
    inc     r14
    jmp     .el_scan

.el_amp:
    cmp     byte [r14+1], '&'
    jne     .el_lone_amp
    mov     byte [r14], 0
    call    .el_run
    cmp     byte [rel last_exit], 0
    sete    r13b
    add     r14, 2
    jmp     .el_skipws
.el_lone_amp:
    inc     r14
    jmp     .el_scan

.el_pipe:
    cmp     byte [r14+1], '|'
    jne     .el_lone_pipe
    mov     byte [r14], 0
    call    .el_run
    cmp     byte [rel last_exit], 0
    setne   r13b
    add     r14, 2
    jmp     .el_skipws
.el_lone_pipe:
    inc     r14
    jmp     .el_scan

.el_semi:
    mov     byte [r14], 0
    call    .el_run
    mov     r13b, 1
    inc     r14
    jmp     .el_skipws

.el_skipws:
    movzx   eax, byte [r14]
    cmp     al, ' '
    je      .el_ws1
    cmp     al, 0x09
    jne     .el_wsdone
.el_ws1:
    inc     r14
    jmp     .el_skipws
.el_wsdone:
    mov     r12, r14
    cmp     byte [r14], 0
    jz      .el_ret
    call    .el_check_block
    jmp     .el_scan

.el_last:
    call    .el_run
    jmp     .el_ret

.el_check_block:
    mov     rdi, r12
    lea     rsi, [rel kw_if]
    call    starts_with_word
    test    eax, eax
    jnz     .elcb_if
    mov     rdi, r12
    lea     rsi, [rel kw_for]
    call    starts_with_word
    test    eax, eax
    jnz     .elcb_for
    mov     r14, r12
    ret
.elcb_if:
    lea     rdi, [r12+3]
    lea     rsi, [rel kw_fi]
    call    find_word
    test    rax, rax
    jz      .elcb_noend
    lea     r14, [rax+2]
    ret
.elcb_for:
    lea     rdi, [r12+4]
    lea     rsi, [rel kw_done]
    call    find_word
    test    rax, rax
    jz      .elcb_noend
    lea     r14, [rax+4]
    ret
.elcb_noend:
    mov     r14, r12
.elcb_scan:
    movzx   eax, byte [r14]
    test    al, al
    jz      .elcb_ret
    inc     r14
    jmp     .elcb_scan
.elcb_ret:
    ret

.el_run:
    cmp     r13b, 0
    je      .elr_ret
    mov     rsi, r12
    call    skip_ws_rsi
    mov     r12, rsi
    movzx   eax, byte [rsi]
    test    al, al
    jz      .elr_ret
    cmp     al, '#'
    je      .elr_ret
    mov     rdi, rsi
    call    exec_stmt
.elr_ret:
    ret

.el_ret:
    pop     r14
    pop     r13
    pop     r12
    ret

exec_stmt:
    push    rdi
    mov     rdi, [rsp]
    lea     rsi, [rel kw_if]
    call    starts_with_word
    test    eax, eax
    jz      .es_not_if
    pop     rdi
    add     rdi, 3
    jmp     exec_if
.es_not_if:
    mov     rdi, [rsp]
    lea     rsi, [rel kw_for]
    call    starts_with_word
    test    eax, eax
    jz      .es_not_for
    pop     rdi
    add     rdi, 4
    jmp     exec_for
.es_not_for:
    pop     rdi
    jmp     parse_and_exec

starts_with_word:
.sw_loop:
    movzx   eax, byte [rsi]
    test    al, al
    jz      .sw_boundary
    movzx   ecx, byte [rdi]
    cmp     al, cl
    jne     .sw_no
    inc     rdi
    inc     rsi
    jmp     .sw_loop
.sw_boundary:
    movzx   eax, byte [rdi]
    cmp     al, ' '
    je      .sw_yes
    cmp     al, 0x09
    je      .sw_yes
    test    al, al
    jz      .sw_yes
    jmp     .sw_no
.sw_yes:
    mov     eax, 1
    ret
.sw_no:
    xor     eax, eax
    ret

find_word:
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
.fw_outer:
    movzx   eax, byte [r12]
    test    al, al
    jz      .fw_notfound
    mov     rbx, r12
    mov     r13, rsi
.fw_cmp:
    movzx   eax, byte [r13]
    test    al, al
    jz      .fw_matchend
    movzx   ecx, byte [rbx]
    cmp     al, cl
    jne     .fw_nomatch
    inc     rbx
    inc     r13
    jmp     .fw_cmp
.fw_matchend:
    movzx   eax, byte [rbx]
    test    al, al
    jz      .fw_boundok
    cmp     al, ' '
    je      .fw_boundok
    cmp     al, 0x09
    je      .fw_boundok
    cmp     al, ';'
    je      .fw_boundok
    jmp     .fw_nomatch
.fw_boundok:
    cmp     r12, rdi
    je      .fw_found
    mov     al, [r12-1]
    cmp     al, ' '
    je      .fw_found
    cmp     al, 0x09
    je      .fw_found
    cmp     al, ';'
    je      .fw_found
.fw_nomatch:
    inc     r12
    jmp     .fw_outer
.fw_found:
    mov     rax, r12
    pop     r13
    pop     r12
    pop     rbx
    ret
.fw_notfound:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    ret

term_trim:
    mov     byte [rsi], 0
    dec     rsi
.tt_loop:
    cmp     rsi, rdi
    jl      .tt_done
    movzx   eax, byte [rsi]
    cmp     al, ' '
    je      .tt_null
    cmp     al, 0x09
    je      .tt_null
    cmp     al, ';'
    je      .tt_null
    jmp     .tt_done
.tt_null:
    mov     byte [rsi], 0
    dec     rsi
    jmp     .tt_loop
.tt_done:
    ret

exec_if:
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi

    lea     rsi, [rel kw_then]
    mov     rdi, r12
    call    find_word
    test    rax, rax
    jz      .eif_syntax
    mov     r13, rax

    lea     rdi, [r13+4]
    lea     rsi, [rel kw_fi]
    call    find_word
    test    rax, rax
    jz      .eif_syntax
    mov     r14, rax

    lea     rdi, [r13+4]
    lea     rsi, [rel kw_else]
    call    find_word
    test    rax, rax
    jz      .eif_no_else
    cmp     rax, r14
    jae     .eif_no_else
    mov     rbx, rax
    jmp     .eif_have_else
.eif_no_else:
    xor     rbx, rbx
.eif_have_else:

    mov     rdi, r12
    mov     rsi, r13
    call    term_trim

    mov     rdi, r12
    call    exec_line

    test    rbx, rbx
    jnz     .eif_has_else_branch

    movzx   eax, byte [rel last_exit]
    test    al, al
    jnz     .eif_false_noelse
    lea     rdi, [r13+4]
    mov     rsi, r14
    call    term_trim
    lea     rdi, [r13+4]
    call    exec_line
    jmp     .eif_ret
.eif_false_noelse:
    mov     byte [rel last_exit], 0
    jmp     .eif_ret

.eif_has_else_branch:
    movzx   eax, byte [rel last_exit]
    test    al, al
    jnz     .eif_run_else
    lea     rdi, [r13+4]
    mov     rsi, rbx
    call    term_trim
    lea     rdi, [r13+4]
    call    exec_line
    jmp     .eif_ret
.eif_run_else:
    lea     rdi, [rbx+4]
    mov     rsi, r14
    call    term_trim
    lea     rdi, [rbx+4]
    call    exec_line
    jmp     .eif_ret

.eif_syntax:
    mov     byte [rel last_exit], 1
    lea     rsi, [rel msg_ifsyn]
    mov     edx, msg_ifsyn_l
    call    errw
.eif_ret:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

exec_for:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    lea     rbx, [rel for_var_name]
    xor     ecx, ecx
.efv_loop:
    movzx   eax, byte [rdi]
    test    al, al
    jz      .efor_syntax
    cmp     al, ' '
    je      .efv_done
    cmp     al, 0x09
    je      .efv_done
    cmp     ecx, 30
    jge     .efv_skip
    mov     [rbx+rcx], al
    inc     ecx
.efv_skip:
    inc     rdi
    jmp     .efv_loop
.efv_done:
    mov     byte [rbx+rcx], 0

    mov     rsi, rdi
    call    skip_ws_rsi
    mov     rdi, rsi

    lea     rsi, [rel kw_in]
    call    starts_with_word
    test    eax, eax
    jz      .efor_syntax
    mov     rsi, rdi
    call    skip_ws_rsi
    mov     rdi, rsi

    mov     r12, rdi

    lea     rsi, [rel kw_do]
    call    find_word
    test    rax, rax
    jz      .efor_syntax
    mov     r13, rax

    lea     rdi, [r13+2]
    lea     rsi, [rel kw_done]
    call    find_word
    test    rax, rax
    jz      .efor_syntax
    mov     r14, rax

    mov     rdi, r12
    mov     rsi, r13
    call    term_trim

    lea     rax, [r13+2]
    mov     rsi, rax
    call    skip_ws_rsi
    mov     r15, rsi

    mov     rdi, r15
    mov     rsi, r14
    call    term_trim

    lea     rdi, [rel for_body_tpl]
    mov     rsi, r15
.efb_cpy:
    movzx   eax, byte [rsi]
    mov     [rdi], al
    test    al, al
    jz      .efb_cpy_done
    inc     rsi
    inc     rdi
    jmp     .efb_cpy
.efb_cpy_done:

    xor     r8d, r8d
    mov     rbx, r12
.efor_iter:
    mov     rsi, rbx
    call    skip_ws_rsi
    mov     rbx, rsi
    movzx   eax, byte [rbx]
    test    al, al
    jz      .efor_finished

    mov     r9, rbx
.efor_wscan:
    movzx   eax, byte [r9]
    test    al, al
    jz      .efor_wend
    cmp     al, ' '
    je      .efor_wend
    cmp     al, 0x09
    je      .efor_wend
    inc     r9
    jmp     .efor_wscan
.efor_wend:
    mov     cl, [r9]
    mov     byte [r9], 0
    mov     r8b, 1

    lea     rdi, [rel for_var_name]
    mov     rsi, rbx
    call    var_set

    lea     rdi, [rel for_body_work]
    lea     rsi, [rel for_body_tpl]
.efb_cpy2:
    movzx   eax, byte [rsi]
    mov     [rdi], al
    test    al, al
    jz      .efb_cpy2_done
    inc     rsi
    inc     rdi
    jmp     .efb_cpy2
.efb_cpy2_done:
    lea     rdi, [rel for_body_work]
    call    exec_line

    mov     [r9], cl
    test    cl, cl
    jz      .efor_finished
    mov     rbx, r9
    inc     rbx
    jmp     .efor_iter

.efor_finished:
    test    r8b, r8b
    jnz     .efor_ret
    mov     byte [rel last_exit], 0
    jmp     .efor_ret

.efor_syntax:
    mov     byte [rel last_exit], 1
    lea     rsi, [rel msg_forsyn]
    mov     edx, msg_forsyn_l
    call    errw
.efor_ret:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

gen_streq:
.gs_loop:
    movzx   eax, byte [rdi]
    movzx   ecx, byte [rsi]
    cmp     al, cl
    jne     .gs_ne
    test    al, al
    jz      .gs_eq
    inc     rdi
    inc     rsi
    jmp     .gs_loop
.gs_eq:
    mov     eax, 1
    ret
.gs_ne:
    xor     eax, eax
    ret

var_lookup:
    push    rbx
    push    r8
    push    rdi
    xor     r8d, r8d
.vlk_loop:
    cmp     r8d, 8
    jge     .vlk_none
    mov     rbx, r8
    imul    rbx, rbx, 16
    lea     rbx, [rel var_names + rbx]
    movzx   eax, byte [rbx]
    test    al, al
    jz      .vlk_next
    mov     rsi, [rsp]
    mov     rdi, rbx
    call    gen_streq
    test    eax, eax
    jz      .vlk_next
    mov     rbx, r8
    imul    rbx, rbx, 64
    lea     rax, [rel var_values + rbx]
    pop     rdi
    pop     r8
    pop     rbx
    ret
.vlk_next:
    inc     r8d
    jmp     .vlk_loop
.vlk_none:
    xor     eax, eax
    pop     rdi
    pop     r8
    pop     rbx
    ret

copy_str_bounded:
    xor     ecx, ecx
.csb_loop:
    cmp     ecx, r10d
    jge     .csb_term
    movzx   eax, byte [rsi+rcx]
    test    al, al
    jz      .csb_term
    mov     [rdi+rcx], al
    inc     ecx
    jmp     .csb_loop
.csb_term:
    mov     byte [rdi+rcx], 0
    ret

var_set:
    push    rdi
    push    rsi
    push    rbx
    push    r8
    push    r9

    mov     r9, -1
    xor     r8d, r8d
.vs_loop:
    cmp     r8d, 8
    jge     .vs_after
    mov     rbx, r8
    imul    rbx, rbx, 16
    lea     rbx, [rel var_names + rbx]
    movzx   eax, byte [rbx]
    test    al, al
    jnz     .vs_check
    cmp     r9, -1
    jne     .vs_next
    mov     r9, r8
    jmp     .vs_next
.vs_check:
    mov     rdi, rbx
    mov     rsi, [rsp+32]
    call    gen_streq
    test    eax, eax
    jz      .vs_next
    jmp     .vs_write
.vs_next:
    inc     r8d
    jmp     .vs_loop
.vs_after:
    cmp     r9, -1
    jne     .vs_use_r9
    mov     r9, 0
.vs_use_r9:
    mov     r8, r9
.vs_write:
    mov     rbx, r8
    imul    rbx, rbx, 16
    lea     rdi, [rel var_names + rbx]
    mov     rsi, [rsp+32]
    mov     r10d, 15
    call    copy_str_bounded
    mov     rbx, r8
    imul    rbx, rbx, 64
    lea     rdi, [rel var_values + rbx]
    mov     rsi, [rsp+24]
    mov     r10d, 63
    call    copy_str_bounded

    pop     r9
    pop     r8
    pop     rbx
    pop     rsi
    pop     rdi
    ret

subst_last_arg:
    push    rax
    push    rcx
    push    rsi
    push    rdi
    push    r8
    push    r9
    push    r10

    mov     r8, r12
    dec     r8
    lea     rdi, [rel argv_buf + r8*8]
    mov     rsi, [rdi]
    movzx   eax, byte [rsi]
    cmp     al, '$'
    jne     .sla_ret

    lea     rsi, [rsi+1]
    mov     r9, rdi
    mov     rdi, rsi
    call    var_lookup
    test    rax, rax
    jnz     .sla_haveval
    lea     rax, [rel empty_str]
.sla_haveval:
    mov     rsi, rax
    mov     r10, r8
    imul    r10, r10, 64
    lea     rdi, [rel varsub_buf + r10]
    mov     r10, rdi
.sla_copy:
    movzx   eax, byte [rsi]
    mov     [rdi], al
    test    al, al
    jz      .sla_copied
    inc     rsi
    inc     rdi
    jmp     .sla_copy
.sla_copied:
    mov     [r9], r10
.sla_ret:
    pop     r10
    pop     r9
    pop     r8
    pop     rdi
    pop     rsi
    pop     rcx
    pop     rax
    ret

section .data
kw_if:          db "if",0
kw_for:         db "for",0
kw_then:        db "then",0
kw_else:        db "else",0
kw_fi:          db "fi",0
kw_in:          db "in",0
kw_do:          db "do",0
kw_done:        db "done",0
empty_str:      db 0
msg_ifsyn:      db "sh: if: sintaxe (precisa then/fi)",0x0a
msg_ifsyn_l:    equ $-msg_ifsyn
msg_forsyn:     db "sh: for: sintaxe (precisa in/do/done)",0x0a
msg_forsyn_l:   equ $-msg_forsyn
prompt:         db "$ "
msg_nofile:     db "sh: cannot open script",0x0a
msg_nofile_l:   equ $-msg_nofile
msg_cdfail:     db "cd: no such directory",0x0a
msg_cdfail_l:   equ $-msg_cdfail
msg_notfound:   db "sh: command not found",0x0a
msg_notfound_l: equ $-msg_notfound
msg_openfail:   db "sh: cannot open file",0x0a
msg_openfail_l: equ $-msg_openfail
exit_str:       db "exit",0
slash:          db "/",0
spc:            db 0x20
nl:             db 0x0a
path_bin:       db "/bin/"
path_bin_l:     equ $-path_bin
path_usrbin:    db "/usr/bin/"
path_usrbin_l:  equ $-path_usrbin
path_sbin:      db "/sbin/"
path_sbin_l:    equ $-path_sbin
path_table:     dq path_bin, path_usrbin, path_sbin
path_lens:      db path_bin_l, path_usrbin_l, path_sbin_l
null_envp:      dq 0

section .bss
linebuf:      resb BUF_SIZE
charbuf:      resb 1
script_fd:    resd 1
is_script:    resb 1
last_exit:    resb 1
bg_flag:      resb 1
append_mode:  resb 1
cmd_ptrs:     resq MAX_CMDS+1
pipes:        resd (MAX_CMDS*2)
pids:         resq MAX_CMDS
wstat:        resd 1
argv_buf:     resq MAX_ARGS+1
redir_in_fd:  resd 1
redir_out_fd: resd 1
cwdbuf:       resb 512
pathbuf:      resb 512
saved_stdin:  resd 1
saved_stdout: resd 1
var_names:    resb 8*16
var_values:   resb 8*64
varsub_buf:   resb MAX_ARGS*64
for_var_name: resb 32
for_body_tpl: resb 1024
for_body_work:resb 1024

