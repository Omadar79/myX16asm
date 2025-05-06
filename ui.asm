; ===================================================================
; UI Implementation
; ===================================================================
.ifndef _UI_ASM
_UI_ASM = 1

.include "x16.inc"
.include "globals.asm"
init_ui:
    ; Initialize the UI area at top of screen
    MACRO_VERA_SET_ADDR VRAM_TILEMAP, 1
    
    ; Draw static UI elements
    ; "SCORE:" text
    ldx #0                  ; X position
    ldy #0                  ; Y position (top row)
    MACRO_PRINT_STRING "SCORE:", 0, 0
    
    ; "LEVEL:" text
    MACRO_PRINT_STRING "LEVEL:", 14, 0
    
    ; Initial values
    jsr update_score_display 
    jsr update_level_display 
    jsr update_powerup_display 
    rts

; Update score display
update_score_display:
    ; Set VERA address for score digits position
    MACRO_VERA_SET_ADDR (VRAM_TILEMAP + 12), 1  ; After "SCORE:" text
    
    ; Convert score to digits
    lda score
    ldx score+1
    ldy #0                  ; Digit counter
@score_loop:
    ; Divide by 10, remainder is current digit
    ; (Division routine here)
    sta VERA_DATA0          ; Write digit tile
    lda #1                  ; White color
    sta VERA_DATA0          ; Write attribute
    iny
    cpy #SCORE_DIGITS
    bne @score_loop
    rts

; Update level display
update_level_display:
    ; Set VERA address for level digits position
    MACRO_VERA_SET_ADDR (VRAM_TILEMAP + 40), 1  ; After "LEVEL:" text
    
    lda current_level
    ; Convert to two digits
    ldx #2                  ; Two digits to display
@level_loop:
    ; Convert to tile index
    clc
    adc #'0'               ; Convert to ASCII/PETSCII
    sta VERA_DATA0         ; Write digit
    lda #1                 ; White color
    sta VERA_DATA0         ; Write attribute
    dex
    bne @level_loop
    rts

; Update powerup display
update_powerup_display:
    ; Set VERA address for powerup position
    MACRO_VERA_SET_ADDR (VRAM_TILEMAP + 22), 1  ; Powerup position
    
    lda powerup_active 
    beq @no_powerup
    ; Show active powerup icon
    sta VERA_DATA0         ; Write powerup tile
    lda powerup_timer      ; Use timer for color intensity
    sta VERA_DATA0         ; Write attribute
    rts
@no_powerup:
    ; Show empty powerup slot
    lda #0                 ; Empty tile
    sta VERA_DATA0 
    sta VERA_DATA0         ; Black attribute
    rts

; Add score (A = low byte, X = high byte)
add_to_score:
    clc 
    adc score              ; Add low byte
    sta score
    txa                    ; High byte
    adc score+1
    sta score+1
    jsr update_score_display
    rts 

; Increment level
increment_level:
    inc current_level
    jsr update_level_display
    rts 

; Set powerup (A = powerup type, X = duration)
set_powerup:
    sta powerup_active
    stx powerup_timer
    jsr update_powerup_display
    rts 

.endif