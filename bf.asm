use32
db "MENUET01"
dd 0x01
dd START
dd I_END
dd 0X100000
dd 0x100000
dd 0x0, 0x0
title db "BF INTERPRETER", 0
prompt db ">", 0
buffer_size = 65556
tape_size = 30000
buffer rb buffer_size
tape rb tape_size
buffer_ptr rb 1
cursor_posx dd 0
cursor_posy dd 0
TEXT_FORMAT =  0b10110010111111111111111111111111 
; Simple macro for drawing windows
macro begin_draw{
       mov     eax, 12
       mov     ebx, 1
       int     0x40
}
macro end_draw{
       mov     eax, 12
       mov     ebx, 2
       int     0x40
}
macro wait_for_event{
       mov     eax, 10
       int     0x40
}
START:
      call render_screen
start_repl:
      ; ebx hold buffer address
      ; ecx hold buffer_ptr
      xor     ecx, ecx
      mov    ebx, buffer
event_loop:
       wait_for_event
       cmp     eax, 0x01
       je      rerender
       cmp     eax, 0x02   ; key pressed (event list 2)
       jne     event_loop  
process_key:
       mov      eax, 0x02  ; get key code using function 2
       int      0x40
       test     al, al
       jne      event_loop
       movzx   eax, ah
       cmp      eax, 127
       ja       event_loop  ; discard invalid ascii
process_char:
       cmp     eax, '\n'
       je      newline
       mov     [ebx + ecx], eax
       inc     ecx
       call render_char
       jmp     event_loop
rerender:
       call    render_screen
       jmp     event_loop
      
exit:
       mov     eax, -1
       int     0x40
render_char:
; assume   ebx + ecx holds the current pointer
; render character on curpointer position
      push    ebx
      push    ecx  ; save used register
      cmp     eax, '\n'
      jne     .draw_char
      inc     [cursor_posy]
      mov     dword [cursor_posx], 0
      jmp     .exit
.draw_char:
      mov     eax, 4
      lea     edx, [ebx + ecx -1]
      mov     ebx, [cursor_posx]
      shl     ebx, 16
      or      ebx, [cursor_posy] 
      mov     ecx, TEXT_FORMAT
      mov     esi, 1
      int     0x40
      inc     [cursor_posx]
      pop     ecx
      pop     ebx
.exit:
      ret
render_screen:
       begin_draw
       xor     eax, eax   ; using sysfunction 0 as documented in kernel/sysfunc documentation
       mov     ebx, (100 << 16) | 400  ; position 100, width 300
       mov     ecx, (100 << 16) | 600  ; position 100, height 150?
       mov     edx, (0b00110011 << 24) ; set caption, relative coordiante, resizable window, and black background
       mov     esi, ((5 << 16) | (103 << 8)| 173) ; blue header
       mov     edi, title
       int     0x40
       mov     eax, 4 
       mov     ebx, (2 << 16) | 2
       mov     ecx, TEXT_FORMAT; string ends with zero, no background, utf8-encoding, x2 size, white color
       mov     edx, prompt
       int     0x40
       mov     dword [cursor_posy], eax
       inc     eax      ; cursor has shifted by one after rendering of prompt
       mov     dword [cursor_posx], eax
       end_draw
       ret
