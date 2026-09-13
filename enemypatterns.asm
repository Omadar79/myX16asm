; ===================================================================
; File:         enemypatterns.asm
; Programmer:   Dustin Taub
; Description:  enemy movement patterns
; ===================================================================

.ifndef _ENEMY_PATTERNS
ENEMY_PATTERNS = 1

.include "x16.inc"
.include "globals.asm"
.include "macros.inc"
.include "sprite.asm"
.include "sinewaves.asm"
.include "enemy.asm"





; Pattern IDs
PATTERN_STRAIGHT_DOWN = 0
PATTERN_SINE_WAVE = 1
PATTERN_CIRCLE = 2
PATTERN_ZIGZAG = 3
PATTERN_SWOOP = 4

; Enemy movement flags - used to indicate special behavior
ENEMY_MOVE_NORMAL      = 0     ; Standard behavior (permanent deactivation when offscreen)
ENEMY_MOVE_ALLOW_SIDES = 1     ; Can temporarily go off the sides of the screen
ENEMY_MOVE_ALLOW_TOP   = 2     ; Can temporarily go off the top of the screen

; These are the sprite functions that are part of sprite.asm
; but I'm defining them here for clarity
update_sprite_position = $C000 
hide_sprite = $C000            
pattern_functions:
    .word pattern_straight_down 
    .word pattern_sine_wave 
    .word pattern_circle 
    .word pattern_zigzag 
    .word pattern_swoop 



; ===================================================================
; pattern_straight_down - Make enemy move straight down
; Input: X = enemy index
; ===================================================================
pattern_straight_down:
    ; Only update Y position (vertical movement)
    lda enemy_y_pos_l, x
    clc 
    adc enemy_speed, x             ; Add speed value
    sta enemy_y_pos_l, x
    lda enemy_y_pos_h, x
    adc #0                         ; Handle carry
    sta enemy_y_pos_h, x
    
    ; Check if enemy is off-screen - straight down never allows offscreen
    lda #ENEMY_MOVE_NORMAL         ; No special movement flags
    jsr check_enemy_offscreen
    bcs @deactivate                ; If offscreen, deactivate
    
    ; Update sprite position
    jsr update_enemy_sprite
    rts
    
@deactivate:
    jsr deactivate_enemy           ; Use standardized deactivation
    rts


; ===================================================================
; pattern_sine_wave - Make enemy move in a sine wave pattern
; Input: X = enemy index
; ===================================================================
pattern_sine_wave:
    ; Update angle
    inc enemy_angle, x             ; Increment angle for continuous movement
    
    ; Calculate new X position using sine
    lda enemy_angle, x
    jsr get_sine                    ; Get sine value in A (0-255)
    
    ; Convert from 0-255 to -128 to 127 range
    sec 
    sbc #128                        ; A now contains -128 to 127
    
    ; If using only positive math, do this instead:
    ; Scale the sine value for amplitude
    sec 
    sbc #128                        ; Convert from 0-255 to -128 to 127
    bcs @positive_value             ; If >= 128 (positive result)
    
    ; Handle negative value
    eor #$FF                        ; Invert bits
    clc 
    adc #1                          ; Two's complement (get absolute value)
    sta ZP_TEMP                    ; Store absolute value
    
    lda enemy_x_pos_l, x
    sec 
    sbc ZP_TEMP                    ; Subtract from position
    sta enemy_x_pos_l, x
    lda enemy_x_pos_h, x
    sbc #0                          ; Handle borrow
    sta enemy_x_pos_h, x
    bra @update_y
    
@positive_value:
    ; Handle positive value
    sta ZP_TEMP                    ; Store value
    lda enemy_x_pos_l, x
    clc 
    adc ZP_TEMP                    ; Add to position
    sta enemy_x_pos_l, x
    lda enemy_x_pos_h, x
    adc #0                          ; Handle carry
    sta enemy_x_pos_h, x
    
@update_y:
    ; Update Y position - always move downward at constant speed
    lda enemy_y_pos_l, x
    clc 
    adc enemy_speed, x              ; Add speed value to Y position
    sta enemy_y_pos_l, x
    lda enemy_y_pos_h, x
    adc #0                          ; Handle carry
    sta enemy_y_pos_h, x
    
    ; Check if enemy is off-screen - sine wave can go temporarily off the sides
    lda #ENEMY_MOVE_ALLOW_SIDES     ; Allow temporarily going off the sides
    jsr check_enemy_offscreen
    bcs @deactivate                 ; If permanently offscreen, deactivate
    
    ; Update sprite position
    jsr update_enemy_sprite
    rts
    
@deactivate:
    jsr deactivate_enemy            ; Use standardized deactivation
    rts

