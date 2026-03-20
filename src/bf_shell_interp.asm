format binary as ""

use32
org 0


db 'MENUET01'
dd 1
dd START
dd I_END
dd MEM
dd STACKTOP
dd parameters
dd 00

parameters rb 1024

include '../includes/proc32.inc'
include '../includes/macros.inc'
include '../includes/shell.inc'
include '../includes/string.inc'

@pid dd 0

; a brainfuck interpreter 

macro bf_getc{
        shgc
}

macro bf_write{
        shpc al
}

macro write a{
        shps a
}

include 'bf_core.inc'

START:
        call    shell.init
        shln
        cmp     byte[parameters], 0
        je      exit



.run_prog:
; assume command is in format run filepath
        shpsa   parameters
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
        mov     byte [buffer_data + ebx], 0
        call    interpret
        jmp     exit

.check_eof:
        cmp     eax, 6
        je      .process_buffer

.run_error:
        shps  "Error opening file: "
        shpsa   parameters
        shln
        jmp     exit

exit: 
        call    shell.destroy
        mov     eax, -1
        int     0x40
I_END:
; data definitions
err1 db "Missing parenthesis match",0
err2 db "Invalid source file",0
ERR_SIZE = 36
ERR2_SIZE = 30
nl db 10

file_info_struct:
   .fn dd 0
   .offset dd 0
   .offset2 dd 0
   .size dd 0
   .ptr dd 0
   .ecd db 0
   .path dd 0
; ------------------------ stack end ------------
    rb 4096
align 16
STACKTOP:
buffer_data rb BUFFER_SIZE
tape rb TAPE_SIZE

Ops rb BUFFER_SIZE / 2 ; use half of buffer size
arg rd BUFFER_SIZE / 2 ; use half of buffer size

MEM:
