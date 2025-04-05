;//////////////////////////////////////////////////////////////////////
;  game.asm
;
; This is where the game code starts
;//////////////////////////////////////////////////////////////////////

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


;||||||||||||||||||||||||||||||| REFERENCES - VERA  |||||||||
;| $9F29******* Display Composer (DC_Video) ***********
;|  |CNTRFDL|SPRT|L1|L0|NTCS/RGB|NTSC/Ch| OUT_MODE |
;|      CNTRFDL 0 = Interlaced, 1 = Progressive
;|      SPRT = Enable Sprites | L1 = Enable Layer 1 ;| L0 = Enable Layer 0
;|      NTCS/RGB 0 = NTSC, 1 = RGB | NTSC/Ch 0 = NTSC, 1 = PAL 
;|      OUT_MODE 0 = Video Disabled, 1 = VGA, 2 = NTSC(Compos/S-video), 3 = RGB 15hz
;|
;|        31 = 0011|0001               71 = 01110001
;|      ORA40 = 0100|0000 = Enable Sprites
;|      ORA20 = 0010|0000 = Enable Layer 1
;|      ORA10 = 0001|0000 = Enable Layer 0
;|      ORA70 = 0111|0001 = Enable Sprites, Layer 1, Layer 0
;|
;| $9F2D LO / 9F34 L1  *********Layer Config ***********
;|  |MAP_H | MAP_W | T256 |BMP MODE| COLOR DEPTH |
;|       MAP_H/MAP_W 0 = 32,1 = 64,2 = 128,3 = 256
;|       BMP MODE 0 = Text/Tile, 1 = Bitmap
;|       T256 0 = 16 color, 1 = 256 color
;|       COLOR DEPTH 0 = 1bpp, 2 = 4bpp, 3 = 8bpp
;|
;| $9F2E LO / 9F35 L1  *****Layer Map Base **************
;|  |tile map start address >> 9 |
;|
;|$9F2F LO / 9F36 L1  *****Layer Tile Base *************
;|  | tile graphic base address >> 11 | TILE_H | TILE_W |
;|         TILE_H 0 = 8pixel, 1 = 16pixel 
;|         TILE_W 0 = 8pixel, 1 = 16pixel
;||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||



; ------------------------------------ Initialize the game ----------------------------------------
start_game:
        
    ; ------------------------- Load Game Assets From Files
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

; IRQ Initializations 
init_irq:
    sei ; disable IRQ while we're changing the vector
    lda IRQVEC  ; backup default IRQ vector
    sta default_irq_vector 
    lda IRQVEC + 1 
    sta default_irq_vector + 1 

    ; overwrite RAM IRQ vector with custom handler address
    lda #< custom_irq_handler 
    sta IRQVEC 
    lda #> custom_irq_handler 
    sta IRQVEC + 1 

    lda #%11111111   ; SET VERA LineIRQ to trigger on line 255.
	sta VERA_IRQLINE_L 

    lda #%00000011 ; Set VERA to trigger on scan line and vysnc
    sta VERA_IEN 
    cli ; enable IRQ now that vector is properly set

    
    stz VERA_CTRL        ; Set DCSEL to 0
    lda #%00010001 ; enable layer 0, and output mode to VGA
    sta VERA_DC_VIDEO 
;------------------------------------ End of Game Initialization the game ------------------------------------

;------------------------------------ Start Screen Loop ----------------------------------------------------
startscreen_loop:
    jsr SCNKEY           ; Read a character from the keyboard
    cmp #$00             ; Check if no key is pressed
    beq startscreen_loop ; Loop until a key is pressed

    jsr gameplay_init
    
    ;jmp @main_game_loop   ; Jump to the main game loop
;------------------------------------ Start the Game Loop ----------------------------------------------------
@main_game_loop:
    wai ; do nothing in main loop, just let ISR do everything
    ;lda vsync_trig
    bra @main_game_loop ;loop indefinately 

;------------------------------------ End of Game Loop ------------------------------------------------------

;------------------------------------ Game Subroutines ------------------------------------------------------

game_tick_loop:  ; one every 60th of a second
    inc frame_num ; increment frame counter
    lda frame_num 
    cmp #60    
    bne @tick       ; run tick code and check for frame 60
    lda #0          ; on frame 60 we reset the frame counter 
    sta frame_num   ; and still run the last tick code
