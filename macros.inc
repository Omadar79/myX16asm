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

; Macro to print a character string
; Parameters:
;   string_addr - Address of the string to print (low byte)
;   x_pos - X position (0-31)
;   y_pos - Y position (0-31)
.macro MACRO_PRINT_STRING string_addr, x_pos, y_pos 
    .scope
        ; Calculate VRAM address for text position
        lda #<(VRAM_TEXTMAP) ;+ (y_pos * 64) + (x_pos * 2))
        sta VERA_ADDR_LOW 
        lda #>(VRAM_TEXTMAP) ;+ (y_pos * 64) + (x_pos * 2))
        sta VERA_ADDR_HIGH 
        lda #$10                    ; Bank 0, increment by 1
        sta VERA_ADDR_BANK 

        ; Set up string pointer
        lda #<string_addr 
        sta ZP_PTR_1 
        lda #>string_addr 
        sta ZP_PTR_1 + 1

        ldy #0
    @print_loop:
        lda (ZP_PTR_1),y          ; Get character from string
        beq @done                 ; If zero, we're done
        sta VERA_DATA0            ; Write character to VRAM
        lda #%00000000            ; Default attributes (white on black)
        sta VERA_DATA0            ; Write attributes
        iny 
        bra @print_loop
    @done:
    .endscope 
.endmacro

; Macro to clear the text map
; Clears a 32x32 text map by writing spaces to all positions
.macro MACRO_CLEAR_TEXT_MAP 
    .scope
        MACRO_VERA_SET_ADDR VRAM_TEXTMAP, 1 
        ; Clear 2048 bytes (32x32)
        ldx #8                     ; 8 pages of 256 bytes
        ldy #0                      ; Byte counter
    @clear_loop:
        lda #ASCII_SPACE           ; Space character
        sta VERA_DATA0             ; Write character
        lda #%00000000             ; Default attributes
        sta VERA_DATA0             ; Write attributes
        iny 
        bne @clear_loop            ; Continue until Y wraps around
        dex 
        bne @clear_loop            ; Continue until all pages are cleared
    .endscope 
.endmacro


.endif
