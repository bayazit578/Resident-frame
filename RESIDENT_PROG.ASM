.286
.model tiny

.code
org 100h

; 417 нажатость alt, ctrl, tab

locals @@

DISP_LN         equ 50h
DISP_COL	    equ 19h
VRAMSEG  	    equ 0b800h

CMD_STR 	    equ 80h
B_OFFSET        equ 4h
REG_COUNT       equ 0dh
REG_NAME_LN     equ 04h
REG_TABLE_LN    equ 09h
REG_COL         equ 01001100b
FRAME_COL1      equ 00101010b
FRAME_COL2      equ 00011001b
ZERO_ASCII      equ '0'

Main:           push 00h
                pop  es
                mov  bx, (4 * 08h)
                mov  ax, es:[bx]
                mov  word ptr OldHandler08, ax
                mov  ax, es:[bx+2]
                mov  word ptr OldHandler08 + 2, ax

                cli
                mov  es:[bx], offset Handler08
                mov  ax, cs
                mov  es:[bx+2], ax
                sti

                mov  bx, (4 * 09h)
                mov  ax, es:[bx]
                mov  word ptr OldHandler09, ax
                mov  ax, es:[bx+2]
                mov  word ptr OldHandler09 + 2, ax

                cli
                mov  es:[bx], offset Handler09
                mov  ax, cs
                mov  es:[bx+2], ax
                sti

                mov  ax, 3100h
                mov  dx, offset EOP
                shr  dx, 4
                inc  dx
                int  21h

;-----------------------------------------------------------
; Timer handler
;-----------------------------------------------------------

Handler08       proc
                push ax dx cx di ds es ; too many regs

                push cs
                pop  ds

                xor  cx, cx
                mov  cl, update_reg
                jcxz @@end

                ; some code...

            @@end:
                pop  es ds di cx dx ax
                jmp  cs:[OldHandler08]

Handler08       endp

;-----------------------------------------------------------
; Keyboard handler
;-----------------------------------------------------------

Handler09       proc
                push bp
                mov  bp, sp

                push ds ax

                push cs
                pop  ds

                in   al, 60h

                cmp  al, Symbol
                je   @@call_new

                pop  ax ds bp
                jmp  cs:[OldHandler09]

            @@call_new:
                push bx cx dx di si es

                in   al, 61h
                or   al, 80h
                out  61h, al
                and  al, not 80h
                out  61h, al

                push VRAMSEG
                pop  es
                
                mov  dx, REG_COUNT + 2
                mov  cx, REG_NAME_LN + 6
                lea  si, frame_symb2
                xor  ax, ax
                mov  ah, FRAME_COL1

                call draw_frame

                mov  dx, REG_COUNT
                mov  cx, REG_NAME_LN + 4
                lea  si, frame_symb1
                xor  ax, ax
                mov  ah, FRAME_COL2

                call draw_frame

                mov  word ptr di, frame_addr
                add  di, (DISP_LN + 1) * 2

                call draw_reg_names

                mov  word ptr di, frame_addr
                add  di, (DISP_LN + 5) * 2
                mov  dx, 0000111100001111b
                mov  ah, REG_COL
                call draw_reg_val

                mov  byte ptr update_reg, 01h

                mov  al, 20h
                out  20h, al

                pop  es si di dx cx bx ax ds
                
                pop  bp
                iret
Handler09       endp

;-----------------------------------------------------------
; Descr: draw_frame draws the frame with symbols from string 
;        in SI
;
; Entry: CX    -  length of the frame
;        DX    -  height of the frame
;        AH    -  frame_color
;        DS:SI -> string with frame parameters
;
; Assum: ES should points to vram segment
;
; Exit:  
;
; Destr: AX, CX, DI
;-----------------------------------------------------------

