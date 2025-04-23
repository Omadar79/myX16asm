;////////////////////////////////////////////////////////////
;//
;// macros
;//
;////////////////////////////////////////////////////////////
.include "x16.inc"


.ifndef MACROS_INC 
MACROS_INC = 1

ASCII_SPACE = $20 


; ------------------- Set VERA address pointer to RAM address with stride for iteration-------------------
;       Stride - 1 byte, 2 bytes, 4 bytes, 8 bytes, 16 bytes, 32 bytes, 64 bytes, 128 bytes
.macro MACRO_VERA_SET_ADDR addr, stride 
    .ifnblank stride 
        .if stride < 0
            lda #((^addr) | $08 | ((0-stride) << 4))
        .else
            lda #((^addr) | (stride << 4))
        .endif
    .else
      lda #(^addr) | $10
    .endif

    sta VERA_ADDR_BANK 
    lda #(>addr )
    sta VERA_ADDR_HIGH 
    lda #(<addr )
    sta VERA_ADDR_LOW 
.endmacro

; ------------------- Copy data from RAM to VRAM given a set number of bytes -------------------
.macro MACRO_RAM_TO_VRAM ram_addr, vram_addr, num_bytes 
    .scope
        ; set data port 0 to start writing to VRAM address
        stz VERA_CTRL 
        MACRO_VERA_SET_ADDR vram_addr, 1

        lda #<ram_addr 
        sta ZP_PTR_1 
        lda #> ram_addr 
        sta ZP_PTR_1 + 1 
        ; use index pointers to compare with number of bytes to copy
        ldx #0
        ldy #0
    vram_loop:
        lda (ZP_PTR_1) , y
        sta VERA_DATA0 
        iny 
        cpx #> num_bytes ; last page yet?
        beq check_end 
        cpy #0
        bne vram_loop ; not on last page, Y non-zero
        inx ; next page
        inc ZP_PTR_1 + 1 
        bra vram_loop
    check_end:
        cpy #<num_bytes ; last byte of last page?
        bne vram_loop ; last page, before last byte
   .endscope
.endmacro

.macro MACRO_LOAD_TO_VRAM filename, vram_addr 
    .scope
        ; Set logical file number, device number, and secondary address
        lda #1          ; Logical file number
        ldx #8          ; Device number (SD card or host FS)
        ldy #0          ; Secondary address (0 = ignore file header)
        jsr SETLFS      ; Set logical file

        ; Set filename
        lda #(>filename)
        ldx #< filename 
        ldy #(filename##_end - filename)
        jsr SETNAM      ; Set filename

        ; Set VRAM address
        lda # (^vram_addr + 2 ) ; VRAM bank + 2
        ldx #< vram_addr 
        ldy #> vram_addr 
        jsr LOAD        ; Load file into VRAM
    .endscope 
.endmacro



.macro SUPERIMPOSE str_arg, x_arg, y_arg
   .scope
         jmp end_string
      string_begin: .asciiz str_arg 
      end_string:
         lda #<string_begin 
         sta ZP_PTR_1 
         lda #>string_begin 
         sta ZP_PTR_1 + 1
         lda #<__superimpose_string 
         sta ZP_PTR_2 
         lda #>__superimpose_string 
         sta ZP_PTR_2 + 1
         ldx #(end_string-string_begin - 1)
         ldy #0
      loop:
         lda (ZP_PTR_1),y
         sta (ZP_PTR_2),y
         iny 
         dex 
         bne loop 
         lda #1
         ldx #x_arg 
         ldy #y_arg 
         jsr xy2vaddr 
         sta __superimpose_bank 
         lda #$10
         ora __superimpose_bank 
         sta __superimpose_bank 
         lda #(end_string-string_begin-1)
         jsr __superimpose
   .endscope
.endmacro

.macro SUPERIMPOSE_RESTORE vaddr, length
   .if (.paramcount > 0)
      lda #(^vaddr | $10)
      sta __superimpose_bank 
      ldx #<vaddr 
      ldy #>vaddr 
   .else
      ldx __superimpose_address 
      ldy __superimpose_address + 1
   .endif
   .if (.paramcount > 1)
      lda #length 
   .else
      lda __superimpose_length 
   .endif
   jsr __superimpose_restore 
.endmacro


.macro __superimpose_args2veraloop 
   stz VERA_CTRL 
   lda __superimpose_bank 
   sta VERA_ADDR_BANK 
   stx VERA_ADDR_LOW 
   sty VERA_ADDR_HIGH 
   ldy #0               ; Y = tilemap address offset
   lda __superimpose_length 
   clc
   adc __superimpose_length 
   tax                  ; X = 2 x string length
   lda #<__superimpose_clipboard 
   sta ZP_PTR_1         ; ZP_PTR_1 = clipboard
   lda #>__superimpose_clipboard 
   sta ZP_PTR_1 + 1 
.endmacro

__superimpose_clipboard:
.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

__superimpose_string:
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

__superimpose_length:
.byte 0

__superimpose_bank:
.byte 0

__superimpose_address:
.word 0

__superimpose: ; A: string length (max = 20)
               ; X/Y: tilemap address
               ; __superimpose_bank: tilemap bank
               ; __superimpose_string: string to superimpose
   sta __superimpose_length 
   stx __superimpose_address 
   sty __superimpose_address + 1
   __superimpose_args2veraloop 
@readloop:              ; store tiles to clipboard
   txa 
   beq @write
   lda VERA_DATA0 
   sta (ZP_PTR_1),y
   iny 
   dex 
   jmp @readloop
@write:
   lda __superimpose_address + 1
   sta VERA_ADDR_HIGH 
   lda __superimpose_address 
   sta VERA_ADDR_LOW 
   lda #<__superimpose_string 
   sta ZP_PTR_1         ; ZP_PTR_1 = string
   lda #>__superimpose_string 
   sta ZP_PTR_1 + 1 
   ldx __superimpose_length   ; X = string length
   ldy #0               ; Y = string index
@writeloop:             ; write character tiles to tilemap
   txa 
   beq @end 
   lda (ZP_PTR_1),y
   cmp #ASCII_SPACE 
   bne @store_char 
   lda #0               ; replace spaces with blank tiles
@store_char:
   sta VERA_DATA0         ; store character tile
   lda #0
   sta VERA_DATA0         ; store tile control (PO 0, no flip)
   iny 
   dex 
   jmp @writeloop 
@end:
   rts 

__superimpose_restore:  ; A: string length (max = 20)
                        ; X/Y: tilemap address (bank 0 assumed)
                        ; __superimpose_bank: tilemap bank
   sta __superimpose_length 
   __superimpose_args2veraloop 
@loop:
   txa 
   beq @end 
   lda (ZP_PTR_1),y
   sta VERA_DATA0 
   iny 
   dex 
   jmp @loop
@end:
   rts 

.endif
