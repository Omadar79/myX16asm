; ===================================================================
; File:         enemy.asm
; Programmer:   Dustin Taub
; Description:  enemy movement patterns, updates, and collision detection
; ===================================================================

.include "x16.inc"
.include "globals.asm"
.include "macros.inc"
.include "sprite.asm"


;|||||||||||||||||||||||||||||||| REFERENCES - ENEMY STATUS  ||||||||||||
;| ***********Enemy status byte bit layout:
;| Bits 4-7: State variable (0-15, supporting 16 different states per pattern)
;| Bits 1-3: Movement pattern ID (0-7, supporting 8 different patterns)
;| Bit 0:    Active flag (0=inactive, 1=active)
;|          7  6  5  4  3  2  1  0
;|          +-----------------------+
;|          State      |Pattern|Act|
;|          +-----------------------+
;|
;| ***********Enemy move byte bit layout:
;| Bits 7  : X 0 = positive, 1 = negative
;| Bits 6-4: X amount to move (0-7)
;| Bits 3  : Y 0 = positive, 1 = negative
;| Bits 2-0: Y amount to move (0-7)
;|          7   6  5  4   3   2  1  0
;|         +-------------------------+
;|          sign x amt  |sign Y amt 
;|         +-------------------------+
;|
;|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
; ----------------------------------- ENEMY BIT FLAGS -----------------------------------
; Enemy status byte flags and masks

enemies_state:              .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; 16 enemies
enemies_move:               .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ;
enemy_x_pos_l:              .byte $00
enemy_x_pos_h:              .byte $00
enemy_y_pos_l:              .byte $00
enemy_y_pos_h:              .byte $00

enemy_speed                 = $02       ; Speed of enemy movement (2 pixels per frame)
ENEMY_ACTIVE_MASK           = %00000001 ; Bit 0: Active flag
ENEMY_PATTERN_MASK          = %00001110 ; Bits 1-3: Pattern ID (0-7)
ENEMY_STATE_MASK            = %11110000 ; Bits 4-7: State variable (0-15)

MAX_ENEMIES               = 2 ; 16         ; Maximum number of enemies
; ==================================================================='
; enemy_init - Initialize enemy data, currently for testing
enemy_init:
    ;TODO set a sprite for each enemy
    lda #$0C                  ; Sprite index for enemy sprite
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1
    MACRO_VERA_SET_ADDR sp_att_enemy, 1 ; VRAM_SPRITE_ATTR 
    lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda #66                    ; Write low byte of X
    sta VERA_DATA0      
    lda #0                      ; Write high byte of X
    sta VERA_DATA0  
    lda #10                   ; Write low byte of Y
    sta VERA_DATA0   
    lda #0                     ; Write high byte of Y
    sta VERA_DATA0  
    lda #%00001100              ; zlevel, sprite in from of layer1
    sta VERA_DATA0 
    lda #%01010011              ; 16x16 , paletter offset 2
    sta VERA_DATA0 


     lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda #8                      ; Write low byte of X
    sta VERA_DATA0      
    lda #0                      ; Write high byte of X
    sta VERA_DATA0  
    lda #15                   ; Write low byte of Y
    sta VERA_DATA0   
    lda #0                     ; Write high byte of Y
    sta VERA_DATA0  
    lda #%00001100              ; zlevel, sprite in from of layer1
    sta VERA_DATA0 
    lda #%01010111              ; 16x16 , paletter offset 07
    sta VERA_DATA0 

    lda #$0D                  ; Sprite index for enemy sprite
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1
    lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda #100                      ; Write low byte of X
    sta VERA_DATA0      
    lda #0                      ; Write high byte of X
    sta VERA_DATA0  
    lda #10                   ; Write low byte of Y
    sta VERA_DATA0   
    lda #0                     ; Write high byte of Y
    sta VERA_DATA0  
    lda #%00001100              ; zlevel, sprite in from of layer1
    sta VERA_DATA0 
    lda #%01010011              ; 16x16 , paletter offset 3
    sta VERA_DATA0 
    ;TODO set a position for each enemy
    rts 

; ===================================================================
; enemy_update_loop - Main loop to update all enemies
;
; ===================================================================
enemy_update_loop:
    ldx #0
