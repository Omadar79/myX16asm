;////////////////////////////////////////////////////////////
;//
;// macros
;//
;////////////////////////////////////////////////////////////
.include "x16.inc"

.ifndef _MACROS_INC 
_MACROS_INC = 1

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


.macro MACRO_SETLFS logical_file_number, device_number, secondary_address 
    .scope
        lda #0
        sta ROM_BANK             ; Make sure we're in the default ROM bank
        lda #logical_file_number ; Logical file number
        ldx #device_number       ; Device number (SD card or host FS)
        ldy #secondary_address   ; Secondary address (0 = ignore file header)
        jsr SETLFS               ; Set logical file
    .endscope 
.endmacro
.endif
