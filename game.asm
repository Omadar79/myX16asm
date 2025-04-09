; //////////////////////////////////////////////////////////////////////
; File:         game.asm
; Programmer:   Dustin Taub
; Description:  This is where the entire game starts. 
;               -Initializes the game
;               -Loads the game assets
;               -Adds Custom IRQ Handlers
;               -Handles the game loop           
; //////////////////////////////////////////////////////////////////////

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"
    jmp start_game 

.include "x16.inc"
.include "macros.inc"
.include "zsound.inc"
.include "filestovram.asm"
.include "globals.asm"
;.include "sprites.asm"

ZP_PTR_DIR = $28 ; ZP pointer for direction  0 = no move, 1 = right, 2 = left, 3 = up, 4 = down


     ;||||||||||||||||||||||||||||||| REFERENCES - VERA  |||||||||||||||||||||||
     ;|       $9F29******* Display Composer (DC_Video) ***********
     ;|        |CNTRFDL|SPRT|L1|L0|NTCS/RGB|NTSC/Ch| OUT_MODE |
     ;|            CNTRFDL 0 = Interlaced, 1 = Progressive
     ;|            SPRT = Enable Sprites | L1 = Enable Layer 1 ;| L0 = Enable Layer 0
     ;|            NTCS/RGB 0 = NTSC, 1 = RGB | NTSC/Ch 0 = NTSC, 1 = PAL 
     ;|            OUT_MODE 0 = Video Disabled, 1 = VGA, 2 = NTSC(Compos/S-video), 3 = RGB 15hz
     ;|      
     ;|              31 = 0011|0001               71 = 01110001
     ;|            ORA40 = 0100|0000 = Enable Sprites
     ;|            ORA20 = 0010|0000 = Enable Layer 1
     ;|            ORA10 = 0001|0000 = Enable Layer 0
     ;|            ORA70 = 0111|0001 = Enable Sprites, Layer 1, Layer 0
     ;|      
     ;|       $9F2D LO / 9F34 L1  *********Layer Config ***********
     ;|        |MAP_H | MAP_W | T256 |BMP MODE| COLOR DEPTH |
     ;|             MAP_H/MAP_W 0 = 32,1 = 64,2 = 128,3 = 256
     ;|             BMP MODE 0 = Text/Tile, 1 = Bitmap
     ;|             T256 0 = 16 color, 1 = 256 color
     ;|             COLOR DEPTH 0 = 1bpp, 2 = 4bpp, 3 = 8bpp
     ;|      
     ;|       $9F2E LO / 9F35 L1  *****Layer Map Base **************
     ;|        |tile map start address >> 9 |
     ;|      
     ;|      $9F2F LO / 9F36 L1  *****Layer Tile Base *************
     ;|        | tile graphic base address >> 11 | TILE_H | TILE_W |
     ;|               TILE_H 0 = 8pixel, 1 = 16pixel 
     ;|               TILE_W 0 = 8pixel, 1 = 16pixel
     ;||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

; ------------------------------------ Initialize the game ----------------------------------------
start_game:
    ; ------- Load Game Assets From Files
    ; load bitmap startscreen
    lda #> (VRAM_BITMAP >> 4 )
    ldx #< (VRAM_BITMAP >> 4 )
    ldy #< startscreen_fn 
    jsr loadtovram 

    ; load tiles
    lda #> (VRAM_TILES >> 4 )
    ldx #< (VRAM_TILES >> 4 )
    ldy #< tiles_fn 
    jsr loadtovram 

    ; load map
    lda #> (VRAM_TILEMAP >> 4 )
    ldx #< (VRAM_TILEMAP >> 4 )
    ldy #< tilemap_fn 
    jsr loadtovram 

    ; Set the screen mode
    lda #SCALE_320X240 ; SCALE320X240 
    sta VERA_DC_HSCALE 
    sta VERA_DC_VSCALE  
    
    ; configure layer 0 for background bitmaps
    lda #LAYERCONFIG_BITMP4BPP 
    sta VERA_L0_CONFIG 
    lda #(VRAM_BITMAP >> 9 )
    sta VERA_L0_TILEBASE 

    ; initial joystick state: Start & Select pressed
    lda #$CF
    sta joystick_latch 