@loop:
    jsr get_sprite_position             ; Get the sprite position for this enemy index
    
    lda enemy_y_pos_l; , x
    clc 
    adc enemy_speed ;, x            ; Add speed value
    sta enemy_y_pos_l; , x
    lda enemy_y_pos_h ;, x
    adc #0                         ; Handle carry
    sta enemy_y_pos_h ;, x

    jsr set_sprite_position 
    ;lda enemies_state , x           
    ;and #ENEMY_ACTIVE_MASK              ; Check if enemy is active
;    beq @skip                           ; Skip if inactive
;    bra @enemy_update                   ; Update enemy movement

@skip:
    inx 
    cpx #MAX_ENEMIES                              ; 16 for max enemies, Check if all enemies have been processed
    bne @loop                           ; Loop until all enemies are checked

    rts 


activate_enemy:
    pha                            ; Save pattern ID
    lda enemies_state , x
    ora #ENEMY_ACTIVE_MASK         ; Set active bit
    sta enemies_state , x
    pla                            ; Restore pattern ID
    jsr set_enemy_pattern          ; Set the pattern
    lda #0
    jsr set_enemy_state            ; Initialize state to 0

    rts 

; ===================================================================
; deactivate_enemy - Deactivate an enemy
; Input: X = enemy index
; ===================================================================
;deactivate_enemy:
;    lda enemies_state , x
;    and #%11111110                  ; Clear active bit
;    sta enemies_state , x
;    txa   
;    clc 
;    adc #FIRST_ENEMY_SPRITE 
;    tax 
;    jsr hide_sprite 
;
;    rts 

; ===================================================================
; get_enemy_pattern - Get an enemy's pattern ID
; Input: X = enemy index
; ===================================================================
get_enemy_pattern:
    lda enemies_state , x
    and #ENEMY_PATTERN_MASK  
    lsr                            ; Shift right once to get pattern ID

    rts 

; ===================================================================
; set_enemy_pattern - Set an enemy's pattern ID
; Input: X = enemy index, A = pattern ID (0-7)
; ===================================================================
set_enemy_pattern: 
    and #%00000111                 ; First mask to ensure valid pattern ID (0-7)
    asl                            ; Pattern ID sits at bits 1-3 
    pha                            ; Save the shifted pattern bits
    lda enemies_state, x
    and #%11110001                 ; Clear bits 1-3 the pattern bits
    sta ZP_TEMP                    ; Store temporarily
    pla                            ; Restore shifted pattern bits
    ora ZP_TEMP                    ; Combine with cleared state
    sta enemies_state, x           ; Store updated state

    rts 

; ===================================================================
; get_enemy_state - Get an enemy's state variable
; Input: X = enemy index
; Output: A = state variable (0-15)
; ===================================================================
get_enemy_state:
    lda enemies_state , x
    and #ENEMY_STATE_MASK 
    lsr                            ; Shift right 4 times
    lsr 
    lsr 
    lsr 

    rts 

; ===================================================================
; set_enemy_state - Set an enemy's state variable
; Input: X = enemy index, A = state variable (0-15)
; ===================================================================
set_enemy_state:
    ; First mask to ensure valid state (0-15)
    and #%00001111
    asl                            ; Shift left 4 times
    asl 
    asl 
    asl 

    pha                            ; Save the shifted state bits
    lda enemies_state, x
    and #%00001111                 ; Clear bits 4-7, the state bits
    sta ZP_TEMP                    ; Store temporarily
    pla                            ; Restore shifted state bits
    ora ZP_TEMP                    ; Combine with cleared state
    sta enemies_state, x           ; Store updated state

    rts 

 
; ===================================================================


