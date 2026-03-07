format binary as ""

use32
org 0


db 'MENUET01'
dd 1
dd START
dd I_END
dd MEM
dd STACKTOP
dd 00
dd 00

parameters rb 256
include 'proc32.inc'
include 'macros.inc'
include 'dll.inc'
include 'string.inc'

align 16
@IMPORT:
library  terminal, 'console.obj'

import terminal, \
        con_init, 'con_init', \
        con_exit, 'con_exit', \
        con_gets, 'con_gets', \
        con_write, 'con_write_asciiz', \
        con_clear, 'con_cls', \
        con_getc,  'con_getch', \
        con_write_string, 'con_write_string', \
        con_printf,  'con_printf'


@pid dd 0
include 'shell.inc'

; a brainfuck interpreter 
; data definitions

BUFFER_SIZE = (2 shl 16)
TAPE_SIZE  = 30000

buffer_data rb BUFFER_SIZE
tape rb TAPE_SIZE

Ops rb BUFFER_SIZE / 2 ; use half of buffer size
arg rd BUFFER_SIZE / 2 ; use half of buffer size
prompt db "BF:> ", 0
TITLE db "                       BRAINFUCK INTERPRETER  ",0
err1 db "Missing parenthesis match",0
err2 db "Invalid source file",0
REPL db "in repl",10, 0
exit_cmd db "exit", 0
run_cmd  db "run", 0
run_cmd_space db "run "
clear_cmd db "clear", 0
help_cmd  db "help", 0

helps db "A Brainfuck Interpreter"

ERR_SIZE = 36
ERR2_SIZE = 30
nl db 10, 0

macro write2 a {
        local ..string, ..label
        jmp   ..label
..string db a, 0
..label:
        invoke con_write, ..string
}

macro write a {
        local ..string, ..label
        jmp   ..label
..string db a, 10, 0
..label:
        invoke con_write, ..string
}
align 4

file_info_struct:
   .fn dd 0
   .offset dd 0
   .offset2 dd 0
   .size dd 0
   .ptr dd 0
   .ecd db 0
   .path dd 0

macro DISPATCH {
        movzx  eax, byte [ebp+ecx]
        mov    ebx, ecx
        inc    ecx
        jmp    dword [jmp_table + eax *4]
}


jmp_table:
        dd exit_interpret
        rept 42{
          dd BEGIN
        }
        dd vinc
        dd input
        dd vdec
        dd output
        rept 13 {
           dd BEGIN
        }
        dd pdec
        dd BEGIN
        dd pinc
        rept 28 {
          dd BEGIN 
        }
        dd brac_left
        dd BEGIN
        dd brac_right
        rept 34 {
           dd BEGIN
        }

START:
        mcall   68, 11
        stdcall dll.Load, @IMPORT
        or      eax, eax
        jnz     EXIT
        invoke  con_init, 80, 120, -1, -1, TITLE

repl:
        invoke  con_write, prompt
        invoke  con_gets, buffer_data, BUFFER_SIZE
        stdcall string.length, buffer_data
        mov     [buffer_data + eax -1], 0

        stdcall string.cmp, buffer_data, exit_cmd, 5 ; check if exit, length 5 to make sure it is only exit
        test    eax, eax
        jz      exit 

        stdcall string.cmp, buffer_data, clear_cmd, 6
        test    eax, eax
        jz      .clear 

        stdcall string.cmp, buffer_data, run_cmd_space, 4
        test    eax, eax
        jz      .run_prog

        stdcall  string.cmp, buffer_data, help_cmd, 5
        test     eax, eax
        jz       .display_help

        call    interpret
        invoke  con_write, nl
        jmp     repl

.clear:
        invoke  con_clear 
        jmp     repl

.display_help:
        invoke  con_write, helps
        jmp     repl

.run_prog:
; assume command is in format run filepath
        lea     eax, [buffer_data + 4]
        stdcall string.copy, eax, parameters
        mov     esi, parameters
        ; first get_file size

        mov     eax, 70
        mov     dword [file_info_struct], 0x0
        mov     dword [file_info_struct + 12], BUFFER_SIZE-1
        mov     dword [file_info_struct + 16], buffer_data
        mov     dword [file_info_struct + 21], parameters
        mov     ebx, file_info_struct
        mcall

        test    eax, eax
        jnz     .check_eof