@tick: ; code to run every frame aka 1/60 second
    jsr parallax_tick 
    jsr input_tick 
    jsr movePlayer_tick 
    rts 


custom_irq_handler:
    lda #%00000010  ; Check for line IRQ
	and VERA_ISR 
	bne custom_irq_handler_line 

    lda VERA_ISR 
    and #%00000001 ; check for vsync IRQ
    beq @done_vsync 

    jsr game_tick_loop 

@done_vsync:      ; continue to default IRQ handler backed up earlier
   jmp (default_irq_vector); RTI will happen after jump

; Line IRQ Handler for a consistent music playback
custom_irq_handler_line:
    sta VERA_ISR ; Acknowledge the line IRQ 
	; jsr PCM_PLAY
    ; jsr ZSM_PLAYIRQ
	ply ; Directly exit the IRQ, since the Kernal IRQ handler should only run
	plx ; once per frame. It usually restores the registers, so we need
	pla ; to do so here in order to maintain the stack and registers properly.
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
input_tick:
    ; Read joystick state
    jsr JOYSTICK_SCAN  ; Scan the joystick but this might depend on default IRQ vector
    lda #1 ; joystick 1
    jsr JOYSTICK_GET ; check the first joystick 
    cpy #0
    beq @check_inputs ; if no joystick fall through to check keyboard joystick
    lda #0 ;keyboard joystick 0
    jsr JOYSTICK_GET  
@check_inputs:
    sta joystick_state ; save the current state of the joystick from JOYSTICK_GET
    eor joystick_latch ; exclusive OR the last state to check for button state changes
    sta joystick_latch ; save this for next time to see state changes
    lda joystick_state ; pull back in the current state
    bit #%00001000  ;bitwise AND to check for UP button (ie A register bit 3 being 0)
    beq @perform_up_dpad     ; if UP button pressed we don't want to check down incase it's also being pressed somehow
    bit #%00000100  ;bitwise AND to check for down button (ie A register bit 2 being 0)  
    beq @perform_down_dpad   ; if down button is also not pressed fall threw to check left and right
@check_leftright_dpad:
    lda joystick_state ; pull back in the current state
    bit #%00000010  ;bitwise AND to check for left button (ie A register bit 1 being 0)
    beq @perform_left_dpad
    bit #%00000001  ;bitwise AND to check for right button (ie A register bit 0 being 0)
    beq @perform_right_dpad
    bra @check_start_btn ; if not right or left we can jump to check start button
   
@perform_up_dpad:  ; code to perform when up button DPAD pressed
    lda player_sprite_y_frac  
    sec 
    sbc player_speed_frac        ; Subtract fractional speed adjustment
    sta player_sprite_y_frac 
    bcs @skip_y_decrement        ; If no borrow, skip integer decrement
    lda player_sprite_y          ; Handle integer part
    sec 
    sbc player_speed             ; Subtract integer speed adjustment
    sta player_sprite_y 
    @skip_y_decrement:

    bra @check_leftright_dpad ;even if up or down performed we can check left then right
@perform_down_dpad: ; code to perform when down button DPAD pressed
    lda player_sprite_y_frac 
    clc 
    adc player_speed_frac        ; Add fractional speed adjustment
    sta player_sprite_y_frac 
    bcc @skip_y_increment        ; If no carry, skip integer increment
    lda player_sprite_y          ; Handle integer part
    clc 
    adc player_speed             ; Add integer speed adjustment
    sta player_sprite_y 
@skip_y_increment:
    bra @check_leftright_dpad ; even if up or down performed we can check left then right
@perform_left_dpad: ; code to perform when left DPAD button pressed
    lda player_sprite_x_frac 
    sec 
    sbc player_speed_frac        ; Subtract fractional speed adjustment
    sta player_sprite_x_frac 
    bcs @skip_x_decrement        ; If no borrow, skip integer decrement
    lda player_sprite_x          ; Handle integer part
    sec 
    sbc player_speed            ; Subtract integer speed adjustment
    sta player_sprite_x 
@skip_x_decrement:
    bra @check_start_btn ; check start button next