; ===================================================================
; pattern_zigzag - Make enemy move in a zigzag pattern
; Input: X = enemy index
; ===================================================================
pattern_zigzag:
    ; Check current direction
    lda enemy_direction, x
    bne @moving_left
    
@moving_right:
    ; Move right
    lda enemy_x_pos_l, x
    clc 
    adc enemy_speed, x
    sta enemy_x_pos_l, x
    lda enemy_x_pos_h, x
    adc #0
    sta enemy_x_pos_h, x
    
    ; Check if reached right edge
    lda enemy_x_pos_h, x
    bne @change_to_left       ; If high byte != 0, too far right
    lda enemy_x_pos_l, x
    cmp #SCREEN_MAX_X_L
    bcc @update_y             ; If X < max X, continue right
    
@change_to_left:
    ; Change direction to left
    lda #1
    sta enemy_direction, x
    bra @update_y
    
@moving_left:
    ; Move left
    lda enemy_x_pos_l, x
    sec
    sbc enemy_speed, x
    sta enemy_x_pos_l, x
    lda enemy_x_pos_h, x
    sbc #0
    sta enemy_x_pos_h, x
    
    ; Check if reached left edge
    lda enemy_x_pos_h, x
    bne @at_left_edge         ; If high byte != 0, check if negative
    lda enemy_x_pos_l, x
    cmp #SCREEN_MIN_X_L
    bcs @update_y             ; If X >= min X, continue left
    
@at_left_edge:
    lda enemy_x_pos_h, x
    bpl @update_y             ; If high byte is positive, continue
    
    ; Change direction to right
    lda #0
    sta enemy_direction, x
    
@update_y:
    ; Always move down
    lda enemy_y_pos_l, x
    clc 
    adc enemy_speed, x
    sta enemy_y_pos_l, x
    lda enemy_y_pos_h, x
    adc #0
    sta enemy_y_pos_h, x
    
    ; Check if enemy is off-screen - zigzag can go temporarily off the sides
    lda #ENEMY_MOVE_ALLOW_SIDES     ; Allow temporarily going off the sides
    jsr check_enemy_offscreen
    bcs @deactivate                 ; If permanently offscreen, deactivate
    
    ; Update sprite position
    jsr update_enemy_sprite
    rts
    
@deactivate:
    jsr deactivate_enemy            ; Use standardized deactivation
    rts

; ===================================================================
; pattern_circle - Make enemy move in a circular pattern
; Input: X = enemy index
; ===================================================================
pattern_circle:
    ; Update angle
    inc enemy_angle, x             ; Increment angle for continuous movement
    
    ; Calculate new X position using cosine
    lda enemy_angle, x
    jsr get_sine                   ; Get sine value for X movement
    
    ; Scale the sine value for X amplitude (circle radius)
    sec 
    sbc #128                       ; Convert from 0-255 to -128 to 127
    
    ; Get the absolute value and apply in correct direction
    bcs @positive_x               ; If >= 128 (positive result)
    
    ; Handle negative value for X
    eor #$FF                        
    clc 
    adc #1                         ; Two's complement (get absolute value)
    sta ZP_TEMP                   ; Store absolute value
    
    lda enemy_base_x_l, x          ; Use base X position (center of circle)
    sec 
    sbc ZP_TEMP                   ; Subtract from position
    sta enemy_x_pos_l, x
    lda enemy_base_x_h, x
    sbc #0                         ; Handle borrow
    sta enemy_x_pos_h, x
    bra @calculate_y
    
@positive_x:
    ; Handle positive value for X
    sta ZP_TEMP                   ; Store value
    
    lda enemy_base_x_l, x          ; Use base X position (center of circle)
    clc 
    adc ZP_TEMP                   ; Add to position
    sta enemy_x_pos_l, x
    lda enemy_base_x_h, x
    adc #0                         ; Handle carry
    sta enemy_x_pos_h, x
    
@calculate_y:
    ; Calculate Y position using cosine (90 degrees offset from sine)
    lda enemy_angle, x
    clc 
    adc #64                        ; Add 90 degrees (64 is 1/4 of 256)
    jsr get_sine                   ; Get sine value for Y movement
    
    ; Scale the sine value for Y amplitude
    sec 
    sbc #128                       ; Convert from 0-255 to -128 to 127
    
    ; Get the absolute value and apply in correct direction
    bcs @positive_y                ; If >= 128 (positive result)
    
    ; Handle negative value for Y
    eor #$FF
    clc 
    adc #1                         ; Two's complement (get absolute value)
    sta ZP_TEMP                   ; Store absolute value
    
    lda enemy_base_y_l, x          ; Use base Y position (center of circle + descent)
    sec 
    sbc ZP_TEMP                   ; Subtract from position
    sta enemy_y_pos_l, x
    lda enemy_base_y_h, x
    sbc #0                         ; Handle borrow
    sta enemy_y_pos_h, x
    bra @update_base_y
    