; ===================================================================
; get_sprite_position - Get the sprite position in VERA memory and copy it to temporary variables 
; Input: X = enemy index
; Output: enemy_x_pos_l, enemy_x_pos_h, enemy_y_pos_l, enemy_y_pos_h
; ===================================================================
get_sprite_position:            ; sp_att_enemy + (X * 8)   
    txa                         
    asl                         ; x2
    asl                         ; x4
    asl                         ; x8 (now A = X * 8)
    clc 
    adc #<sp_att_enemy 
    sta VERA_ADDR_LOW 
    lda #>sp_att_enemy 
    adc #0                      ; Add carry from low byte
    sta VERA_ADDR_HIGH 
    lda #%00010001              ; Auto-increment = 1, bank = 1
    sta VERA_ADDR_BANK 
    lda VERA_DATA0              ; read address
    lda VERA_DATA0              ; read address
    lda VERA_DATA0          
    sta enemy_x_pos_l           ; Write low byte of X position
    lda VERA_DATA0          
    sta enemy_x_pos_h           ; Write high byte of X position
    lda VERA_DATA0          
    sta enemy_y_pos_l           ; Write low byte of Y position
    lda VERA_DATA0 
    sta enemy_y_pos_h           ; Write high byte of Y position
    ;TODO figure out if the sprite is hidden

    rts 

; ===================================================================
; set_sprite_position - set the sprite position in VERA memory 
; Input: X = enemy index
;         enemy_x_pos_l, enemy_x_pos_h, enemy_y_pos_l, enemy_y_pos_h
; ===================================================================
set_sprite_position:         ; sp_att_enemy + (X * 8)    
    txa                         
    asl                         ; x2
    asl                         ; x4
    asl                         ; x8 (now A = X * 8)
    clc 
    adc #<sp_att_enemy 
    sta VERA_ADDR_LOW 
    lda #>sp_att_enemy 
    adc #0                      ; Add carry from low byte
    sta VERA_ADDR_HIGH 
    lda #%00010001              ; Auto-increment = 1, bank = 1
    sta VERA_ADDR_BANK 
    lda VERA_DATA0              ; read address
    lda VERA_DATA0              ; read address
    lda enemy_x_pos_l           ; Write low byte of X position
    sta VERA_DATA0          
    lda enemy_x_pos_h           ; Write high byte of X position
    sta VERA_DATA0          
    lda enemy_y_pos_l           ; Write low byte of Y position
    sta VERA_DATA0          
    lda enemy_y_pos_h           ; Write high byte of Y position
    sta VERA_DATA0 
    ;TODO show or hide sprite if offscreen
    rts 


; ===================================================================
; batch_update_enemy_sprites - Update all enemy sprite positions in a batch
; Use both control settings of the VERA to read from DATA0 and write to DATA1
; ===================================================================
batch_update_enemy_sprites:
   
    lda #1
    sta VERA_CTRL                ; Set DCSEL to 1
    ; Set VERA address to first sprite attribute
    MACRO_VERA_SET_ADDR sp_att_enemy, 1 ; VRAM_SPRITE_ATTR

    stz VERA_CTRL                ; Set DCSEL to 0
    MACRO_VERA_SET_ADDR sp_att_enemy, 1 ; VRAM_SPRITE_ATTR


    ldx #0 
@loop:
    phx ; store where we are in the loop
    lda #1
    sta VERA_CTRL                ; Set DCSEL to 1
    lda VERA_DATA0              ; read address
    lda VERA_DATA0              ; read address
    
    ; grab sprite position and store in temp
    lda VERA_DATA0 
    sta enemy_x_pos_l 
    lda VERA_DATA0 
    sta enemy_x_pos_h 
    lda VERA_DATA0 
    sta enemy_y_pos_l 
    lda VERA_DATA0 
    sta enemy_y_pos_h 
    lda VERA_DATA0 ;skip next q sprite attribute bytes
    lda VERA_DATA0 

    
    lda #0
    sta VERA_CTRL                ; Set DCSEL to 0
    lda VERA_DATA0              ; read address
    lda VERA_DATA0              ; read address
    bra @x_math  
@done_x:
    lda enemy_x_pos_l 
    sta VERA_DATA0   ; store new X position low byte
    lda enemy_x_pos_h 
    sta VERA_DATA0 

    bra @y_math
@done_y:
    lda enemy_y_pos_l 
    sta VERA_DATA0 
    lda enemy_y_pos_h 
    sta VERA_DATA0 
    
    lda VERA_DATA0 ;skip next 2 sprite attribute bytes
    lda VERA_DATA0 

    plx ; retrieve where we are in the loop

    inx                         ; Move to next enemy
    cpx #MAX_ENEMIES           ; Check if all enemies processed
    bne @loop                   ; Loop until all enemies checked

    rts 