init_irq:
    ; ------- IRQ Initializations 
    sei                         ; disable IRQ while we're initializing our custom irq handler
    lda IRQVEC                  ; backup default IRQ vector
    sta default_irq_vector      ; save the default IRQ vector address low byte
    lda IRQVEC + 1 
    sta default_irq_vector + 1  ; save the default IRQ vector address high byte

    lda #< custom_irq_handler   ; reference our custom IRQ handler low byte
    sta IRQVEC                  ; set the IRQ vector to our custom handler low byte 
    lda #> custom_irq_handler   ; reference our custom IRQ handler high byte
    sta IRQVEC + 1              ; set the IRQ vector to our custom handler high byte

    lda #%11111111              ; SET VERA LineIRQ to trigger on line 255.
	sta VERA_IRQLINE_L 

    lda #%00000011              ; Set VERA to trigger on scan line and vysnc
    sta VERA_IEN 
    cli                         ; enable IRQ now that vector is properly set

    ; VERA initialize going into the start screen
    stz VERA_CTRL               ; Set DCSEL to 0
    lda #%00010001              ; enable layer 0, and output mode to VGA
    sta VERA_DC_VIDEO 
;------------------------------------ Start Screen Loop ----------------------------------------------------
startscreen_loop:
    ; ------- Start Screen Loop, we might put loading logic behind the scenes
    jsr SCNKEY                  ; Read a character from the keyboard
    cmp #$00                    ; Check if no key is pressed
    beq startscreen_loop        ; Loop until a key is pressed
    jsr gameplay_init 
    
;------------------------------------ Main Game Loop ----------------------------------------------------
@main_game_loop:
    wai                         ; do nothing in main loop, just let ISR do everything
    ;lda vsync_trig
    bra @main_game_loop         ; loop indefinately 

;------------------------------------ Game Subroutines ------------------------------------------------------
game_tick_loop:
    ;-------  game tick fires every 60th of a second
    inc frame_num               ; increment frame counter
    lda frame_num 
    cmp #60    
    bne @tick                   ; run tick code and check for frame 60 
    lda #0                      ; on frame 60 we reset the frame counter 
    sta frame_num               ; and still run the last tick code
@tick:                          ; code to run every frame aka 1/60 second
    jsr parallax_tick 
    jsr input_tick 
    lda ZP_PTR_DIR 
    cmp #0
    beq @tick_done           ; if no move then skip to done move player
    jsr movePlayer_tick       
@tick_done:
    jsr update_player_sprite 
    rts 

custom_irq_handler:
    ;------- Custom IRQ Handler that still allows the Kernal IRQ to run at the end of vsync
    lda #%00000010              ; Check for scanline IRQ
	and VERA_ISR 
	bne custom_irq_scanline_handler 
    lda VERA_ISR 
    and #%00000001              ; check for vsync IRQ
    beq @done_vsync 
    jsr game_tick_loop 
@done_vsync:                    ; continue to default IRQ handler backed up earlier
   jmp (default_irq_vector)     ; RTI will happen after jump
custom_irq_scanline_handler:        ; Line IRQ Handler ties to the VERA line IRQ
    sta VERA_ISR                ; Acknowledge the line IRQ 
	; jsr PCM_PLAY
    ; jsr ZSM_PLAYIRQ
	ply                         ; Directly exit the IRQ, since the Kernal IRQ handler should only run once per frame
	plx                         ; Pull the registers back from the stack
	pla                         ; in order to maintain the stack and registers properly.
	rti 

parallax_tick:
                                ; Scroll the background
                                ; scroll ground (layer 1)
    lda VERA_L1_VSCROLL_L 
    clc 
    sbc #1
    sta VERA_L1_VSCROLL_L 
    lda VERA_L1_VSCROLL_H 
    sbc #0 
    sta VERA_L1_VSCROLL_H 
                                ; handle parallax delay
    dec parallax_scroll_delay 
    bne @continue 
                                ; scroll  (layer 0) 
    lda VERA_L0_VSCROLL_L 
    clc 
    sbc #1
    sta VERA_L0_VSCROLL_L 
    lda VERA_L0_VSCROLL_H 
    sbc #0
    sta VERA_L0_VSCROLL_H 
 @continue:    
                                ; reset parallax counter
    lda #SPACE_DELAY
    sta parallax_scroll_delay 
    rts 

