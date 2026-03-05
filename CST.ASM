.286
.model tiny

.code
org 100h

locals @@

DISP_LN         equ 50h
DISP_COL	    equ 19h
VRAMSEG  	    equ 0b800h

NEXT_PAGE       equ 1000h
CMD_STR 	    equ 80h
REG_COUNT       equ 0dh
FLAG_COUNT      equ 09h
REG_NAME_LN     equ 05h
REG_TABLE_LN    equ 06h
REG_VAL_LN      equ 04h

FRAME_LN        equ 0dh
FRAME_HGHT      equ 13h
REG_COL         equ 01001100b
FRAME_COL1      equ 01111111b
FRAME_COL2      equ 00011001b
SYMBOL          equ 29h

mDRAW_FLAG MACRO length
    mov  ax, dx
    and  ax, 100000b
    xor  word ptr es:[di], ax
    add  di, 2

    rol  dx, length
ENDM

Main:           push 00h
                pop  es
     
                cli
                mov  bx, (4 * 08h)
                mov  ax, es:[bx]
                mov  word ptr OldHandler08, ax
                mov  ax, es:[bx+2]
                mov  word ptr OldHandler08 + 2, ax

                mov  es:[bx], offset Handler08
                mov  ax, cs
                mov  es:[bx+2], ax

                mov  bx, (4 * 09h)
                mov  ax, es:[bx]
                mov  word ptr OldHandler09, ax
                mov  ax, es:[bx+2]
                mov  word ptr OldHandler09 + 2, ax

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
                push ax

                xor  ax, ax
                mov  al, byte ptr cs:[update_reg]
                cmp  ax, 1
                je   @@call_new

                pop  ax
                jmp  cs:[OldHandler08]

            @@call_new:
                push bx cx dx si di bp bp ds es
                ;ax | bx cx dx si di bp -- ds es
                mov  bx, VRAMSEG
                mov  es, bx
                
                mov  bx, cs
                mov  ds, bx

                mov  word ptr si, frame_addr
                sub  si, (DISP_LN + 1) * 2
                mov  di, si
                sub  di, NEXT_PAGE * 2
                mov  bx, si
                add  bx, NEXT_PAGE * 2
                mov  cx, FRAME_HGHT
            
            @@compare:
                push cx
                mov  cx, FRAME_LN
                call cmp_bytes
                add  si, (DISP_LN - FRAME_LN) * 2
                add  di, (DISP_LN - FRAME_LN) * 2
                add  bx, (DISP_LN - FRAME_LN) * 2
                pop  cx
                loop @@compare

                mov  bp, sp

                mov  si, 18d
                mov  cx, 10
                mov  di, word ptr frame_addr
                add  di, (DISP_LN + REG_NAME_LN + 1) * 2
                mov  ah, REG_COL

            @@draw1:                                        ; ax bx cx dx si di bp -- ds es
                mov  dx, ss:[bp + si]

                push cx
                call draw_reg_val
                add  di, (DISP_LN - REG_VAL_LN) * 2
                pop  cx

                sub  si, 2
                loop @@draw1

                sub  di, (DISP_LN * 3) * 2
                mov  dx, sp                                 ; sp
                add  dx, 24d
                call draw_reg_val
                add  di, (DISP_LN * 3 - REG_VAL_LN) * 2

                mov  dx, ss                                 ; ss
                call draw_reg_val
                add  di, (DISP_LN - REG_VAL_LN) * 2

                mov  si, 18d
                mov  cx, 2

            @@draw2:                                        ; cs ip
                mov  dx, ss:[bp + si]

                push cx
                call draw_reg_val
                add  di, (DISP_LN - REG_VAL_LN) * 2
                pop  cx

                add  si, 2
                loop @@draw2

                mov  dx, ss:[bp + 24d]                      ; flags

                sub  di, REG_NAME_LN * 2
                call draw_flag_names
                sub  di, FLAG_COUNT * 2
                call draw_flag_vals

                mov  di, word ptr frame_addr
                mov  ax, VRAMSEG
                mov  ds, ax
                sub  di, (DISP_LN + 1) * 2
                mov  si, di
                sub  di, NEXT_PAGE * 2
                mov  cx, FRAME_HGHT

            @@copy_frame:
                mov  bx, cx 
                mov  cx, FRAME_LN
                rep movsw
                add  di, (DISP_LN - FRAME_LN) * 2
                add  si, (DISP_LN - FRAME_LN) * 2
                mov  cx, bx
                loop @@copy_frame

                pop  es ds bp bp di si dx cx bx ax
                jmp  cs:[OldHandler08]