@x_math: ; Update X position
    lda enemy_x_pos_l
    ldy #0
    lda enemies_move , x
    and #%01110000         ; get X amount (bits 6-4)
    lsr 
    lsr 
    lsr 
    lsr 
    sta ZP_TEMP            ; store X amount in ZP_TEMP
    lda enemies_move , x
    and #%10000000         ; get X sign (bit 7)
    beq @add_x
    ; negative X
    lda enemy_x_pos_l
    sec 
    sbc ZP_TEMP 
    sta enemy_x_pos_l 
    lda enemy_x_pos_h 
    sbc #0
    sta enemy_x_pos_h 
    bra @done_x 
@add_x:
    lda enemy_x_pos_l 
    clc 
    adc ZP_TEMP 
    sta enemy_x_pos_l 
    lda enemy_x_pos_h 
    adc #0
    sta enemy_x_pos_h 
    bra @done_x 
@done_y_jump:
    bra @done_y
@y_math:    ; Update Y position
    lda enemies_move, x
    and #%00000111         ; get Y amount (bits 2-0)
    sta ZP_TEMP            ; store Y amount in ZP_TEMP
    lda enemies_move, x
    and #%00001000         ; get Y sign (bit 3)
    beq @add_y
    ; negative Y
    lda enemy_y_pos_l 
    sec 
    sbc ZP_TEMP 
    sta enemy_y_pos_l 
    lda enemy_y_pos_h 
    sbc #0 
    sta enemy_y_pos_h 
    bra @done_y_jump
@add_y:
    lda enemy_y_pos_l 
    clc 
    adc ZP_TEMP 
    sta enemy_y_pos_l 
    lda enemy_y_pos_h 
    adc #0
    sta enemy_y_pos_h 
    bra @done_y_jump 

; ===================================================================
; set_enemy_movement - Set an enemy's movement values
; Input: X = enemy index, A = X amount (0-7), Y = Y amount (0-7)
;        Carry set for negative X, overflow set for negative Y
; ===================================================================
set_enemy_movement:
    ; Store X amount (bits 6-4)
    and #%00000111              ; Ensure X amount is 0-7
    asl 
    asl 
    asl 
    asl                         ; Shift to bits 6-4
    sta ZP_TEMP                 ; Store in temp
    
    ; Add X sign bit if carry set
    bcc @handle_y
    lda ZP_TEMP
    ora #%10000000              ; Set X sign bit
    sta ZP_TEMP
    
@handle_y:
    ; Store Y amount (bits 2-0)
    tya
    and #%00000111              ; Ensure Y amount is 0-7
    ora ZP_TEMP                 ; Combine with X values
    sta ZP_TEMP 
    
    ; Add Y sign bit if overflow set
    bvc @finish 
    lda ZP_TEMP 
    ora #%00001000              ; Set Y sign bit
    sta ZP_TEMP 
    
@finish:
    lda ZP_TEMP 
    sta enemies_move, x         ; Store final movement byte

    rts 



; =================================================================== TEMP PATTERN FUNCTIONS
pattern_functions:
    .word pattern_test_all 
    .word pattern_test_all 
    .word pattern_test_all 
    .word pattern_test_all 
    .word pattern_test_all 

; ===================================================================
; pattern_straight_down - Make enemy move straight down
; Input: X = enemy index
; ===================================================================
pattern_test_all:
    ; Only update Y position (vertical movement)
    lda enemy_y_pos_l; , x
    clc 
    adc enemy_speed ;, x            ; Add speed value
    sta enemy_y_pos_l; , x
    lda enemy_y_pos_h ;, x
    adc #0                         ; Handle carry
    sta enemy_y_pos_h ;, x
    
    ; Check if enemy is off-screen - straight down never allows offscreen
 ;   lda #ENEMY_MOVE_NORMAL         ; No special movement flags
;    jsr check_enemy_offscreen 
;    bcs @deactivate                ; If offscreen, deactivate
;    jsr update_enemy_sprite 

    rts 
;@deactivate:
;    jsr deactivate_enemy           ; Use standardized deactivation
;
;    rts 