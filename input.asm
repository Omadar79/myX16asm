; ===================================================================
; File:         input.asm
; Programmer:   Dustin Taub
; Description:  Input handling for joystick/keyboard for game and menus
;===================================================================
.ifndef _INPUT_ASM
_INPUT_ASM = 1

.include "x16.inc"
.include "globals.asm"
.include "soundfx.asm"
.include "projectiles.asm" 

;|||||||||||||||||||||||||||||||| REFERENCES - JOYSTICK  ||||||||||||
;| ***********kernal supported joystick buttons to keys
;| CURSOR             to NES/SNES DPAD
;| LEFT-CTRL or key-X to NES A or SNES B button
;| LEFT-ALT or key-Z  to NES B or SNES B button
;| key-S              to SNES X button
;| key-A              to SNES Y button
;| key-D              to SHOULDER LEFT
;| key-C              to SHOULDER RIGHT
;| SPACE              to NES/SNES START button
;| LEFT-SHIFT         to NES/SNES SELECT button
;| 
;| joystick number passed into A register (0 for the keyboard joystick and 1 through 4 for SNES controllers)
;| $FF56 *********** JOYSTICK_GET 
;| A register, byte 0: NES/SNES lower partial
;|    NES:  A | B | SELECT | START | UP | DOWN | LEFT | RIGHT
;|    SNES: B | Y | SELECT | START | UP | DOWN | LEFT | RIGHT
;| X register, byte 1: = SNES upper partial
;|    SNES: A | X | SHOULDER LEFT | SHOULDER RIGHT | 1  | 1  | 1  | 1
;| Y register, byte 2: = Joystick Present?    
;|   $00 if no joystick present, $FF if joystick present
;| NOTE: 0 bit means button down
;| NOTE: keyboard allow LEFT and RIGHT and/or UP and DOWN to be pressed at the same time.
;|
;|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||


; Input Constants
KEY_ESCAPE = $1B                  ; ESC key
KEY_RETURN = $0D                  ; Return/Enter key
KEY_UP     = $91                  ; Cursor up
KEY_DOWN   = $11                  ; Cursor dow
MENU_DELAY_TIME  = 10            ; Frames to wait between menu movements

; Input state variables
joystick_state:        .byte 0   ; current state of the joystick
joystick_latch:        .byte $CF ; last state of the joystick
menu_selection:        .byte 0   ; Current selected menu item
menu_delay:            .byte 0   ; Delay between menu movements



; ===================================================================
; Input Handling for Start Menu State
; ===================================================================
check_start_menu_input:
    jsr GETIN                       ; Get keyboard input
    cmp #KEY_RETURN                 ; Check if return key is pressed
    beq @start_game                 ; reset player direction to 0 (no move)
    jsr JOYSTICK_SCAN               ; Scan the joystick
    lda #1                          ; joystick 1
    jsr JOYSTICK_GET                ; check the first joystick 
    cpy #0  
    beq @check_prev_state           ; if no joystick fall through to check keyboard joystick
    lda #0                          ; keyboard joystick 0
    jsr JOYSTICK_GET   
@check_prev_state:  
    sta joystick_state             ; save the current state of the joystick
    eor joystick_latch             ; exclusive OR the last state to check for button state changes
    sta joystick_latch             ; save this for next time to see state changes
    lda joystick_state             ; pull back in the current state

    bit #%00001000                 ; Check UP
    beq @menu_up  
    bit #%00000100                 ; Check DOWN
    beq @menu_down   
    bit #%00010000                 ; Check START button
    beq @start_game
    bra @done_start_menu  
@menu_up:  
    lda #132                         ; set direction to up
    sta player_sprite_y_l  
    jsr play_sfx_shoot
    bra @done_start_menu     

@menu_down:  
    lda #152                         ; set direction to down
    sta player_sprite_y_l 
    jsr play_sfx_laser
    bra @done_start_menu  

@start_game: ;TODO check which menu we are on and set the game state accordingly
    lda #GAME_STATE_IN_GAME        ; Set game state to in-game
    jsr request_state_change    ; Use the new transition system
    ;sta game_state 
    ;lda #1
    ;sta has_state_changed          ; set a 1 to we change state this frame
    ;jsr play_sfx_sparkle 
    ;jsr gameplay_init 
                        
    rts 

