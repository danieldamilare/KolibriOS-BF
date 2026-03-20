;-----------------------------------------------------------
; Brainfuck Interpreter for KolibriOS
; 
; Interactive REPL 
; Uses console.obj for terminal interface
;
;-----------------------------------------------------------

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

include '../includes/proc32.inc'
include '../includes/macros.inc'
include '../includes/dll.inc'
include '../includes/string.inc'

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


; a brainfuck interpreter 

ERR_SIZE = 36
ERR2_SIZE = 30

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

macro flush {
        pusha
        invoke  con_write_string, output_buf, dword [output_buf_idx]
        mov     dword [output_buf_idx], 0
        popa
}

; line buffering 
macro bf_write{
local   .store, .done
        cmp     dword [output_buf_idx], OUTPUT_BUF_LEN
        jb      .store
        flush
.store:
        mov     ebx, [output_buf_idx]
        mov     [output_buf + ebx], al
        inc     [output_buf_idx]
        cmp     al, 10
        jne     .done
        flush
.done:
}

macro bf_getc{
        invoke con_getc
}

include 'bf_core.inc'

align 4

file_info_struct:
   .fn dd 0
   .offset dd 0
   .offset2 dd 0
   .size dd 0
   .ptr dd 0
   .ecd db 0
   .path dd 0

START:
        mcall   68, 11
        stdcall dll.Load, @IMPORT
        or      eax, eax
        jnz     EXIT
        invoke  con_init, -1, -1, -1, -1, TITLE

repl:
        ; write   "Checking if there is data to flush"
        mov     eax, [output_buf_idx]
        test    eax, eax
        jz      .prompt
        flush

.prompt:
        invoke  con_write, prompt
        invoke  con_gets, buffer_data, BUFFER_SIZE
        test    eax, eax ; documentation said eax is zero when console is closed
        jz      exit

        stdcall string.length, buffer_data

        cmp     eax, BUFFER_SIZE
        je      .repl_continue
        lea     ebx, [buffer_data + eax - 1]
        mov     byte [ebx], 0

.repl_continue:
        mov     ebx, repl_table
.loop:
        cmp     dword[ebx], 0
        jz      .default
        stdcall string.cmp, buffer_data, dword [ebx], dword [ebx+4]
        test    eax, eax
        jnz     .next
        jmp      dword [ebx + 8]

.next:
        add     ebx, 12
        jmp     .loop

.default:
        call    interpret
        invoke  con_write, nl
        jmp     repl

.clear:
        invoke  con_clear 
        jmp     repl

.reset:
        cld
        mov     ecx, TAPE_SIZE
        xor     eax, eax
        mov     edi, tape
        rep     stosb
        jmp     repl

        
.display_help:
        invoke  con_write, help_text
        jmp     repl

.run_prog:
; assume command is in format run filepath
        lea     eax, [buffer_data + 4]
        stdcall string.copy, eax, parameters
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
        mov     byte [buffer_data + ebx],  0
        call    interpret
        invoke  con_write, nl
        flush
        ; write   "Finish flushing..."
        jmp     .reset    ; reset tape after reading from file

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

exit: 
        invoke  con_exit, 1
EXIT:
        mov     eax, -1
        int     0x40
I_END:
; data definitions
BUFFER_SIZE = (2 shl 16)
TAPE_SIZE  = 30000
OUTPUT_BUF_LEN = 512
output_buf_idx dd 0

prompt db "BF:> ", 0
TITLE db "                       BRAINFUCK INTERPRETER  ",0
err1 db "Missing parenthesis match",0
err2 db "Invalid source file",0
REPL db "in repl",10, 0
exit_cmd db "exit", 0
run_cmd db "run "
clear_cmd db "clear", 0
help_cmd  db "help", 0
reset_cmd db "reset", 0

help_text:
    db "BRAINFUCK INTERPRETER - HELP", 10
    db "========================", 10, 10
    db "COMMANDS:", 10
    db "  help          - show this help", 10
    db "  clear         - clear the screen", 10
    db "  reset         - clear the tape: set all cell as 0", 10
    db "  run <file>    - run a brainfuck file", 10
    db "  exit          - exit the interpreter", 10, 10
    db "NOTES:", 10
    db "  - tape is persistent across REPL sessions", 10
    db "  - use reset to clear tape between programs", 10
    db "  - tape size is 30000 cells", 10
    db "  - cells are 8-bit with wraparound", 10, 10
    db "BRAINFUCK COMMANDS:", 10
    db "  >  move tape pointer right", 10
    db "  <  move tape pointer left", 10
    db "  +  increment current cell", 10
    db "  -  decrement current cell", 10
    db "  .  output current cell as ASCII", 10
    db "  ,  read one character into current cell", 10
    db "  [  jump forward if current cell is zero", 10
    db "  ]  jump back if current cell is non-zero", 10, 0

nl db 10, 0

repl_table:
        dd exit_cmd, 5, exit
        dd clear_cmd, 6, repl.clear  
        dd run_cmd, 4, repl.run_prog
        dd help_cmd, 5, repl.display_help
        dd reset_cmd, 6, repl.reset
        dd 0

; --------- STACK END-----------
    rb 4096
align 16

STACKTOP:

buffer_data rb BUFFER_SIZE
tape rb TAPE_SIZE

Ops rb BUFFER_SIZE / 2 ; use half of buffer size
arg rd BUFFER_SIZE / 2 ; use half of buffer size
output_buf rb OUTPUT_BUF_LEN
parameters rb 256
MEM:
