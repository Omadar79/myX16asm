;////////////////////////////////////////////////////////////
;//
;// macros
;//
;////////////////////////////////////////////////////////////
.include "x16.inc"


.ifndef MACROS_INC 
MACROS_INC = 1

ASCII_SPACE = $20

textoverlay_buffer:         .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
textoverlay_length:         .byte 0
textoverlay_bank:           .byte 0
textoverlay_address:        .word 0
textoverlay_clipboard:      .word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

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

; ---------------------------------------------------------------
; MACRO_PRINT_OVERLAY - Displays text string over existing graphics
; Parameters:
;   string: The string to display
;   x_pos: X position (0-39 for 40 column mode)
;   y_pos: Y position (0-29 for normal display)
; ---------------------------------------------------------------
.macro MACRO_PRINT_STRING mystring 
    .scope
        ; Save the current VERA state
        lda VERA_CTRL 
        pha 
        lda VERA_DC_VIDEO 
        pha 
        
        ; Configure Layer 1 for text mode
        lda #%00000000          ; 1bpp text mode, 32x32 map
        sta VERA_L1_CONFIG 
        lda #(VRAM_PETSCII>> 9); Set tile base to PETSCII font
        sta VERA_L1_TILEBASE 
        lda #(VRAM_TEXTMAP >> 9); Set map base for our text
        sta VERA_L1_MAPBASE 
        
        ; Clear the text overlay first
        MACRO_CLEAR_TEXT_OVERLAY 

        ; Set VERA address
        stz VERA_CTRL           ; Select Data Port 0
        lda #((VRAM_TEXTMAP >> 16) | $10)  ; Bank and stride=1
        sta VERA_ADDR_BANK 
        lda #>(VRAM_TEXTMAP + 1024)  ; Center vertically (roughly)
        sta VERA_ADDR_HIGH
        lda #<(VRAM_TEXTMAP + 1024)  ; Center vertically (roughly)
        sta VERA_ADDR_LOW
        
        
        ; Write the string
        ldx #0
    loop: 
        lda mystring, x          ; Load character
        beq done                 ; If zero, end of string
        sta VERA_DATA0           ; Write character
        lda #01                   ; White text on transparent
        sta VERA_DATA0           ; Write color
        inx 
        bne loop                ; Loop if not zero
    done:
        ; Restore VERA state
        pla 
        sta VERA_DC_VIDEO 
        pla 
        sta VERA_CTRL 
    .endscope 
.endmacro

; ---------------------------------------------------------------
; MACRO_CLEAR_TEXT_OVERLAY - Clears the text overlay layer
; No parameters needed
; ---------------------------------------------------------------
.macro MACRO_CLEAR_TEXT_OVERLAY
    .scope
        ; Set VERA address to start of text map
        stz VERA_CTRL           ; Select Data Port 0
        lda #((VRAM_TEXTMAP >> 16) | $10)  ; Bank and stride=1
        sta VERA_ADDR_BANK 
        lda #>VRAM_TEXTMAP 
        sta VERA_ADDR_HIGH 
        lda #<VRAM_TEXTMAP 
        sta VERA_ADDR_LOW 
        ; Clear 32x32 text area (2048 bytes = 1024 characters with colors)
        ldx #4                  ; 4 pages of 256 bytes = 1024 bytes
        lda #32                  ; Space character
    page_loop:
        ldy #0                  ; 256 bytes per page
    byte_loop:
        sta VERA_DATA0          ; Clear character
        sta VERA_DATA0          ; Clear color
        dey 
        bne byte_loop
        dex 
        bne page_loop
    .endscope
.endmacro

; ---------------------------------------------------------------
; MACRO_PRINT_STRING - Writes text directly to the current tilemap
; Parameters:
;   string: The string to display
;   x_pos: X position in tiles
;   y_pos: Y position in tiles
; ---------------------------------------------------------------
.macro MACRO_PRINT_STRING_TOP string, x_pos, y_pos
    .scope
        ; Calculate tilemap position (32 tiles per row)
        lda #y_pos 
        asl                     ; × 2
        asl                     ; × 4
        asl                     ; × 8
        asl                     ; × 16
        asl                     ; × 32
        sta ZP_PTR_1            ; Store low byte
        lda #0
        rol                     ; Get any carry from shifts
        sta ZP_PTR_1 + 1        ; Store high byte
        
        ; Add X position
        lda #x_pos 
        asl                     ; × 2 (each tile entry is 2 bytes)
        clc 
        adc ZP_PTR_1 
        sta ZP_PTR_1 
        lda ZP_PTR_1 + 1
        adc #0
        sta ZP_PTR_1 + 1
        
        ; Set VERA address to correct tilemap position
        stz VERA_CTRL           ; Select Data Port 0
        lda #((VRAM_TILEMAP >> 16) | $10)  ; Bank and stride=1
        sta VERA_ADDR_BANK 
        lda ZP_PTR_1 + 1         ; High byte of position
        clc 
        adc #>VRAM_TILEMAP 
        sta VERA_ADDR_HIGH 
        lda ZP_PTR_1            ; Low byte of position
        sta VERA_ADDR_LOW 
        
        ; Write the string
        ldx #0
    loop:
        lda string,x           ; Load character
        beq done               ; If zero, end of string
        sta VERA_DATA0         ; Write tile index
        lda #%00000001         ; Palette offset 0, no flip
        sta VERA_DATA0         ; Write tile attributes
        inx 
        bne loop               ; Loop if not zero
    done:
    .endscope
.endmacro

.macro MACRO_PRING_CRLF 
    .scope 
        lda #$0D 
        jsr CHROUT 
    .endscope 
.endmacro

.endif ; MACROS_INC