@done_start_menu:
    lda joystick_state             ; Update latch with current state
    sta joystick_latch             ; for next frame's comparison
    rts 

; ===================================================================
; Input Handling for Pause Menu State
; ===================================================================
check_pause_input:
    jsr GETIN                       ; Get keyboard input
    cmp #KEY_ESCAPE                 ; Check if escape key is pressed
    beq @unpause_game               ; If ESC pressed, unpause
    stz player_xy_state             ; fall through to joystick check
    jsr JOYSTICK_SCAN               ; Scan the joystick
    lda #1                          ; joystick 1
    jsr JOYSTICK_GET                ; check the first joystick 
    cpy #0      
    beq @check_prev_joystate        ; if no joystick fall through to check keyboard joystick
    lda #0                          ; keyboard joystick 0
    jsr JOYSTICK_GET        
@check_prev_joystate:   
    sta joystick_state              ; save the current state of the joystick
    eor joystick_latch              ; exclusive OR the last state to check for button state changes
    sta joystick_latch              ; save this for next time to see state changes
    lda joystick_state      
    bit #%00010000                  ; Check START button
    bne @done                       ; start not pressed, exit loop
    lda joystick_latch              ; button is pressed but is it a new press?  Check the cache latch state
    bit #%00010000                  ; bitwise AND to check for start button (ie A register bit 4 being 0)  
    beq @done                       ; if not a new press then skip to check select button
@unpause_game:
    lda #GAME_STATE_IN_GAME         ; Set game state to in-game
    jsr request_state_change        ; Use the new transition system
    ;sta game_state 
    
    ;lda #1
    ;sta has_state_changed           ; set a 1 to we change state this frame
    ;jsr play_sfx_menu
    ;jsr unpause
    ;jsr gameplay_init     
    

@done:
    lda joystick_state              ; Update latch with current state
    sta joystick_latch              ; for next frame's comparison
    rts 


; ===================================================================
; Input Handling for Gameplay State
; player_xy_state: 0 = no move | 1 = right | 2 = left | 3 = up | 4 = down
; ===================================================================
process_game_input:
    stz player_xy_state             ; reset player direction to 0 (no move)
    stz player_sprite_index         ; reset player sprite index to 0 (no move)
    jsr GETIN                       ; Get keyboard input
    cmp #KEY_ESCAPE                 ; Check if escape key is pressed
    beq @pause_game                 ; If ESC pressed, unpause
    jsr JOYSTICK_SCAN               ; Scan the joystick
    lda #1                          ; joystick 1
    jsr JOYSTICK_GET                ; check the first joystick 
    cpy #0  
    beq @check_prev_state           ; if no joystick fall through to check keyboard joystick
    lda #0                          ; keyboard joystick 0
    jsr JOYSTICK_GET    
@check_prev_state:  
    sta joystick_state              ; save the current state of the joystick
    eor joystick_latch              ; exclusive OR the last state to check for button state changes
    sta joystick_latch              ; save this for next time to see state changes
    lda joystick_state              ; pull back in the current state
    
    bit #%00001000                  ; Check UP
    beq @perform_up  
    bit #%00000100                  ; Check DOWN
    beq @perform_down
    bra @check_leftright
@perform_up:  
    lda #3                          ; set direction to up
    sta player_xy_state  
    bra @check_leftright  
@perform_down:  
    lda #4                          ; set direction to down
    sta player_xy_state  
    bra @check_leftright  
@check_leftright:    
    lda joystick_state  
    bit #%00000010                  ; Check LEFT
    beq @perform_left  
    bit #%00000001                  ; Check RIGHT
    beq @perform_right  
    bra @check_start  
@perform_left:  
    lda #2                          ; set direction to left
    sta player_xy_state   
    bra @check_start
@perform_right:  
    lda #1                          ; set direction to right
    sta player_xy_state  
@check_start:  
    bit #%00010000                  ; Check START button
    bne @check_select  
    lda joystick_latch  
    bit #%00010000  
    beq @check_select  
@pause_game:               
    bra @continue_pause_input 
    ; Check if we're still in cooldown period
    ;lda pause_cooldown 
    ;beq @continue_pause_input    ; If zero, we can process input
    ;dec pause_cooldown          ; Otherwise, decrement timer
    bra @done                    ; And exit without processing input
@continue_pause_input:         ; Start button pressed, pause game
    lda #GAME_STATE_PAUSED          ; change state
    jsr request_state_change        ; Use the new transition system
    ;sta game_state  
    ;lda #1
    ;sta has_state_changed           ; set a 1 as we changed state this frame
    ;jsr play_sfx_menu 
    ;jsr pause_init   
    bra @done                       ; skip to done to avoid checking select button
@check_select:  
    lda joystick_state 
    bit #%00100000                  ; Check SELECT button
    bne @check_fire  
    lda joystick_latch  
    bit #%00100000  
    beq @check_fire 
    ; TODO: Handle select button press here
    bra @done 
@check_fire:  
    lda joystick_state 
    bit #%10000000              ; Check bit 7 (fire button)
    beq @done                   ; If not pressed, skip firing
    lda joystick_latch 
    bit #%10000000
    beq @done   ; fire If not pressed last frame, fire now
    bra @pause_game              

    ; Already pressed, check for auto-fire if using rapid fire weapon
    ;lda player_weapon_type 
    ;cmp #PROJ_TYPE_RAPID
    ;beq @check_autofire

@done:
    lda joystick_state 
    sta joystick_latch 
    rts 

@check_autofire:
    ; For rapid fire, we allow continuous firing
    lda proj_cooldown
    bne @done                  ; If still in cooldown, don't fire
    
@fire:
    ; Set up starting position (offset from player position to center the projectile)
    ; For 8x8 projectile from 16x16 player, add 4 pixels to center
    lda player_sprite_x_l 
    clc 
    adc #4                      ; X offset to center projectile
    sta ZP_PTR_1 
    lda player_sprite_x_h 
    adc #0                      ; Add carry
    sta ZP_PTR_1 + 1
    
    lda player_sprite_y_l 
    clc 
    adc #4                      ; Y offset to center projectile
    sta ZP_PTR_2 
    lda player_sprite_y_h 
    adc #0                      ; Add carry
    sta ZP_PTR_2 + 1
    
    ; Determine firing direction based on player's sprite frame or joystick
    jsr convert_movement_to_direction    ; Get player facing direction based on input or animation
    
    ; Handle spread shot - fire 3 projectiles in a fan pattern
    ldx player_weapon_type 
    cpx #PROJ_TYPE_SPREAD 
    bne @standard_shot 
    
    ; For spread shot, fire 3 projectiles at different angles, Save the main direction to the stack
    pha 
    
    ; Fire first projectile (angled left)
    sec 
    sbc #1                      ; One direction counter-clockwise
    and #7                      ; Keep within 0-7 range
    jsr fire_projectile 
    
    ; Fire second projectile (straight ahead)
    pla                         ; Get original direction
    pha                         ; Save it again
    jsr fire_projectile 
    
    ; Fire third projectile (angled right)
    pla                         ; Get original direction
    clc
    adc #1                      ; One direction clockwise
    and #7                      ; Keep within 0-7 range
    bra @do_fire 
    
@standard_shot:
    ; Just fire a single projectile in the calculated direction, drop through to fire
@do_fire:
    ; Fire the projectile
    jsr fire_projectile 
    bra @done 
    
; ===================================================================
; convert_movement_to_direction - Convert player_xy_state to direction
; Input: A = player_xy_state (0=none, 1=right, 2=left, 3=up, 4=down)
; Output: A = direction (0=up, 1=up-right, 2=right, etc.)
; ===================================================================
convert_movement_to_direction:
    ; If no movement, use the sprite index or default to right
    cmp #0
    bne @has_movement
    lda player_sprite_index      ; No movement, use sprite index for direction
    and #7                      ; Ensure it's in range 0-7
    rts 
@has_movement:
    ; Convert from player_xy_state to 8-way direction
    cmp #1                      ; Right?
    bne @check_left
    lda #2                      ; Direction 2 = right
    rts 
@check_left:    ; Left?
    cmp #2                      
    bne @check_up
    lda #6                      ; Direction 6 = left
    rts 
@check_up:     ; Up?
    cmp #3                      
    bne @check_down
    lda #0                      ; Direction 0 = up
    rts 
@check_down:  ; Must be down (4)
    lda #4                      ; Direction 4 = down
    rts 


.endif