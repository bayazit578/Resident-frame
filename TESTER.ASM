.286
.model tiny
.code
org 100h
locals @@
REG_VAL         equ 4c00h

Start:          ;call Program

                push es 7777h
                pop  es
                push 1000h
                pop  di
                push offset @@hui
                pop  si
                push cs
                pop  ds

                mov  cx, 10h
                rep  movsb

                mov  bx, 2222h
                mov  cx, 3333h
                mov  dx, 4444h
                mov  si, 5555h
                mov  di, 6666h
                mov  bp, 7777h

                push 8888h
                pop  ds

                push 9999h
                pop  es

                push 7777h
                push 1000h
                retf

@@hui:          in   al, 60h
                cmp  al, 1
                jne  @@hui
            
                mov ax, 4c00h
                int 21h

end             Start