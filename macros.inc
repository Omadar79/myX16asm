;////////////////////////////////////////////////////////////
;//
;// macros
;//
;////////////////////////////////////////////////////////////
.include "x16.inc"

.ifndef MACROS_INC 
MACROS_INC = 1

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


.macro MACRO_PRINT_STRING mystring 
    .scope 
        jmp end_string 
    string_begin: .byte mystring 
    end_string:

        lda #<string_begin 
        sta ZP_PTR_1 
        lda #>string_begin 
        sta ZP_PTR_1 + 1
        ldx #(end_string - string_begin)
        ldy #0

    loop:
        lda (ZP_PTR_1) , y
        jsr CHROUT 
        iny 
        dex 
        bne loop 
   .endscope 
.endmacro

.macro MACRO_PRING_CRLF 
    .scope 
        lda #$0D 
        jsr CHROUT 
    .endscope 
.endmacro

.endif ; MACROS_INC