@positive_y:
    ; Handle positive value for Y
    sta ZP_TEMP                   ; Store value
    
    lda enemy_base_y_l, x          ; Use base Y position (center of circle + descent)
    clc 
    adc ZP_TEMP                   ; Add to position
    sta enemy_y_pos_l, x
    lda enemy_base_y_h, x
    adc #0                         ; Handle carry
    sta enemy_y_pos_h, x
    
@update_base_y:
    ; Make circle descend by increasing base_y
    lda enemy_base_y_l, x
    clc 
    adc #1                         ; Slow descent (increase for faster)
    sta enemy_base_y_l, x
    lda enemy_base_y_h, x
    adc #0                         ; Handle carry
    sta enemy_base_y_h, x
    
    ; Check if enemy is off-screen - circle can go off sides temporarily
    lda #ENEMY_MOVE_ALLOW_SIDES     ; Allow temporarily going off the sides
    jsr check_enemy_offscreen
    bcs @deactivate                 ; If permanently offscreen, deactivate
    
    ; Update sprite position
    jsr update_enemy_sprite
    rts
    
@deactivate:
    jsr deactivate_enemy            ; Use standardized deactivation
    rts

; ===================================================================
; pattern_swoop - Make enemy move in a swooping pattern toward player position
; Input: X = enemy index
; ===================================================================
pattern_swoop:
    ; First move straight down a bit
    lda enemy_state, x
    bne @diving                   ; If state is not 0, we're already diving
    
    ; Increment distance moved
    inc enemy_counter, x
    lda enemy_counter, x
    cmp #30                       ; Wait until we've moved down 30 pixels
    bcc @move_down                ; If < 30, keep moving down
    
    ; Start diving - calculate angle toward player
    lda #1
    sta enemy_state, x            ; Set state to diving
    
    ; Calculate direction to player (simplified targeting)
    lda player_x_pos_l
    cmp enemy_x_pos_l, x
    bcc @player_left              ; If player X < enemy X, player is left
    
    ; Player is right of enemy - store right-down direction
    lda #1
    sta enemy_direction, x         ; 1 = right-down
    bra @move_down
    
@player_left:
    ; Player is left of enemy - store left-down direction
    lda #2
    sta enemy_direction, x         ; 2 = left-down
    
@move_down:
    ; Move straight down until ready to dive
    lda enemy_state, x
    bne @diving                   ; If diving state, skip straight-down
    
    lda enemy_y_pos_l, x
    clc
    adc enemy_speed, x
    sta enemy_y_pos_l, x
    lda enemy_y_pos_h, x
    adc #0
    sta enemy_y_pos_h, x
    bra @check_bounds
    
@diving:
    ; Move in the diving direction
    lda enemy_direction, x
    cmp #1
    beq @dive_right
    
@dive_left:
    ; Move left and down
    lda enemy_x_pos_l, x
    sec 
    sbc enemy_speed, x            ; Move left at speed
    sta enemy_x_pos_l, x
    lda enemy_x_pos_h, x
    sbc #0
    sta enemy_x_pos_h, x
    
    ; Move down faster while diving
    lda enemy_y_pos_l, x
    clc 
    adc enemy_speed, x
    adc enemy_speed, x            ; Double speed for diving
    sta enemy_y_pos_l, x
    lda enemy_y_pos_h, x
    adc #0
    sta enemy_y_pos_h, x
    bra @check_bounds
    
@dive_right:
    ; Move right and down
    lda enemy_x_pos_l, x
    clc 
    adc enemy_speed, x            ; Move right at speed
    sta enemy_x_pos_l, x
    lda enemy_x_pos_h, x
    adc #0
    sta enemy_x_pos_h, x
    
    ; Move down faster while diving
    lda enemy_y_pos_l, x
    clc 
    adc enemy_speed, x
    adc enemy_speed, x            ; Double speed for diving
    sta enemy_y_pos_l, x
    lda enemy_y_pos_h, x
    adc #0
    sta enemy_y_pos_h, x
    
@check_bounds:
    ; Check if enemy is off-screen - swoop can temporarily go off the sides
    lda #ENEMY_MOVE_ALLOW_SIDES     ; Allow temporarily going off the sides
    jsr check_enemy_offscreen
    bcs @deactivate                 ; If permanently offscreen, deactivate
    
    ; Update sprite position
    jsr update_enemy_sprite
    rts 
    
@deactivate:
    jsr deactivate_enemy            ; Use standardized deactivation
    rts 

.endif ; ENEMY_PATTERNS