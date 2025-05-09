; ===================================================================
; File:         proj_manager.asm
; Programmer:   Dustin Taub
; Description:  Projectile management system for the game
; ===================================================================
.ifndef _PROJECTILES_ASM
_PROJECTILES_ASM = 1

.include "x16.inc"
.include "globals.asm"
.include "sprite.asm"

; ===================================================================
; Constants
; ===================================================================
PROJ_MAX_COUNT          = 10    ; Maximum number of player projectiles
PROJ_SPEED              = 5     ; Base projectile speed (pixels per frame)
PROJ_LIFETIME           = 90    ; Maximum lifetime in frames (1.5 seconds at 60fps)
PROJ_INACTIVE           = 0     ; Projectile state: inactive
PROJ_ACTIVE             = 1     ; Projectile state: active

; Projectile types
PROJ_TYPE_STANDARD      = 0     ; Standard shot
PROJ_TYPE_RAPID         = 1     ; Rapid fire
PROJ_TYPE_SPREAD        = 2     ; Spread shot
PROJ_TYPE_POWER         = 3     ; Power shot

; Player weapon type
player_weapon_type:     .byte 0     ; 0=standard, 1=rapid, 2=spread, 3=power

; ===================================================================
; Data Structures
; ===================================================================
; Projectile data structure arrays (10 projectiles)
proj_states:            .res PROJ_MAX_COUNT, 0  ; 0=inactive, 1=active
proj_x_pos_l:           .res PROJ_MAX_COUNT, 0  ; X position (low byte)
proj_x_pos_h:           .res PROJ_MAX_COUNT, 0  ; X position (high byte)
proj_y_pos_l:           .res PROJ_MAX_COUNT, 0  ; Y position (low byte)
proj_y_pos_h:           .res PROJ_MAX_COUNT, 0  ; Y position (high byte)
proj_dir_x:             .res PROJ_MAX_COUNT, 0  ; X direction (-1, 0, 1)
proj_dir_y:             .res PROJ_MAX_COUNT, 0  ; Y direction (-1, 0, 1)
proj_lifetime:          .res PROJ_MAX_COUNT, 0  ; Frames remaining before despawn
proj_type:              .res PROJ_MAX_COUNT, 0  ; Projectile type (for different weapons)
proj_cooldown:          .byte 0                 ; Global cooldown for firing

; Direction lookup tables (8 directions - 0=up, 1=up-right, 2=right, etc.)
; Instead of using negative values, we'll use:
; 0 = no movement, 1 = positive movement, 2 = negative movement
direction_x_table:
    .byte  0,  1,  1,  1,  0,  2,  2,  2  ; X components (0=none, 1=right, 2=left)
direction_y_table:
    .byte  2,  2,  0,  1,  1,  1,  0,  2  ; Y components (0=none, 1=down, 2=up)

; ===================================================================
; init_projectiles - Initialize the projectile system
; ===================================================================
init_projectiles:
    ldx #0                      ; Start with projectile 0
@loop:
    lda #PROJ_INACTIVE          ; Set state to inactive
    sta proj_states,x
    
    inx                         ; Next projectile
    cpx #PROJ_MAX_COUNT         ; Check if we've done all projectiles
    bne @loop                   ; If not, loop back
    
    stz proj_cooldown           ; Reset cooldown timer
    rts

; ===================================================================
; fire_projectile - Create a new projectile
; Inputs:
;   X = Projectile type (0=standard, 1=spread, etc.)
;   ZP_PTR_1, ZP_PTR_1+1 = Starting X position
;   ZP_PTR_2, ZP_PTR_2+1 = Starting Y position
;   A = Direction (0=up, 1=up-right, 2=right, etc. - 8 directions)
; Returns:
;   Carry clear if projectile created, set if no slots available
; ===================================================================
fire_projectile:
    pha                         ; Save direction
    txa                         ; Save projectile type
    pha 

    ; Check cooldown
    lda proj_cooldown 
    bne @no_slots               ; If cooldown active, don't fire
    
    ; Find a free projectile slot
    ldx #0                      ; Start with projectile 0
@find_slot:
    lda proj_states,x           ; Check if this slot is free
    beq @slot_found             ; If it's inactive, use this slot
    
    inx                         ; Try next slot
    cpx #PROJ_MAX_COUNT         ; Have we checked all slots?
    bne @find_slot              ; If not, continue searching
    
@no_slots:
    ; No slots available
    pla                         ; Clean up stack
    pla 
    sec                         ; Set carry to indicate failure
    rts 
    
