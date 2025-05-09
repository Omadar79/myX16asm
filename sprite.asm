; ===================================================================
; File:         sprite.asm
; Programmer:   Dustin Taub
; Description:  Sprite handling for the game
;===================================================================
.ifndef _SPRITE_ASM
_SPRITE_ASM = 1

.include "x16.inc"
.include "globals.asm"

;// sprite attribute addresses
sp_att_player =         $1FC00  ; 1x 
                                ; $1FC00 
sp_att_playermisc =     $1FC08  ; 4x
                                ; $1FC08 /$1FC10 /$1FC18 /$1FC20 
sp_att_playerproj =     $1FC28  ; 10x
                                ; $1FC28 /$1FC30 /$1FC38 /$1FC40 /$1FC48 /$1FC50 /$1FC58 /$1FC60 /$1FC68 /$1FC70 
sp_att_enemy =          $1FC78  ; 16x
                                ; $1FC78 /$1FC80 /$1FC88 /$1FC90 /$1FC98 /$1FCA0 /$1FCA8 /$1FCB0 /$1FCB8 /$1FCD0 
                                ; $1FCD8 /$1FCE0 /$1FCE8 /$1FCF0 /$1FCF8 /$1FD00
sp_att_enemyproj =      $1FD08  ; 20x
                                ; $1FD08 /$1FD10 /$1FD18 /$1FD20 /$1FD28 /$1FD30 /$1FD38 /$1FD40 /$1FD48 /$1FD50 
                                ; $1FD58 /$1FD60 /$1FD68 /$1FD70 /$1FD78 /$1FD80 /$1FD88 /$1FD90 /$1FD98 /$1FDA0
                                
                                ; 20x
                                ; $1FDA8 /$1FDB0 /$1FDB8 /$1FDC0 /$1FDC8 /$1FDD0 /$1FDD8 /$1FDE0 /$1FDE8 /$1FDF0                               
                                ; $1FDF8 /$1FE00 /$1FE08 /$1FE10 /$1FE18 /$1FE20 /$1FE28 /$1FE30 /$1FE38 /$1FE40
                                
                                ; 20x
                                ; $1FE48 /$1FE50 /$1FE58 /$1FE60 /$1FE68 /$1FE70 /$1FE78 /$1FE80 /$1FE88 /$1FE90
                                ; $1FE98 /$1FEA0 /$1FEA8 /$1FEB0 /$1FEB8 /$1FEC0 /$1FEC8 /$1FED0 /$1FED8 /$1FEE0 

                                ; 20x
                                ; $1FEE8 /$1FEF0 /$1FEF8 /$1FF00 /$1FF08 /$1FF10 /$1FF18 /$1FF20 /$1FF28 /$1FF30
                                ; $1FF38 /$1FF40 /$1FF48 /$1FF50 /$1FF58 /$1FF60 /$1FF68 /$1FF70 /$1FF78 /$1FF80


                                ; 5x
                                ; $1FF88 /$1FF90 /$1FF98 /$1FFA0 /$1FFA8 

                                

sp_att_ui =             $1FFB0  ; 10x
                                ; $1FFB0 /$1FFB8 /$1FFC0 / $1FFC8 /$1FFD0 /$1FFD8 /$1FFE0 /$1FFE8 /$1FFF0 /$1FFF8 

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
    lda #$0A                    ; Sprite index for UI element frame
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1
    MACRO_VERA_SET_ADDR sp_att_ui, 1 ; VRAM_SPRITE_ATTR 
    lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda #8                      ; Write low byte of X
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
    lda #$03                      ; Sprite index for UI element frame
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1 
    MACRO_VERA_SET_ADDR (sp_att_ui + $08), 1 ; VRAM_SPRITE_ATTR << (3 * 1)) , 1
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
    lda #$03                      ; Sprite index for UI element frame
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1 
    MACRO_VERA_SET_ADDR (sp_att_ui + $10) , 1 ; VRAM_SPRITE_ATTR << (3 * 1)) , 1
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
    lda #$03                      ; Sprite index for UI element frame
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1 
    MACRO_VERA_SET_ADDR (sp_att_ui + $18), 1 ; VRAM_SPRITE_ATTR << (3 * 1)) , 1
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