draw_frame      proc
                push bp
                mov  bp, sp

                push ax

                mov  bx, DISP_LN                            ; calculating address of the frame starting
                sub  bx, cx
                shr  bx, 1

                mov  ax, DISP_COL - 1
                sub  ax, dx
                shr  ax, 1

                push bx
                mov  bl, DISP_LN
                mul  bl
                pop  bx

                add  ax, bx
                mov  di, ax
                shl  di, 1

                mov  frame_addr, di

                pop  ax

                cld

                lodsb                                       ; left top corner
                stosw

                mov  bx, cx

                lodsb                                       ; top side
                rep  stosw

                mov  cx, bx

                lodsb                                       ; right top corner
                stosw

                add  di, (DISP_LN - 1) * 2

                mov  bx, cx
                mov  cx, dx

                lodsb                                       ; right side
            @@right_side:
                stosw
                add  di, (DISP_LN - 1) * 2
                loop @@right_side
                sub  di, (DISP_LN - 1) * 2

                mov  cx, bx

                add  di, (DISP_LN - 1) * 2

                lodsb                                       ; right bottom corner
                std
                stosw

                cld
                lodsb                                       ; bottom side
                std
                rep stosw

                cld
                lodsb                                       ; left bottom corner
                std
                stosw

                sub  di, (DISP_LN - 1) * 2

                mov  bx, cx
                mov  cx, dx

                cld
                lodsb                                       ; left side
                std
            @@left_side:
                stosw
                sub  di, (DISP_LN - 1) * 2
                loop @@left_side
                add  di, (DISP_LN - 1) * 2

                mov  cx, bx

                pop  bp
                ret
draw_frame      endp

;-----------------------------------------------------------
;
;
;
;-----------------------------------------------------------

draw_reg_names  proc
                mov  si, offset registers
                mov  cx, REG_COUNT

            @@name_print:
                mov  dx, cx
                mov  cx, REG_NAME_LN
                mov  ah, [si + REG_TABLE_LN - 1]
                call print_str
                add  di, (DISP_LN - REG_NAME_LN) * 2
                add  si, REG_TABLE_LN - REG_NAME_LN
                mov  cx, dx
                loop @@name_print

                ret
draw_reg_names  endp

;-----------------------------------------------------------
; Descr: print_str prints the string
; 
; Entry: DS:SI -> start of the string
;        CX    =  string length
;        ES:DI -> vram address start
;
; Assum: ES should be setted to vram seg
;
; Exit:
;
; Destr: SI, DI, CX
;-----------------------------------------------------------

print_str       proc
                cld

            @@print_string:
                lodsb
                stosw
                loop @@print_string

                ret
print_str       endp

;-----------------------------------------------------------
; Descr: byte_to_hex converts byte to hex representation
; 
; Entry: DX    -  reg value
;        AH    -  text 
;        ES:DI -> place in vram to dump
;
; Assum: 
;
; Exit:
;
; Destr: AX, BX, DI, CX
;-----------------------------------------------------------

draw_reg_val    proc
                mov  cx, 4

            @@print_char:
                mov  al, dl
                and  al, 00001111b

                lea  bx, hex_table
                xlatb                                       ; al = [bx + al]
                stosw
                shr  dl, 4
                loop @@print_char

                ret
draw_reg_val    endp

hex_table       db '0123456789abcdf'
frame_symb1     db 0dah, 0c4h, 0bfh, 0b3h, 0d9h, 0c4h, 0c0h, 0b3h
frame_symb2     db 0c9h, 0cdh, 0bbh, 0bah, 0bch, 0cdh, 0c8h, 0bah
frame_addr      dw 0
registers       db 'ax: ', 4 dup (0), REG_COL 
                db 'bx: ', 4 dup (0), REG_COL
                db 'cx: ', 4 dup (0), REG_COL
                db 'dx: ', 4 dup (0), REG_COL
                db 'si: ', 4 dup (0), REG_COL
                db 'di: ', 4 dup (0), REG_COL
                db 'sp: ', 4 dup (0), REG_COL
                db 'bp: ', 4 dup (0), REG_COL
                db 'ds: ', 4 dup (0), REG_COL
                db 'es: ', 4 dup (0), REG_COL
                db 'ss: ', 4 dup (0), REG_COL
                db 'cs: ', 4 dup (0), REG_COL
                db 'ip: ', 4 dup (0), REG_COL
update_reg      db 0
OldHandler09    dd 0
OldHandler08    dd 0
Symbol          db 29h

EOP:

end             Main