Handler08       endp

;-----------------------------------------------------------
; Keyboard handler
;-----------------------------------------------------------

Handler09       proc
                push ax

                in   al, 60h

                cmp  al, SYMBOL
                je   @@ctrl_pressed

                pop  ax
                jmp  cs:[OldHandler09]

            @@ctrl_pressed:
                push es

                in   al, 61h
                or   al, 80h
                out  61h, al
                and  al, not 80h
                out  61h, al

                call ctrl_recognize

                pop  es
                jnz  @@erasing

                push bx cx dx si di ds es
                mov  bx, cs
                mov  ds, bx

                mov  bx, VRAMSEG
                mov  es, bx

                mov  dx, REG_COUNT + 3
                mov  cx, REG_NAME_LN + 6
                lea  si, frame_symb2
                mov  ah, FRAME_COL1
                call draw_frame

                mov  dx, REG_COUNT + 1
                mov  cx, REG_NAME_LN + 4
                lea  si, frame_symb1
                mov  ah, FRAME_COL2
                call draw_frame

                mov  di, word ptr frame_addr
                add  di, (DISP_LN + 1) * 2

                call draw_reg_names

                ; call draw_flag_names

                mov  byte ptr update_reg, 01h

                mov  al, 20h
                out  20h, al

                pop  es ds di si dx cx bx ax
                jmp  @@end

            @@erasing:
                push bx cx si di ds es
                mov  bx, cs
                mov  ds, bx

                mov  byte ptr cs:[update_reg], 00h

                mov  ax, VRAMSEG
                mov  es, ax
                mov  ds, ax
                mov  di, word ptr cs:[frame_addr]
                sub  di, (DISP_LN + 1) * 2
                mov  si, di
                add  si, NEXT_PAGE * 2
                sub  di, NEXT_PAGE * 2
                mov  cx, FRAME_HGHT

            @@erase_frame:
                mov  bx, cx
                mov  cx, FRAME_LN
                rep movsw
                add  di, (DISP_LN - FRAME_LN) * 2
                add  si, (DISP_LN - FRAME_LN) * 2
                mov  cx, bx
                loop @@erase_frame

                mov  al, 20h
                out  20h, al
                pop  es ds di si cx bx ax

            @@end:
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

                mov  ax, DISP_COL ;- 1
                sub  ax, dx
                shr  ax, 1

                push bx
                mov  bl, DISP_LN
                mul  bl
                pop  bx

                add  ax, bx
                mov  di, ax
                shl  di, 1
                add  di, NEXT_PAGE * 2

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
; Descr: draw_reg_names draws register names in second page
;        of vram
; 
; Entry: 
;
; Assum:
;
; Esit:  
;
; Destr: AX, CX, DX, SI, DI
;-----------------------------------------------------------

draw_reg_names  proc
                lea  si, registers
                mov  cx, REG_COUNT

            @@name_print:
                mov  dx, cx
                mov  cx, REG_NAME_LN
                mov  ah, [si + REG_NAME_LN]
                call print_str
                add  di, (DISP_LN - REG_NAME_LN) * 2
                add  si, REG_TABLE_LN - REG_NAME_LN
                mov  cx, dx
                loop @@name_print

                ret
draw_reg_names  endp