.process_buffer:
        mov     [buffer_data + ebx], byte 0
        call    interpret
        jmp     repl

.check_eof:
        cmp     eax, 6
        je      .process_buffer

.run_error:
        write2  "Error opening file: "
        invoke  con_write, parameters
        invoke  con_write, nl
        jmp     repl
        
.not_run:
        write   "Invalid run Command. Use run file_path"
        jmp     repl

        
; interpret  a brainfuck program
interpret:
    ;ecx -> ip, edx -> dp, esi => bracket depth, edi -> tape
        ; shps  "In interpet"
        write  "In Interpret function"
        call   preprocess

        cmp    eax, -1 
        je     .match_error

        xor    ecx, ecx
        xor    edx, edx
        xor    esi, esi
        mov    edi, tape
        mov    ebp, Ops

        DISPATCH

.match_error:
        write  "Match error found" 
        ret

exit_interpret:
        ret

BEGIN: 
        DISPATCH
vinc:
        mov    eax, dword [arg + ebx * 4]
        add    byte [edi + edx], al
        DISPATCH

vdec:
        mov    eax, [arg + ebx * 4]
        sub    byte [edi + edx], al
        DISPATCH

pinc:
        add    edx, [arg + ebx * 4]
        cmp    edx, TAPE_SIZE
        jl     .dispatch
        sub   edx, TAPE_SIZE
.dispatch:
        DISPATCH

pdec:
        sub   edx, [arg + ebx * 4]
        jns    .dispatch
        add     edx, TAPE_SIZE
.dispatch:
        DISPATCH


output:
        pusha
        mov    ebx, [arg + ebx *4]
.loop:
        lea    eax, [edi + edx]
        test   ebx, ebx
        je     .dispatch
        dec    ebx
        invoke con_write_string, eax, 1
        jmp    .loop
.dispatch:
        popa
        DISPATCH

input:
        pusha
        invoke  con_getc
        mov    [edi + edx], al
        popa
        DISPATCH

brac_left:
        cmp    byte [edi + edx], 0
        jne    .dispatch
        mov    ecx, [arg + ebx * 4]
.dispatch:
        DISPATCH

brac_right:
        mov    al, byte [edi + edx]
        test   al, al
        jz     .dispatch
        mov    ecx,  [arg + ebx * 4]
.dispatch:
        DISPATCH

preprocess:
; esi as ptr for buffer, ebx as buffer reference
; edi as pointer to Ops and arg
        write "in preprocess"
        push   ebp
        mov    ebp, esp
        mov    ebx, buffer_data 
        xor    esi, esi
        xor    edi, edi
        xor    edx, edx

.start:
        movzx  eax, byte [ebx + esi]
        inc    esi 
        test   eax, eax
        je     .exit
        cmp    eax, 127
        jg     .start
        mov    ecx, dword [jmp_table + eax * 4]
        cmp    ecx, BEGIN
        je     .start
        cmp    eax, '['
        je     .left
        cmp    eax, ']'
        je    .right
        jmp    .repeat

.left:
        inc    edx
        push   edi
        mov    byte [Ops + edi], al
        inc    edi
        jmp    .start

.right:
        test   edx, edx
        je     .error
        dec    edx
        pop    ecx
        mov    [Ops + edi], al
        mov    [arg + edi * 4], ecx
        inc    [arg + edi * 4]
        inc    edi
        mov    [arg + ecx * 4], edi
        jmp    .start

.repeat:
        mov    ecx, 1
.start_repeat:
        cmp    al, byte [ebx + esi]
        jne    .end_repeat
        inc    ecx
        inc    esi
        jmp    .start_repeat

.end_repeat:
        mov    [Ops + edi], al
        mov    [arg + edi *4], ecx
        inc    edi
        jmp     .start

.error:
        mov   eax, -1
        leave
        ret
.exit:
        xor    eax, eax
        mov    byte [Ops + edi], 0
        leave
        ret

exit: 
        invoke con_exit, 1
EXIT:
        mov    eax, -1
        int    0x40
I_END:
    rb 4096
align 16
STACKTOP:
MEM:
