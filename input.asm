; ===================================================================
; File:         input.asm
; Programmer:   Dustin Taub
; Description:  Input handling for joystick/keyboard for game and menus
;===================================================================
.ifndef INPUT_ASM
INPUT_ASM = 1

.include "x16.inc"
.include "globals.asm"

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
@pause_game:                        ; Start button pressed, pause game
    lda #GAME_STATE_PAUSED          ; change state
    sta game_state  
    lda #1
    sta has_state_changed           ; set a 1 as we changed state this frame
    jsr pause_init  
    bra @done                       ; skip to done to avoid checking select button
@check_select:  
    lda joystick_latch  
    bit #%00100000                  ; Check SELECT button
    bne @done  
    lda joystick_latch  
    bit #%00100000  
    beq @done  
    ; TODO: Handle select button press here
@done:
    lda joystick_state 
    sta joystick_latch 
    rts 


; ===================================================================
; Input Handling for Start Menu State
; ===================================================================
check_start_menu_input:
    jsr GETIN                       ; Get keyboard input
    cmp #KEY_RETURN                 ; Check if return key is pressed
    beq @start_game                ; reset player direction to 0 (no move)
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
    bra @done_start_menu     

@menu_down:  
    lda #152                         ; set direction to down
    sta player_sprite_y_l  
    bra @done_start_menu  

@start_game: ;TODO check which menu we are on and set the game state accordingly
    lda #GAME_STATE_IN_GAME        ; Set game state to in-game
    sta game_state 
    lda #1
    sta has_state_changed           ; set a 1 to we change state this frame
    jsr gameplay_init 
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
    sta game_state 
    lda #1
    sta has_state_changed           ; set a 1 to we change state this frame
    jsr clear_pause_overlay 
    jsr gameplay_init     

@done:
    lda joystick_state              ; Update latch with current state
    sta joystick_latch              ; for next frame's comparison
    rts 


.endif