;-----------------------------------------------------------
; Descr: draw_reg_val draws register names
; 
; Entry: DX    -  reg value
;        AH    -  text color 
;        ES:DI -> place in vram to dump
;
; Assum: 
;
; Exit:
;
; Destr: AX, BX, DI, CX
;-----------------------------------------------------------

draw_reg_val    proc
                mov  cx, REG_VAL_LN
                lea  bx, hex_table

            @@print_char:
                mov  al, dh
                shr  al, 4
                xlatb                                       ; al = [bx + al]
                stosw
                shl  dx, 4
                loop @@print_char

                ret
draw_reg_val    endp

;-----------------------------------------------------------
; Descr: cmp_bytes compares bytes from 2 strings and write 
;        different bytes to required buffers 
;
; Entry: ES:DI -> 1st string and 1st requred buffer to save
;        ES:SI -> 2nd string
;        ES:BX -> 2nd requred buffer to save
;        CX    -  length of comparable strings
;
; Assum: 
; 
; Exit:
;
; Destr: AX, BX, DX, SI, DI
;-----------------------------------------------------------

cmp_bytes       proc

            @@compare:
                mov dx, word ptr es:[di]
                cmp dx, word ptr es:[si]
                je  @@not_save
                mov dx, word ptr es:[di]
                mov word ptr es:[bx], dx

                @@not_save:
                add di, 2
                add si, 2
                add bx, 2
                loop @@compare

                ret
cmp_bytes       endp

;-----------------------------------------------------------
; Descr: ctrl_recognize recognizes the ctrl pressing and 
;        sets ZF to 1 if ctrl pressed
;
; Entry: 
;
; Assum:
;
; Exit:
;
; Destr: AX, ES
;-----------------------------------------------------------

ctrl_recognize  proc
                mov  ax, 40h
                mov  es, ax
                mov  ax, word ptr es:[17h]

                test al, 00000100b
                ret
ctrl_recognize  endp

;-----------------------------------------------------------
; Descr: draw_flag_names draws flag names in vram
;
; Entry: ES:DI -> address to draw
;
; Assum: 
;
; Exit:
;
; Destr: AX, CX, SI
;-----------------------------------------------------------

draw_flag_names proc
                lea  si, flags
                mov  cx, FLAG_COUNT
                mov  ah, [si + FLAG_COUNT]
            
            @@draw:
                lodsb
                stosw
                loop @@draw
                ret
draw_flag_names endp

;-----------------------------------------------------------
; Descr: draw_flags draws vals of flags in the frame
;
; Entry: DX    -  value of FLAGS
;        ES:DI -> place to draw flags
;
; Assum: 
;
; Exit:
;
; Destr: AX, DX, DI
;-----------------------------------------------------------

draw_flag_vals  proc
                ror  dx, 6
                mov  cx, 6

            @@draw1:
                mDRAW_FLAG 1
                loop @@draw1

                rol  dx, 1
                mov  cx, 3

            @@draw2:
                mDRAW_FLAG 2
                loop @@draw2

                ret
draw_flag_vals  endp

hex_table       db '0123456789abcdef'
frame_symb1     db 0dah, 0c4h, 0bfh, 0b3h, 0d9h, 0c4h, 0c0h, 0b3h
frame_symb2     db 0c9h, 0cdh, 0bbh, 0bah, 0bch, 0cdh, 0c8h, 0bah
frame_addr      dw 0
registers       db 'ax:  ', REG_COL 
                db 'bx:  ', REG_COL
                db 'cx:  ', REG_COL
                db 'dx:  ', REG_COL
                db 'si:  ', REG_COL
                db 'di:  ', REG_COL
                db 'bp:  ', REG_COL
                db 'sp:  ', REG_COL
                db 'ds:  ', REG_COL
                db 'es:  ', REG_COL
                db 'ss:  ', REG_COL
                db 'cs:  ', REG_COL
                db 'ip:  ', REG_COL
flags           db 'oditszapc', REG_COL
update_reg      db 0
OldHandler09    dd 0
OldHandler08    dd 0

EOP:

end             Main
