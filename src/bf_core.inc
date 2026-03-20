;-----------------------------------------------------------
; bf_core.inc - Brainfuck interpreter core
;
; Required macros:
;   bf_write  - write character in al to output
;   bf_getc   - read character from input into al
;   write     - print a null-terminated string literal
;
; Required labels:
;   buffer_data - source buffer containing BF program with size BUFFER_SIZE
;   tape        - data tape (TAPE_SIZE bytes)
;   Ops         - compiled ops array (BUFFER_SIZE/2 bytes)
;   arg         - argument array (BUFFER_SIZE/2 dwords)
;-----------------------------------------------------------

BUFFER_SIZE = (2 shl 16)
TAPE_SIZE  = 30000

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



;-----------------------------------------------------------
; interpret: Execute Brainfuck program from buffer_data
; uses ecx, edx, esi, edi, and epi, ebx, eax
; ----------------------------------------------------------

interpret:
;---------------------------------
; ecx = Instruction Pointer for Ops
; edx = Data Pointer for tape
; edi = Tape Base Address
; ebp = Ops array base address
; ebx = Temporary for arg lookup
;-----------------------------------

        call    preprocess

        cmp     eax, -1 
        je      .error_mismatch
        cmp     eax, -2
        je      .error_unclosed

        xor     ecx, ecx
        xor     edx, edx
        xor     esi, esi
        mov     edi, tape
        mov     ebp, Ops

        DISPATCH

.error_mismatch:
        write   "Error: Unmatched ]"
        ret

.error_unclosed:
        write  "Error: Unclosed ["
        ret

exit_interpret:
        ret

BEGIN: 
        DISPATCH
vinc:
        mov     eax, [arg + ebx * 4]
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
        add     edx, TAPE_SIZE

.dispatch:
        DISPATCH

output:
        push     ecx
        mov      ecx, [arg + ebx *4]
        mov      al, byte [edi + edx]
.loop:
        test     ecx, ecx
        je       .dispatch
        dec      ecx
        bf_write      ; bf_write write the character in al
        jmp      .loop
.dispatch:
        pop      ecx ; restore vm state
        DISPATCH

input:
        pusha
        bf_getc
        mov     [edi + edx], al
        popa
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


;-----------------------------------------------------------
; preprocess:  simple peephole optimzer for the interpreter
; returns eax = 0 on success or -1 on error
; uses esi, ebx, edi, eax
;------------------------------------------------------------
preprocess:
; esi as ptr for buffer, ebx as buffer reference
; edi as pointer to Ops and arg
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
        mov     ecx, [jmp_table + eax * 4]
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
        je      .error_mismatch
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

.error_mismatch:
        mov     eax, -1
        jmp     .done
.error_unclosed:
        mov     eax, -2
        jmp     .done
.exit:
        xor     eax, eax
        test    edx, edx
        jnz     .error_unclosed
        mov     byte [Ops + edi], 0
.done:
        leave
        ret