;|||||||||||||||||||||||||||||||| REFERENCES - JOYSTICK  |||||||||
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
;||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
input_tick:                     ; Read joystick state
    stz ZP_PTR_DIR              ; reset player direction to 0 (no move)
    stz player_sprite_index      ; reset player sprite index to 0 (no move)
    jsr JOYSTICK_SCAN           ; Scan the joystick but this might depend on default IRQ vector
    lda #1                      ; joystick 1
    jsr JOYSTICK_GET            ; check the first joystick 
    cpy #0
    beq @input_prev_state       ; if no joystick fall through to check keyboard joystick
    lda #0                      ; keyboard joystick 0
    jsr JOYSTICK_GET  
@input_prev_state:
    sta joystick_state          ; save the current state of the joystick from JOYSTICK_GET
    eor joystick_latch          ; exclusive OR the last state to check for button state changes
    sta joystick_latch          ; save this for next time to see state changes
    ;@check_updown_dpad:       ; check and perform up and down DPAD buttons
    lda joystick_state          ; pull back in the current state
    bit #%00001000              ; bitwise AND to check for UP button (ie A register bit 3 being 0)
    beq @perform_up_dpad        ; if UP button pressed we don't want to check down incase it's also being pressed somehow
    bit #%00000100              ; bitwise AND to check for down button (ie A register bit 2 being 0)  
    beq @perform_down_dpad      ; if down button is also not pressed fall threw to check left and right
    bra @check_leftright_dpad   ; if not up or down we can check left then right
   
@perform_up_dpad:               ; code to perform when up button DPAD pressed
    lda #3                    ; set player direction to up
    sta ZP_PTR_DIR 
    bra @check_leftright_dpad 
@perform_down_dpad:             ; code to perform when down button DPAD pressed
    lda #4                    ; set player direction to down
    sta ZP_PTR_DIR 
    bra @check_leftright_dpad 

@check_leftright_dpad:
    lda joystick_state          ; pull back in the current state
    bit #%00000010              ; bitwise AND to check for left button (ie A register bit 1 being 0)
    beq @perform_left_dpad 
    bit #%00000001              ; bitwise AND to check for right button (ie A register bit 0 being 0)
    beq @perform_right_dpad 
    bra @check_start_btn        ; if not right or left we can jump to check start button

@perform_left_dpad:             ; code to perform when left DPAD button pressed
    lda #2                      ; set player direction to down
    sta ZP_PTR_DIR 
    bra @check_start_btn        ; Continue to check start button

@perform_right_dpad:            ; code to perform when right DPAD button pressed 
    lda #1                      ; set player direction to down
    sta ZP_PTR_DIR 
    ;bra @check_start_btn      ; commented out to allow it to fall through to check start button

@check_start_btn:               ; check and perform start button 
   bit #%00010000               ; bitwise AND to check for start button (ie A register bit 4 being 0)    
   bne @check_select_btn        ; button is not pressed so skip to check select button  
   lda joystick_latch           ; button is pressed but is it a new press?  Check the cache latch state
   bit #%00010000               ; bitwise AND to check for start button (ie A register bit 4 being 0)  
   beq @check_select_btn        ; if not a new press then skip to check select button
;TODO code to perform when start button pressed

@check_select_btn:              ; check and perform select button 
   lda joystick_state           ; pull back in the current state
   bit #%00100000               ; bitwise AND to check for select button (ie A register bit 5 being 0) 
   bne @latch                   ; button is not pressed so skip to end
   lda joystick_latch           ; button is pressed but is it a new press?  Check the cache state
   bit #%00100000               ; bitwise AND to check for select button (ie A register bit 5 being 0) in the cache
   beq @latch 
;TODO code to perform when select button pressed
@latch:
   lda joystick_state 
   sta joystick_latch 
   rts 

movePlayer_tick:   ; Move the sprite by player speed and directio                           
    MACRO_VERA_SET_ADDR VRAM_SPRITE_ATTR , 1
    lda VERA_DATA0              ; skip past the first byte of the sprite attribute
    lda VERA_DATA0              ; skip past the second byte of the sprite attribute
    lda VERA_DATA0              ; Read low byte of X position
    sta player_sprite_x_l       ; Store in zero-page
    lda VERA_DATA0              ; Read high byte of X position
    sta player_sprite_x_h    
    lda VERA_DATA0              ; Read low byte of Y position
    sta player_sprite_y_l     
    lda VERA_DATA0              ; Read high byte of Y position
    sta player_sprite_y_h 
    
    ldy ZP_PTR_DIR 
    cpy #1
    beq @move_x_positive    ; +X
    cpy #2
    beq @move_x_negative    ; -X
    cpy #3
    beq @move_y_negative    ; +Y
    cpy #4
    beq @move_y_positive    ; -Y

    rts 

@move_x_positive:
    lda #8                      ; Frame 2 for moving right
    sta player_sprite_index 
    lda player_sprite_x_l 
    clc 
    adc player_speed_x           
    sta player_sprite_x_l 
    lda player_sprite_x_h 
    adc #0                  
    sta player_sprite_x_h 
    bra @write_position

@move_x_negative:
    lda #4                      ; Frame 1 for moving left
    sta player_sprite_index 
    lda player_sprite_x_l 
    sec 
    sbc player_speed_x             
    sta player_sprite_x_l 
    lda player_sprite_x_h 
    sbc #0            
    sta player_sprite_x_h 
    bra @write_position

@move_y_positive:
    lda player_sprite_y_l  
    clc 
    adc player_speed_y 
    sta player_sprite_y_l 
    lda player_sprite_y_h 
    adc #0                
    sta player_sprite_y_h 
    bra @write_position

@move_y_negative:
    lda player_sprite_y_l  
    sec 
    sbc player_speed_y 
    sta player_sprite_y_l 
    lda player_sprite_y_h 
    sbc #0         
    sta player_sprite_y_h 
    rts 
    ;bra @write_position

@write_position:                    ; Write updated position back to VRAM
    jsr check_boundaries  

    MACRO_VERA_SET_ADDR VRAM_SPRITE_ATTR , 1
    lda VERA_DATA0 
    lda VERA_DATA0 
    lda player_sprite_x_l                   ; Write low byte of X
    sta VERA_DATA0  
    lda player_sprite_x_h              ; Write high byte of X
    sta VERA_DATA0  
    lda player_sprite_y_l                  ; Write low byte of Y
    sta VERA_DATA0  
    lda player_sprite_y_h               ; Write high byte of Y
    sta VERA_DATA0  
    rts     
check_boundaries:
    ; Check X boundaries
    lda player_sprite_x_h        ; High byte of X
    cmp #SCREEN_MAX_X_H          ; Compare with max high byte
    bcc @check_x_min               ; If less than max, check Y
    bne @clamp_x_max                 ; If greater, clamp X
    lda player_sprite_x_l        ; Low byte of X
    cmp #SCREEN_MAX_X_L          ; Compare with max low byte
    bcc @check_x_min             ;   If less than max, check minimum
@clamp_x_max:
    lda #SCREEN_MAX_X_L          ; Clamp low byte of X
    sta player_sprite_x_l
    lda #SCREEN_MAX_X_H          ; Clamp high byte of X
    sta player_sprite_x_h
    bra @check_y  

@check_x_min:
    lda player_sprite_x_h        ; High byte of X
    cmp #SCREEN_MIN_X_H            ; Compare with min high byte (0)
    bne @done_x_min              ; If greater, no need to clamp
    lda player_sprite_x_l        ; Low byte of X
    cmp #SCREEN_MIN_X_L            ; Compare with min low byte (0)
    bcs @done_x_min              ; If carry is set, no underflow
    lda #SCREEN_MIN_X_L            ; Clamp low byte of X to 0
    sta player_sprite_x_l
    lda #SCREEN_MIN_X_H            ; Clamp high byte of X to 0
    sta player_sprite_x_h
@done_x_min:
@check_y: 
    ; Check Y boundaries
    lda player_sprite_y_h        ; High byte of Y
    cmp #SCREEN_MAX_Y_H          ; Compare with max high byte
    bcc @check_y_min            ; If less than max, we're done
    bne @clamp_y_max                 ; If greater, clamp Y
    lda player_sprite_y_l        ; Low byte of Y
    cmp #SCREEN_MAX_Y_L          ; Compare with max low byte
    bcc @check_y_min             ; If less than max, check minimum
@clamp_y_max: 
    lda #SCREEN_MAX_Y_L          ; Clamp low byte of Y
    sta player_sprite_y_l
    lda #SCREEN_MAX_Y_H          ; Clamp high byte of Y
    sta player_sprite_y_h
    bra @doneboundry 
@check_y_min:
    lda player_sprite_y_h        ; High byte of Y
    cmp #SCREEN_MIN_Y_H            ; Compare with min high byte (0)
    bne @done_y_min              ; If greater, no need to clamp
    lda player_sprite_y_l        ; Low byte of Y
    cmp #SCREEN_MIN_Y_L            ; Compare with min low byte (0)
    bcs @done_y_min              ; If carry is set, no underflow
    lda #SCREEN_MIN_Y_L            ; Clamp low byte of Y to 0
    sta player_sprite_y_l
    lda #SCREEN_MIN_Y_H            ; Clamp high byte of Y to 0
    sta player_sprite_y_h
@done_y_min:
@doneboundry:
    rts

update_player_sprite:
    ; Calculate the VRAM address of the sprite frame
  
    lda #< (VRAM_SPRITES >> 5)
    clc 
    adc player_sprite_index 
    sta ZP_PTR_1 
    lda #> (VRAM_SPRITES >> 5)
    adc #0                      ; Add carry from low byte addition
    sta ZP_PTR_1 + 1  ; Add the offset for the sprite frame
       

    MACRO_VERA_SET_ADDR VRAM_SPRITE_ATTR , 1
    lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda player_sprite_x_l                   ; Write low byte of X
    sta VERA_DATA0  
    lda player_sprite_x_h              ; Write high byte of X
    sta VERA_DATA0  
    lda player_sprite_y_l                  ; Write low byte of Y
    sta VERA_DATA0  
    lda player_sprite_y_h               ; Write high byte of Y
    sta VERA_DATA0  
    rts 
gameplay_init:
                                    ; Setup tiles on layer 0
    lda #LAYERCONFIG_32x324BPP 
    sta VERA_L0_CONFIG 
    lda #(VRAM_TILEMAP >> 9)
    sta VERA_L0_MAPBASE 
    lda #(VRAM_TILES >> 9 )
    sta VERA_L0_TILEBASE 
    stz VERA_L0_HSCROLL_L           ; horizontal scroll = 0
    stz VERA_L0_HSCROLL_H 
    stz VERA_L0_VSCROLL_L           ; vertical scroll = 0
    stz VERA_L0_VSCROLL_H 
    
    ; configure layer 1: 
    lda #LAYERCONFIG_32x324BPP 
    sta VERA_L1_CONFIG 
    lda #(VRAM_TILEMAP >> 9 )
    sta VERA_L1_MAPBASE 
    lda #(VRAM_TILES >> 9 ) 
    sta VERA_L1_TILEBASE 
    stz VERA_L1_HSCROLL_L           ; horizontal scroll = 0
    stz VERA_L1_HSCROLL_H 
    stz VERA_L1_VSCROLL_L           ; vertical scroll = 0
    stz VERA_L1_VSCROLL_H 
    
    ;load sprites
    lda #>(VRAM_SPRITES >> 4 )
    ldx #<(VRAM_SPRITES >> 4 )
    ldy #<sprites_fn 
    jsr loadtovram 
    
    ; configure sprites
    MACRO_VERA_SET_ADDR VRAM_SPRITE_ATTR , 1
    lda #< (VRAM_SPRITES >> 5)
    sta VERA_DATA0 
    lda #> (VRAM_SPRITES >> 5)
    sta VERA_DATA0 
    lda player_sprite_x_l       ; Write X position (16-bit)
    sta VERA_DATA0              ; Low byte of X position
    lda player_sprite_x_h 
    stz VERA_DATA0              ; High byte of X position
    lda player_sprite_y_l       ; Write Y position (16-bit)
    sta VERA_DATA0              ; Low byte of Y position
    lda player_sprite_y_h 
    stz VERA_DATA0              ; High byte of Y position
    lda #%00001100              ; zlevel, sprite in from of layer1
    sta VERA_DATA0 
    lda #%01010011              ; 16x16 , paletter offset 01
    sta VERA_DATA0 
    stz VERA_CTRL               ; Set DCSEL to 0
    lda #%01110001              ; enable sprites, layer 1, layer 0, and output mode to VGA
    sta VERA_DC_VIDEO 

    ; Initialize game variables
    lda #SPACE_DELAY            ; initialize our paralax counter
    sta parallax_scroll_delay 
    rts 





clear_screen:
    lda #$00
    stz VERA_CTRL                   ; Set DCSEL to 0
    MACRO_VERA_SET_ADDR $0E000, 1   ; Start at VRAM address $0E000
    ldx #0
@clear_loop:
    sta VERA_DATA0                  ; Write 0 to clear the screen
    inx 
    bne @clear_loop                 ; Loop until the entire screen is cleared
    rts 




; ------------------------------------ End of Game Subroutines