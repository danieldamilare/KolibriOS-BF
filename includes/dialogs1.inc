;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                            ;
;     DIALOGS1.INC                           ; 
;                                            ;
;   COMPILE WITH FASM                        ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

menus     dd 3       ; number of menus
m_x       dd 0x5     ; x_start
m_y       dd 20      ; y start
m_xs      dd 290     ; x size
m_ys      dd 14      ; y size
g_stack   dd 0xf00   ; thread stack - required

menu:
        db   '*D FILE    +Save File      +Load File      +=      +Quit    '
        db   '*B EDIT    +Copy           +Paste          '
        db   '*B HELP    +Setup          +About..        '
        db   '@'

menu_action dd '----'
window_on   db 0

g_n       dd -1
g_x       dd 0x0 
g_t       dd 0x0
g_i       dd 0x0
g_l       dd 0x0 
closet    db 0

table: times 1024 db 0

last_mouse   dd 0x0

mo_x         dd 0x0
mo_y         dd 0x0

check_mouse:
    pusha
    cmp [window_on], 1
    je  no_open

    mov eax, 37
    mov ebx, 2
    mcall

    cmp   [window_on], 0
    ne    openw2

    cmp   eax, 0
    je    no_open

openw2:
waitformouse:
        mov eax, 23
        mov ebx, 2
        mcall

        cmp  eax, 0
        jne  waitformouse

        mov eax, 37
        mov ebx, 1
        mcall

        mov esi, eax
        shr eax, 10
        xor edx, edx
        mov ebx, 50
        div ebx
        mov edx, eax
        cmp edx, [g_n]
        je  no_open
        cmp edx, [menus]
        jge no_open 
        mov eax, esi
        and eax, 0xffff


        mov ebx, [m_y]
        cmp eax, ebx
        jbe no_open
        add ebx, [m_ys]
        cmp eax, ebx
        jge no_open
        cmp [window_on], 0
        je noww

        mov [closet], 1
        mov ecx, 100
waitm:
        mov eax, 5
        mov ebx, 1
        mcall
        dec ecx
        jz no_open
        cmp [window_on], 0
        jne waitm
noww:
        mov eax, edx
        jmp cll
no_open:
        mov [last_mouse], esi
        popa
        ret
cll:
        mov [window_on], 2
        mov [g_n], eax
        mov [g_x], 96
        mov [g_t], 0
        mov [g_1], 1
        mov eax, 0
        mov ebx, table
        mov ecx, -1
        mcall

