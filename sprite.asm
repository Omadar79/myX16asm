; ===================================================================
; File:         sprite.asm
; Programmer:   Dustin Taub
; Description:  Sprite handling for the game
;===================================================================
.ifndef SPRITE_ASM
SPRITET_ASM = 1

.include "x16.inc"
.include "globals.asm"

get_sprite_frame_addr: 
    ; A: actual sprite frame index   
    ; OUTPUT:  ZP_PTR_1 frame (low byte) | ZP_PTR_1+1 (high byte)
    asl                         ; × 2
    asl                         ; × 4  to get 4 bytes per sprite 
    sta ZP_PTR_2 
    lda #<(VRAM_SPRITES >> 5)
    clc 
    adc ZP_PTR_2 
    sta ZP_PTR_1                ; index of visual sprite 
    lda #>(VRAM_SPRITES >> 5)
    adc #0                      ; Add carry from low byte addition
    sta ZP_PTR_1 + 1    
    rts 




; ===================================================================
; update_sprite - Updates a sprite's attributes in VERA memory
; Inputs:
;   A = sprite index (0-127)
;   X = sprite frame index 
;   ZP_PTR_1 = X position (low byte)
;   ZP_PTR_1+1 = X position (high byte)
;   ZP_PTR_2 = Y position (low byte)
;   ZP_PTR_2+1 = Y position (high byte)
; ===================================================================
;update_sprite:
;    pha                         ; Save sprite index
;    phx                         ; Save sprite frame index
;    
;    ; Calculate the VRAM address of the sprite frame
;    txa                         ; Transfer sprite frame index to A
;    ;asl                         ; Multiply by 2 (each entry is 2 bytes)
;    clc 
;    adc #<(VRAM_SPRITES >> 5)   ; Add base address low byte
;    sta ZP_PTR_3                ; Store in temporary ZP
;    lda #>(VRAM_SPRITES >> 5)   ; Load base address high byte
;    adc #0                      ; Add carry from previous addition
;    sta ZP_PTR_3 + 1            ; Store in temporary ZP
;    
;    ; Get the sprite attribute address
;    pla                         ; Restore sprite index to A
;    jsr get_sprite_frame_addr    ; Set VERA address to sprite attributes
;    
;    ; Write sprite attributes
;    lda ZP_PTR_3                ; Sprite frame address (low byte)
;    sta VERA_DATA0 
;    lda ZP_PTR_3 + 1            ; Sprite frame address (high byte)
;    sta VERA_DATA0 
;    
;    lda ZP_PTR_1                ; X position (low byte)
;    sta VERA_DATA0 
;    lda ZP_PTR_1 + 1            ; X position (high byte)
;    sta VERA_DATA0 
;    
;    lda ZP_PTR_2                ; Y position (low byte)
;    sta VERA_DATA0 
;    lda ZP_PTR_2 + 1            ; Y position (high byte)
;    sta VERA_DATA0 
;    
;    lda #%00001100              ; Z-depth: In front of layer 1
;    sta VERA_DATA0 
;    lda #%01010000              ; 16x16 sprite, palette offset 0
;    sta VERA_DATA0 
;    
;    plx                         ; Restore original sprite index
;    rts 


build_sprite_ui:
    
    ;//// pilot image
    lda #$12                     ; Sprite index for UI element frame
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1
    MACRO_VERA_SET_ADDR $1FC08, 1 ; VRAM_SPRITE_ATTR 
    lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda #8                 ; Write low byte of X
    sta VERA_DATA0      
    lda #0                      ; Write high byte of X
    sta VERA_DATA0  
    lda #216                    ; Write low byte of Y
    sta VERA_DATA0   
    lda #0                     ; Write high byte of Y
    sta VERA_DATA0  
    lda #%00001100              ; zlevel, sprite in from of layer1
    sta VERA_DATA0 
    lda #%01010000              ; 16x16 , paletter offset 00
    sta VERA_DATA0 

     ;UI Box Frame place holder
    lda #$0B                      ; Sprite index for UI element frame
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1 
    MACRO_VERA_SET_ADDR $1FC10, 1 ; VRAM_SPRITE_ATTR << (3 * 1)) , 1
    lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda #248                  ; Write low byte of X
    sta VERA_DATA0      
    lda #0                      ; Write high byte of X
    sta VERA_DATA0  
    lda #216                    ; Write low byte of Y
    sta VERA_DATA0   
    lda #0                     ; Write high byte of Y
    sta VERA_DATA0  
    lda #%00001100              ; zlevel, sprite in from of layer1
    sta VERA_DATA0 
    lda #%01010000              ; 16x16 , paletter offset 00
    sta VERA_DATA0 

    ;UI Box Frame place holder
    lda #$0B                      ; Sprite index for UI element frame
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1 
    MACRO_VERA_SET_ADDR $1FC18, 1 ; VRAM_SPRITE_ATTR << (3 * 1)) , 1
    lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda #16                  ; Write low byte of X
    sta VERA_DATA0      
    lda #1                      ; Write high byte of X
    sta VERA_DATA0  
    lda #216                    ; Write low byte of Y
    sta VERA_DATA0   
    lda #0                     ; Write high byte of Y
    sta VERA_DATA0  
    lda #%00001100              ; zlevel, sprite in from of layer1
    sta VERA_DATA0 
    lda #%01010000              ; 16x16 , paletter offset 00
    sta VERA_DATA0 
    
    ;UI Box Frame place holder
    lda #$0B                      ; Sprite index for UI element frame
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1 
    MACRO_VERA_SET_ADDR $1FC20, 1 ; VRAM_SPRITE_ATTR << (3 * 1)) , 1
    lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda #40                 ; Write low byte of X
    sta VERA_DATA0      
    lda #1                      ; Write high byte of X
    sta VERA_DATA0  
    lda #216                    ; Write low byte of Y
    sta VERA_DATA0   
    lda #0                     ; Write high byte of Y
    sta VERA_DATA0  
    lda #%00001100              ; zlevel, sprite in from of layer1
    sta VERA_DATA0 
    lda #%01010000              ; 16x16 , paletter offset 00
    sta VERA_DATA0 

    rts 

.endif