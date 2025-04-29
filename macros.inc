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

; ------------------- Calculate sprite data address based on sprite index -------------------
; Input: sprite_index - The 0-based index of the sprite (0-127)
; Output: Sets address to VRAM_SPRITES + (sprite_index * 128)
;         For 16x16 4bpp sprites (128 bytes each)
.macro MACRO_SPRITE_ADDR sprite_index
    .if .match(.left(1, {sprite_index}), #)
        ; Immediate mode - constant sprite index
        .local sprite_idx
        sprite_idx = .right(.tcount({sprite_index})-1, {sprite_index})
        lda #<(VRAM_SPRITES + (sprite_idx * 128))
        sta ZP_PTR_1
        lda #>(VRAM_SPRITES + (sprite_idx * 128))
        sta ZP_PTR_1+1
        lda #^(VRAM_SPRITES + (sprite_idx * 128))
        sta ZP_PTR_1+2
    .else
        ; Variable sprite index
        lda sprite_index        ; Load sprite index
        asl                     ; × 2
        asl                     ; × 4
        asl                     ; × 8
        asl                     ; × 16
        asl                     ; × 32
        asl                     ; × 64
        asl                     ; × 128 (size of one 16×16 4bpp sprite)
        
        ; Add to VRAM_SPRITES base address
        clc
        adc #<VRAM_SPRITES
        sta ZP_PTR_1            ; Store low byte
        lda #>VRAM_SPRITES
        adc #0                  ; Add carry
        sta ZP_PTR_1+1          ; Store high byte
        lda #^VRAM_SPRITES
        adc #0                  ; Add carry
        sta ZP_PTR_1+2          ; Store bank
    .endif
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



.endif