@perform_right_dpad: ; code to perform when lright DPAD button pressed
    lda player_sprite_x_frac 
    clc 
    adc player_speed_frac        ; Add fractional speed adjustment
    sta player_sprite_x_frac 
    bcc @skip_x_increment        ; If no carry, skip integer increment
    lda player_sprite_x          ; Handle integer part
    clc 
    adc player_speed            ; Add integer speed adjustment
    sta player_sprite_x 
@skip_x_increment:
  ; bra @check_start_btn ; fall threw to check start button next
@check_start_btn:  ;check and perform start button 
   bit #%00010000   ;bitwise AND to check for start button (ie A register bit 4 being 0)    
   bne @check_select_btn ; button is not pressed so skip to check select button  
   lda joystick_latch   ; button is pressed but is it a new press?  Check the cache latch state
   bit #%00010000   ;bitwise AND to check for start button (ie A register bit 4 being 0)  
   beq @check_select_btn  ;if not a new press then skip to check select button
    ;TODO code to perform when start button pressed

@check_select_btn:  ;check and perform select button 
   lda joystick_state ; pull back in the current state
   bit #%00100000   ;bitwise AND to check for select button (ie A register bit 5 being 0) 
   bne @latch    ; button is not pressed so skip to end
   lda joystick_latch   ; button is pressed but is it a new press?  Check the cache state
   bit #%00100000 ;bitwise AND to check for select button (ie A register bit 5 being 0) in the cache
   beq @latch 
@latch:
   lda joystick_state 
   sta joystick_latch 
   rts 

movePlayer_tick:
    ; pull up the sprite atribute in VRAM
    MACRO_VERA_SET_ADDR VRAM_SPRITE_ATTR , 1
    lda VERA_DATA0 ; move past the address
    lda VERA_DATA0 
    lda player_sprite_x 
    sta VERA_DATA0     ; Update X coordinate (integer part)
    stz VERA_DATA0     ; Zero out high byte
    lda player_sprite_y 
    sta VERA_DATA0     ; Update Y coordinate (integer part)
    stz VERA_DATA0     ; Zero out high byte
    rts 

gameplay_init:
    ; Setup tiles on layer 0
    lda #LAYERCONFIG_32x324BPP 
    sta VERA_L0_CONFIG 
    lda #(VRAM_TILEMAP >> 9)
    sta VERA_L0_MAPBASE 
    lda #(VRAM_TILES >> 9 )
    sta VERA_L0_TILEBASE 
    stz VERA_L0_HSCROLL_L ; horizontal scroll = 0
    stz VERA_L0_HSCROLL_H 
    stz VERA_L0_VSCROLL_L ; vertical scroll = 0
    stz VERA_L0_VSCROLL_H 
    
    ; configure layer 1: 
    lda #LAYERCONFIG_32x324BPP 
    sta VERA_L1_CONFIG 
    lda #(VRAM_TILEMAP >> 9 )
    sta VERA_L1_MAPBASE 
    lda #(VRAM_TILES >> 9 ) 
    sta VERA_L1_TILEBASE 
    stz VERA_L1_HSCROLL_L ; horizontal scroll = 0
    stz VERA_L1_HSCROLL_H 
    stz VERA_L1_VSCROLL_L ; vertical scroll = 0
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

    lda player_sprite_x 
    sta VERA_DATA0  ; x attribute
    stz VERA_DATA0  ; zero out high byte
    lda player_sprite_y 
    sta VERA_DATA0 ; y attribute
    stz VERA_DATA0 ; zero out high byte
    lda #%00001100 ; zlevel, sprite in from of layer1
    sta VERA_DATA0 
    lda #%01010011  ; 16x16 , paletter offset 01
    sta VERA_DATA0 

    stz VERA_CTRL        ; Set DCSEL to 0
    lda #%01110001 ; enable sprites, layer 1, layer 0, and output mode to VGA
    sta VERA_DC_VIDEO 

    ; Initialize game variables
    lda #SPACE_DELAY ; initialize our paralax counter
    sta parallax_scroll_delay 

    rts 

clear_screen:
    lda #$00
    stz VERA_CTRL           ; Set DCSEL to 0
    MACRO_VERA_SET_ADDR $0E000, 1 ; Start at VRAM address $0E000
    ldx #0
@clear_loop:
    sta VERA_DATA0       ; Write 0 to clear the screen
    inx
    bne @clear_loop       ; Loop until the entire screen is cleared
    rts

; ------------------------------------ End of Game Subroutines