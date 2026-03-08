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
include 'includes/macros.inc'
@pid dd 0
include 'includes/shell.inc'

; a brainfuck interpreter 
; data definitions

BUFFER_SIZE = (2 shl 16)
TAPE_SIZE  = 30000

prompt db "BF:> ", 0
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
        call    shell.init
        ; shps   "Starting..."
        shln
        ; shps  "Parameters: "
        ; shpsa  parameters
        cmp     byte[parameters], 0
        je      exit


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
        jmp     exit

.check_eof:
        cmp     eax, 6
        je      .process_buffer

.run_error:
        write2  "Error opening file: "
        shpsa   parameters
        shln
        jmp     exit

macro DISPATCH {
        movzx  eax, byte [ebp+ecx]
        mov    ebx, ecx
        inc    ecx
        jmp    dword [jmp_table + eax *4]
}

; interpret  a brainfuck program
interpret:
    ;ecx -> ip, edx -> dp, esi => bracket depth, edi -> tape
        ; shps  "In interpet"
        call    preprocess
        cmp     eax, -1 
        je      .match_error
        xor     ecx, ecx
        xor     edx, edx
        xor     esi, esi
        mov     edi, tape
        mov     ebp, Ops
        DISPATCH

.match_error:
        shpsa   err1
        ret

exit_interpret:
        ret

BEGIN: 
        DISPATCH
vinc:
        mov     eax, dword [arg + ebx * 4]
        add     byte [edi + edx], al
        DISPATCH

vdec:
        mov     eax, [arg + ebx * 4]
        sub     byte [edi + edx], al
        DISPATCH

pinc:
        add     edx, [arg + ebx * 4]
        cmp     edx, TAPE_SIZE
        jl      .dispatch
        sub     edx, TAPE_SIZE
.dispatch:
        DISPATCH

pdec:
        sub     edx, [arg + ebx * 4]
        jns     .dispatch
        add      edx, TAPE_SIZE
.dispatch:
        DISPATCH


output:
        mov     ebx, [arg + ebx *4]
        mov     al, byte [edi + edx]
.loop:
        test    ebx, ebx
        je      .dispatch
        dec     ebx
        call    shell.print_char
        jmp     .loop
.dispatch:
        DISPATCH

input:
        shgc
        mov     [edi + edx], al
        DISPATCH

brac_left:
        cmp     byte [edi + edx], 0
        jne     .dispatch
        mov     ecx, [arg + ebx * 4]
.dispatch:
        DISPATCH

brac_right:
        mov     al, byte [edi + edx]
        test    al, al
        jz      .dispatch
        mov     ecx,  [arg + ebx * 4]
.dispatch:
        DISPATCH

preprocess:
; esi as ptr for buffer, ebx as buffer reference
; edi as pointer to Ops and arg
        ; shps   "Preprocessing"
        push    ebp
        mov     ebp, esp
        mov     ebx, buffer_data 
        xor     esi, esi
        xor     edi, edi
        xor     edx, edx
 
.start:
        movzx   eax, byte [ebx + esi]
        inc     esi 
        test    eax, eax
        je      .exit
        cmp     eax, 127
        jg      .start
        mov     ecx, dword [jmp_table + eax * 4]
        cmp     ecx, BEGIN
        je      .start
        cmp     eax, '['
        je      .left
        cmp     eax, ']'
        je      .right
        jmp     .repeat

.left:
        inc     edx
        push    edi
        mov     byte [Ops + edi], al
        inc     edi
        jmp     .start

.right:
        test    edx, edx
        je      .error
        dec     edx
        pop     ecx
        mov     [Ops + edi], al
        mov     [arg + edi * 4], ecx
        inc     [arg + edi * 4]
        inc     edi
        mov     [arg + ecx * 4], edi
        jmp     .start

.repeat:
        mov     ecx, 1
.start_repeat:
        cmp     al, byte [ebx + esi]
        jne     .end_repeat
        inc     ecx
        inc     esi
        jmp     .start_repeat
 
.end_repeat:
        mov     [Ops + edi], al
        mov     [arg + edi *4], ecx
        inc     edi
        jmp     .start

.error:
        mov     eax, -1
        leave
        ret
.exit:
        xor     eax, eax
        mov     byte [Ops + edi], 0
        leave
        ret

exit: 
        call    shell.destroy
        mov     eax, -1
        int     0x40
I_END:
    rb 4096
align 16
STACKTOP:
buffer_data rb BUFFER_SIZE
tape rb TAPE_SIZE

Ops rb BUFFER_SIZE / 2 ; use half of buffer size
arg rd BUFFER_SIZE / 2 ; use half of buffer size

MEM:
