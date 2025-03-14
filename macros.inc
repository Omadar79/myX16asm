;////////////////////////////////////////////////////////////
;//
;// macros
;//
;////////////////////////////////////////////////////////////
.include "x16.inc"

.ifndef MACROS_INC
MACROS_INC  = 1

;--- Set VERA address with RAM address and stride for iteration
.macro VERA_SET_ADDR addr, stride
    .ifnblank stride
        .if stride < 0
            lda #((^addr) | $08 | ((0-stride) << 4))
        .else
            lda #((^addr) | (stride << 4))
        .endif
    .else
      lda #(^addr) | $10
    .endif

    sta VERA_addr_bank
    lda #(>addr)
    sta VERA_addr_high
    lda #(<addr)
    sta VERA_addr_low
.endmacro

.macro JSRFAR far_sr_addr, bank
    jsr JSRFAR_kernal_addr
	.addr far_sr_addr
	.byte bank
.endmacro

;--- Copy data from RAM to VRAM
.macro RAM_TO_VRAM ram_addr, vram_addr, num_bytes
    .scope
        ; set data port 0 to start writing to VRAM address
        stz VERA_ctrl
        VERA_SET_ADDR vram_addr, 1

        lda #<ram_addr
        sta ZP_PTR_1 
        lda #>ram_addr
        sta ZP_PTR_1+1
        ; use index pointers to compare with number of bytes to copy
        ldx #0
        ldy #0
    vram_loop:
        lda (ZP_PTR_1),y
        sta VERA_data0
        iny
        cpx #>num_bytes ; last page yet?
        beq check_end
        cpy #0
        bne vram_loop ; not on last page, Y non-zero
        inx ; next page
        inc ZP_PTR_1+1
        bra vram_loop
    check_end:
        cpy #<num_bytes ; last byte of last page?
        bne vram_loop ; last page, before last byte
   .endscope
.endmacro

.endif ; MACROS_INC