@slot_found:
    ; Set cooldown based on projectile type
    pla                         ; Get projectile type
    pha                         ; Save it again
    
    ; Different cooldowns for different weapon types
    cmp #PROJ_TYPE_RAPID
    beq @rapid_cooldown
    cmp #PROJ_TYPE_SPREAD
    beq @spread_cooldown
    cmp #PROJ_TYPE_POWER
    beq @power_cooldown
    
    ; Standard shot cooldown
    lda #15                     ; ~1/4 second at 60fps
    bra @set_cooldown
    
@rapid_cooldown:
    lda #5                      ; Very quick cooldown
    bra @set_cooldown
    
@spread_cooldown:
    lda #20                     ; Longer cooldown for spread
    bra @set_cooldown
    
@power_cooldown:
    lda #30                     ; Longest cooldown for power shot
    
@set_cooldown:
    sta proj_cooldown           ; Set cooldown timer
    
    ; Set projectile as active
    lda #PROJ_ACTIVE
    sta proj_states,x
    
    ; Set projectile position (copy from input parameters)
    lda ZP_PTR_1
    sta proj_x_pos_l,x
    lda ZP_PTR_1+1
    sta proj_x_pos_h,x
    lda ZP_PTR_2
    sta proj_y_pos_l,x
    lda ZP_PTR_2+1
    sta proj_y_pos_h,x
    
    ; Set projectile type
    pla                         ; Restore projectile type from stack
    sta proj_type,x
    
    ; Set projectile direction based on input
    pla                         ; Restore direction from stack
    pha                         ; Save it again for later
    
    ; Convert from 8-direction format to x/y components
    tay                         ; Direction in Y for lookup
    lda direction_x_table,y     ; Get X component
    sta proj_dir_x,x
    lda direction_y_table,y     ; Get Y component
    sta proj_dir_y,x
    
    ; Set projectile lifetime
    lda #PROJ_LIFETIME
    sta proj_lifetime,x
    
    ; Play sound effect based on projectile type
    pla                         ; Restore direction (don't need it anymore)
    phx                         ; Save X register
    
    lda proj_type,x
    cmp #PROJ_TYPE_RAPID 
    beq @rapid_sound
    cmp #PROJ_TYPE_SPREAD 
    beq @spread_sound
    cmp #PROJ_TYPE_POWER 
    beq @power_sound
    
    ; Standard shot sound
    jsr play_sfx_blaster 
    bra @update_sprite
    
@rapid_sound:
    jsr play_sfx_laser 
    bra @update_sprite
    
@spread_sound:
    jsr play_sfx_photon 
    bra @update_sprite
    
@power_sound:
    jsr play_sfx_plasma 
    
@update_sprite:
    plx                         ; Restore X register
    jsr update_projectile_sprite
    clc                         ; Clear carry to indicate success
    rts 

; ===================================================================
; update_projectiles - Update all projectiles (call once per frame)
; ===================================================================
update_projectiles:
    ; Decrement cooldown if active
    lda proj_cooldown
    beq @update_proj_loop
    dec proj_cooldown
    
@update_proj_loop:
    ldx #0                      ; Start with projectile 0
    
@update_one:
    lda proj_states,x           ; Check if this projectile is active
    beq @next_projectile        ; If inactive, skip to next one
    
    ; Decrement lifetime
    dec proj_lifetime,x         ; Reduce lifetime by 1
    beq @deactivate             ; If lifetime reached 0, deactivate
    
    ; Update position (call subroutine instead of inline code)
    jsr update_projectile_pos
    
    ; Check bounds (call subroutine)
    jsr check_projectile_bounds
    bcs @deactivate             ; If out of bounds, deactivate
    
    ; Update sprite
    jsr update_projectile_sprite
    jmp @next_projectile
    
@deactivate:
    lda #PROJ_INACTIVE
    sta proj_states,x
    jsr disable_projectile_sprite
    
@next_projectile:
    inx                         ; Move to next projectile
    cpx #PROJ_MAX_COUNT         ; Have we processed all projectiles?
    bne @update_one             ; If not, continue
    rts

; ===================================================================
; update_projectile_pos - Update position of a projectile
; Input: X = projectile index
; ===================================================================
update_projectile_pos:
    ; Update X position
    lda proj_dir_x,x            ; Get X direction
    beq @update_y               ; If 0, no change in X
    
    cmp #1                      ; Check if direction is positive (right)
    bne @move_left              ; If not 1, must be 2 (left)
    
    ; Move right
    lda proj_x_pos_l,x          ; Get X low byte
    clc
    adc #PROJ_SPEED             ; Add speed
    sta proj_x_pos_l,x          ; Store result
    lda proj_x_pos_h,x          ; Get X high byte
    adc #0                      ; Add carry
    sta proj_x_pos_h,x          ; Store result
    jmp @update_y
    
@move_left:
    lda proj_x_pos_l,x          ; Get X low byte
    sec
    sbc #PROJ_SPEED             ; Subtract speed
    sta proj_x_pos_l,x          ; Store result
    lda proj_x_pos_h,x          ; Get X high byte
    sbc #0                      ; Subtract borrow
    sta proj_x_pos_h,x          ; Store result
    
@update_y:
    ; Update Y position
    lda proj_dir_y,x            ; Get Y direction
    beq @done                   ; If 0, no change in Y
    
    cmp #1                      ; Check if direction is positive (down)
    bne @move_up                ; If not 1, must be 2 (up)
    
    ; Move down
    lda proj_y_pos_l,x          ; Get Y low byte
    clc
    adc #PROJ_SPEED             ; Add speed
    sta proj_y_pos_l,x          ; Store result
    lda proj_y_pos_h,x          ; Get Y high byte
    adc #0                      ; Add carry
    sta proj_y_pos_h,x          ; Store result
    rts
    
@move_up:
    lda proj_y_pos_l,x          ; Get Y low byte
    sec
    sbc #PROJ_SPEED             ; Subtract speed
    sta proj_y_pos_l,x          ; Store result
    lda proj_y_pos_h,x          ; Get X high byte
    sbc #0                      ; Subtract borrow
    sta proj_y_pos_h,x          ; Store result
@done:
    rts

; ===================================================================
; check_projectile_bounds - Check if projectile is out of bounds
; Input: X = projectile index
; Output: Carry set if out of bounds, clear if in bounds
; ===================================================================
check_projectile_bounds:
    ; Check X position (too far right)
    lda proj_x_pos_h,x          ; High byte of X position
    cmp #SCREEN_MAX_X_H         ; Compare with max X high byte
    bcc @check_x_min            ; If less, check X minimum
    bne @out_of_bounds          ; If greater, out of bounds
    lda proj_x_pos_l,x          ; Low byte of X position
    cmp #SCREEN_MAX_X_L         ; Compare with max X low byte
    bcs @out_of_bounds          ; If greater or equal, out of bounds
    
@check_x_min:
    ; Check X position (too far left)
    lda proj_x_pos_h,x          ; High byte of X position
    cmp #SCREEN_MIN_X_H         ; Compare with min X high byte
    bne @check_y_max            ; If not equal, check Y maximum
    lda proj_x_pos_l,x          ; Low byte of X position
    cmp #SCREEN_MIN_X_L         ; Compare with min X low byte
    bcc @out_of_bounds          ; If less, out of bounds
    
@check_y_max:
    ; Check Y position (too far down)
    lda proj_y_pos_h,x          ; High byte of Y position
    cmp #SCREEN_MAX_Y_H         ; Compare with max Y high byte
    bcc @check_y_min            ; If less, check Y minimum
    bne @out_of_bounds          ; If greater, out of bounds
    lda proj_y_pos_l,x          ; Low byte of Y position
    cmp #SCREEN_MAX_Y_L         ; Compare with max Y low byte
    bcs @out_of_bounds          ; If greater or equal, out of bounds
    
@check_y_min:
    ; Check Y position (too far up)
    lda proj_y_pos_h,x          ; High byte of Y position
    cmp #SCREEN_MIN_Y_H         ; Compare with min Y high byte
    bne @in_bounds              ; If not equal, in bounds
    lda proj_y_pos_l,x          ; Low byte of Y position
    cmp #SCREEN_MIN_Y_L         ; Compare with min Y low byte
    bcc @out_of_bounds          ; If less, out of bounds
    
@in_bounds:
    clc                         ; Clear carry to indicate in bounds
    rts 
    
@out_of_bounds:
    sec                         ; Set carry to indicate out of bounds
    rts 

; ===================================================================
; update_projectile_sprite - Update sprite attributes for projectile
; Inputs:
;   X = Projectile index
; ===================================================================
update_projectile_sprite:
    phx                         ; Save X register to the stac
    ; Calculate sprite attribute address
    txa                         ; Get projectile index
    asl                         ; Multiply by 8 (each sprite attr is 8 bytes)
    asl 
    asl 
    clc 
    adc #<sp_att_playerproj     ; Add base address
    sta ZP_PTR_3                ; Store low byte
    lda #>sp_att_playerproj 
    adc #0                      ; Add carry
    sta ZP_PTR_3 + 1            ; Store high byte
    
    ; Set VERA address to sprite attribute
    lda ZP_PTR_3 + 1            ; Set high byte
    sta VERA_ADDR_HIGH 
    lda ZP_PTR_3                ; Set low byte
    sta VERA_ADDR_LOW 
    lda #%00010001              ; Auto-increment = 1, bank = 1
    sta VERA_ADDR_BANK 
    
    ; Determine which sprite frame to use based on projectile type and direction
    plx                         ; Restore X register to get projectile index
    phx                         ; Save it again
    
    lda proj_type , x           ; Get projectile type
    asl                         ; Multiply by 8 (8 directions per type)
    asl 
    asl 
    
    ; Add direction offset (0-7)
    ldy proj_dir_y , x          ; Check Y direction first
    cpy #2                      ; Is it up (2)?
    beq @dir_up                 
    cpy #1                      ; Is it down (1)?
    beq @dir_down
    ldy proj_dir_x , x          ; Y is 0, check X
    cpy #2                      ; Is it left (2)?
    beq @dir_left
    clc 
    adc #2                      ; Right (dir 2)
    bra @set_sprite_frame
@dir_up:
    ldy proj_dir_x , x      ; Check X component
    cpy #2                  ; Is it left (2)?
    beq @dir_up_left        
    cpy #0                  ; Is it center (0)?
    beq @dir_up_straight    
    clc 
    adc #1                  ; Up-right (dir 1)
    bra @set_sprite_frame
@dir_up_straight:
    clc 
    adc #0                  ; Up (dir 0)
    bra @set_sprite_frame
@dir_up_left:
    clc 
    adc #7                  ; Up-left (dir 7)
    bra @set_sprite_frame
@dir_left:
    clc 
    adc #6                  ; Left (dir 6)
    bra @set_sprite_frame
@dir_down:
    ldy proj_dir_x , x      ; Check X component
    cpy #2                  ; Is it left (2)?
    beq @dir_down_left      
    cpy #0                  ; Is it center (0)?
    beq @dir_down_straight  
    clc 
    adc #3                  ; Down-right (dir 3)
    bra @set_sprite_frame
@dir_down_straight:
    clc 
    adc #4                  ; Down (dir 4)
    bra @set_sprite_frame
@dir_down_left:
    clc 
    adc #5                  ; Down-left (dir 5)
@set_sprite_frame:
    ; A now contains projectile frame index
    jsr get_small_sprite_frame_addr ; Get the address for this small sprite
    
    ; Write sprite attributes to VERA
    lda ZP_PTR_1                ; Sprite frame address (low byte)
    sta VERA_DATA0 
    lda ZP_PTR_1+1              ; Sprite frame address (high byte)
    sta VERA_DATA0 
    plx                         ; Restore X register to get projectile index
    
    lda proj_x_pos_l,x          ; X position (low byte)
    sta VERA_DATA0 
    lda proj_x_pos_h,x          ; X position (high byte)
    sta VERA_DATA0 
    lda proj_y_pos_l,x          ; Y position (low byte)
    sta VERA_DATA0 
    lda proj_y_pos_h,x          ; Y position (high byte)
    sta VERA_DATA0 
    lda #%00001100              ; Z-depth: In front of layer 1
    sta VERA_DATA0 
    
    ; Set different color/size based on projectile type
    lda proj_type,x
    cmp #PROJ_TYPE_POWER
    beq @power_sprite
    cmp #PROJ_TYPE_SPREAD
    beq @spread_sprite
    cmp #PROJ_TYPE_RAPID
    beq @rapid_sprite
    
    ; Standard projectile
    lda #%00010000              ; 8x8 sprite, palette offset 0
    bra @write_mode
    
@rapid_sprite:
    lda #%00010001              ; 8x8 sprite, palette offset 1
    bra @write_mode
    
@spread_sprite:
    lda #%00010010              ; 8x8 sprite, palette offset 2
    bra @write_mode
    
@power_sprite:
    lda #%00010011              ; 8x8 sprite, palette offset 3
    
@write_mode:
    sta VERA_DATA0
    rts 

; ===================================================================
; disable_projectile_sprite - Disable sprite for projectile
; Inputs:
;   X = Projectile index
; ===================================================================
disable_projectile_sprite:
    phx                         ; Save X register
    
    ; Calculate sprite attribute address
    txa                         ; Get projectile index
    asl                         ; Multiply by 8 (each sprite attr is 8 bytes)
    asl 
    asl 
    clc 
    adc #<sp_att_playerproj     ; Add base address
    sta ZP_PTR_3                ; Store low byte
    lda #>sp_att_playerproj 
    adc #0                      ; Add carry
    sta ZP_PTR_3 + 1            ; Store high byte
    
    ; Set VERA address to sprite attribute Z-depth byte (6th byte)
    lda ZP_PTR_3 + 1            ; Set high byte
    sta VERA_ADDR_HIGH 
    lda ZP_PTR_3                ; Set low byte 
    clc 
    adc #6                      ; Skip to Z-depth byte
    sta VERA_ADDR_LOW 
    lda #%00000001              ; No auto-increment, bank = 1
    sta VERA_ADDR_BANK 
    ; Disable sprite by setting Z-depth to 0
    lda #0                      ; Z-depth 0 = disabled
    sta VERA_DATA0 
    plx                         ; Restore X register
    rts 



.endif