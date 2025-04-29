; ===================================================================
; File:         game.asm
; Programmer:   Dustin Taub
;
; Resources: ZeroByteOrg ZSound Library for the Commander X16 
;                       https://github.com/ZeroByteOrg/ZSound
;
; Description:  This is where the entire game starts. 
;               -Initializes the game
;               -Loads the game assets
;               -Adds Custom IRQ Handlers
;               -Handles the game loop           
; ===================================================================

.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"
    jmp start_game 

.include "x16.inc"
.include "zsmplayer.inc"
.include "pcmplayer.inc"
.include "macros.inc"
.include "loadfiledata.asm"
.include "globals.asm"
.include "sprite.asm"
.include "input.asm"
.include "soundfx.asm"

;||||||||||||||||||||||||||||||||||| REFERENCES - VERA  |||||||||||||||||||||||
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

;===================================================================
; Initialize the game
;===================================================================
start_game:                     ; ------- Load Game Assets From Files

    ;zsound player init
    jsr init_player             ;zsound player init

    ; load startscreen
    lda #>(VRAM_BITMAP >> 4 )
    ldx #<(VRAM_BITMAP >> 4 )
    ldy #<startscreen_fn 
    jsr loadtovram 

    ; load tiles
    lda #>(VRAM_TILES >> 4 )
    ldx #<(VRAM_TILES >> 4 )
    ldy #<tiles_fn 
    jsr loadtovram 

    ; load map
    lda #> (VRAM_TILEMAP >> 4 )
    ldx #< (VRAM_TILEMAP >> 4 )
    ldy #< tilemap_fn 
    jsr loadtovram 

    lda #>(VRAM_UIMAP >> 4 )
    ldx #<(VRAM_UIMAP >> 4 )
    ldy #<uitiles_fn 
    jsr loadtovram 

    ;load sprites
    lda #>(VRAM_SPRITES >> 4 )
    ldx #<(VRAM_SPRITES >> 4 )
    ldy #<sprites_fn 
    jsr loadtovram 

    ; Set the screen mode
    lda #SCALE_320X240          ; SCALE320X240 
    sta VERA_DC_HSCALE 
    sta VERA_DC_VSCALE  
    

init_irq:                       ; ------- IRQ Initializations          
    sei                         ; disable IRQ while we're initializing our custom irq handler
    lda IRQVEC                  ; backup default IRQ vector
    sta default_irq_vector      ; save the default IRQ vector address low byte
    lda IRQVEC + 1 
    sta default_irq_vector + 1  ; save the default IRQ vector address high byte
    lda #< custom_irq_handler   ; reference our custom IRQ handler low byte
    sta IRQVEC                  ; set the IRQ vector to our custom handler low byte 
    lda #> custom_irq_handler   ; reference our custom IRQ handler high byte
    sta IRQVEC + 1              ; set the IRQ vector to our custom handler high byte
    lda #%11111111              ; SET VERA to trigger on line 255 .
    ;lda #START_LINE             ;scan line for UI to start
	sta VERA_IRQLINE_L 
    lda #%00000011              ; Set VERA to trigger on scan line and vblank
    sta VERA_IEN 
    cli                         ; re-enable IRQ now that vector is properly set
    
    ; VERA initialize going into the start screen
    jsr startscreen_init 
   

    
;===================================================================
; Main Game Loop
;===================================================================
@main_game_loop:
    wai                         ; do nothing in main loop, just let ISR do everything
    ;lda vsync_trig
    bra @main_game_loop         ; loop indefinately 

game_tick_loop:                 ;-------  game tick fires every 60th of a second
    stz has_state_changed       ; Reset but we can change to 1 if a state change happens
    inc frame_num               ; increment frame counter
    lda frame_num 
    cmp #60    
    bne @tick                   ; run tick code and check for frame 60 
    lda #0                      ; on frame 60 we reset the frame counter 
    sta frame_num               ; and still run the last tick code
@tick:                          ; code to run every frame aka 1/60 second                   ; reset the frame state change boolean 
    lda game_state  
    cmp #GAME_STATE_START_SCREEN 
    beq @handle_startscreen_tick 
    lda has_state_changed 
    cmp #1 
    beq @tick_done              ; if a state was changed lets finish this frame
    lda game_state              
    cmp #GAME_STATE_IN_GAME 
    beq @handle_ingame_tick 
    lda has_state_changed 
    cmp #1 
    beq @tick_done              ; if a state was changed lets finish this frame
    lda game_state              
    cmp #GAME_STATE_PAUSED 
    beq @handle_paused_tick 
    ;lda has_state_changed
    ;cmp #1 
    ;beq @tick_done             ; if a state was changed lets finish this frame
    ;lda game_state              
    ;cmp #GAME_STATE_GAME_OVER 
    ;beq @handle_game_over 
@tick_done:
    rts 

; Gameplay Screen Loop ----------------------------------------------------
@handle_ingame_tick:
    ;jsr parallax_tick 
    jsr process_game_input 
    lda player_xy_state 
    cmp #0
    beq @ingame_tick            ; if no move then skip to done move player
    jsr movePlayer_tick    
@ingame_tick:
    jsr update_player_sprite 
    ;jsr update_ui_sprite 
    ;jsr ui_tick 
    rts 

; Start Screen Loop ----------------------------------------------------
@handle_startscreen_tick:
    jsr check_start_menu_input 
    jsr update_player_sprite 
    rts 

; Pause Loop ------------------------------------------------------------
@handle_paused_tick:
    jsr check_pause_input 
    rts 

;===================================================================
; Custom IRQ Handler
;===================================================================
custom_irq_handler:             ;------- Custom IRQ Handler 
    lda #%00000010              ; Check for scanline 
	and VERA_ISR 
	bne irq_scanline_handler    ; if scanline then handle it instead
    lda VERA_ISR 
    and #%00000001              ; check for vsync IRQ
    beq @vsync_done  
    jsr game_tick_loop          ; run the game tick code every frame
@vsync_done:                    ; continue to default IRQ handler backed up earlier
   jmp (default_irq_vector)     ; RTI will happen after jump

irq_scanline_handler:           ; ------- Line IRQ Handler 
    sta VERA_ISR                ; Acknowledge the line IRQ 
    ;jsr playmusic_IRQ          ; play the zsm music
    ;jsr play_pcm               ; play the sound effects
    jsr soundfx_play_irq 
    ply                         ; restore the registers
	plx                         ; off the stack
	pla                         ; which would normally happen on a normal IRQ 
	rti                         ; exit the IRQ 



;===================================================================
; Other Game Subroutines
;===================================================================
;parallax_tick:                  ; scroll front layer (layer 1)
;   
;    lda VERA_L1_VSCROLL_L 
;    clc 
;    sbc #1
;    sta VERA_L1_VSCROLL_L 
;    lda VERA_L1_VSCROLL_H 
;    sbc #0 
;    sta VERA_L1_VSCROLL_H         
;    dec parallax_scroll_delay   ; handle parallax delay
;    bne @continue               
;    lda VERA_L0_VSCROLL_L       ; scroll  (layer 0) 
;    clc 
;    sbc #1
;    sta VERA_L0_VSCROLL_L 
;    lda VERA_L0_VSCROLL_H 
;    sbc #0
;    sta VERA_L0_VSCROLL_H 
; @continue:    
;    lda #SPACE_DELAY            ; reset parallax counter
;    sta parallax_scroll_delay 
;    rts 

movePlayer_tick:                ; Move the sprite by player speed and direction                             
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
    
    lda #0                      ; default sprite index for no movement
    sta player_sprite_index  
    ldy player_xy_state 
    cpy #1
    beq @move_x_positive        ; +X
    cpy #2
    beq @move_x_negative        ; -X
    cpy #3
    beq @move_y_negative        ; +Y
    cpy #4
    beq @move_y_positive        ; -Y
    rts 

@move_x_positive:
    lda #2                      ; Frame 2 for moving right
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
    lda #1                      ; Frame 1 for moving left
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

@write_position:                ; Write updated position back to VRAM
    jsr check_boundaries  

    MACRO_VERA_SET_ADDR VRAM_SPRITE_ATTR , 1
    lda VERA_DATA0 
    lda VERA_DATA0 
    lda player_sprite_x_l       ; Write low byte of X
    sta VERA_DATA0  
    lda player_sprite_x_h       ; Write high byte of X
    sta VERA_DATA0  
    lda player_sprite_y_l       ; Write low byte of Y
    sta VERA_DATA0  
    lda player_sprite_y_h       ; Write high byte of Y
    sta VERA_DATA0  
    rts     
check_boundaries:
    ; Check X boundaries
    lda player_sprite_x_h       ; High byte of X
    cmp #SCREEN_MAX_X_H         ; Compare with max high byte
    bcc @check_x_min            ; If less than max, check Y
    bne @clamp_x_max            ; If greater, clamp X
    lda player_sprite_x_l       ; Low byte of X
    cmp #SCREEN_MAX_X_L         ; Compare with max low byte
    bcc @check_x_min            ; If less than max, check minimum
@clamp_x_max:
    lda #SCREEN_MAX_X_L         ; Clamp low byte of X
    sta player_sprite_x_l 
    lda #SCREEN_MAX_X_H         ; Clamp high byte of X
    sta player_sprite_x_h 
    bra @check_y  
    
@check_x_min:
    lda player_sprite_x_h       ; High byte of X
    cmp #SCREEN_MIN_X_H         ; Compare with min high byte (0)
    bne @done_x_min             ; If greater, no need to clamp
    lda player_sprite_x_l       ; Low byte of X
    cmp #SCREEN_MIN_X_L         ; Compare with min low byte (0)
    bcs @done_x_min             ; If carry is set, no underflow
    lda #SCREEN_MIN_X_L         ; Clamp low byte of X to 0
    sta player_sprite_x_l 
    lda #SCREEN_MIN_X_H         ; Clamp high byte of X to 0
    sta player_sprite_x_h 
@done_x_min:
@check_y: 
    ; Check Y boundaries
    lda player_sprite_y_h       ; High byte of Y
    cmp #SCREEN_MAX_Y_H         ; Compare with max high byte
    bcc @check_y_min            ; If less than max, we're done
    bne @clamp_y_max            ; If greater, clamp Y
    lda player_sprite_y_l       ; Low byte of Y
    cmp #SCREEN_MAX_Y_L         ; Compare with max low byte
    bcc @check_y_min            ; If less than max, check minimum
@clamp_y_max: 
    lda #SCREEN_MAX_Y_L         ; Clamp low byte of Y
    sta player_sprite_y_l 
    lda #SCREEN_MAX_Y_H         ; Clamp high byte of Y
    sta player_sprite_y_h 
    bra @doneboundry 
@check_y_min:
    lda player_sprite_y_h       ; High byte of Y
    cmp #SCREEN_MIN_Y_H         ; Compare with min high byte (0)
    bne @done_y_min             ; If greater, no need to clamp
    lda player_sprite_y_l       ; Low byte of Y
    cmp #SCREEN_MIN_Y_L         ; Compare with min low byte (0)
    bcs @done_y_min             ; If carry is set, no underflow
    lda #SCREEN_MIN_Y_L         ; Clamp low byte of Y to 0
    sta player_sprite_y_l 
    lda #SCREEN_MIN_Y_H         ; Clamp high byte of Y to 0
    sta player_sprite_y_h 
@done_y_min:
@doneboundry:
    rts 

update_player_sprite:
    lda player_sprite_index     ; Get current player frame index
    jsr get_sprite_frame_addr   ; Get sprite frame address  returns address ZP_PTR_1 and ZP_PTR_1+1  
    
    MACRO_VERA_SET_ADDR VRAM_SPRITE_ATTR , 1
    lda ZP_PTR_1                ; Write low byte of sprite frame address
    sta VERA_DATA0 
    lda ZP_PTR_1 + 1            ; Write high byte of sprite frame address
    sta VERA_DATA0 
    lda player_sprite_x_l       ; Write low byte of X
    sta VERA_DATA0  
    lda player_sprite_x_h       ; Write high byte of X
    sta VERA_DATA0  
    lda player_sprite_y_l       ; Write low byte of Y
    sta VERA_DATA0  
    lda player_sprite_y_h       ; Write high byte of Y
    sta VERA_DATA0     
    rts 



; Gameplay Screen Init ------------------------------------------------------------
gameplay_init:                   
    lda #LAYERCONFIG_64X324BPP    ; Setup tiles on layer 0
    sta VERA_L0_CONFIG 
    lda #(VRAM_TILEMAP >> 9)
    sta VERA_L0_MAPBASE 
    lda #(VRAM_TILES >> 9 )
    sta VERA_L0_TILEBASE 
    stz VERA_L0_HSCROLL_L       ; horizontal scroll = 0
    stz VERA_L0_HSCROLL_H 
    stz VERA_L0_VSCROLL_L       ; vertical scroll = 0
    stz VERA_L0_VSCROLL_H 
    
    ; configure layer 1: 
    lda #LAYERCONFIG_64X32UI    
    sta VERA_L1_CONFIG 
    lda #(VRAM_UIMAP >> 9 )
    sta VERA_L1_MAPBASE 
    lda #(VRAM_PETSCII >> 9)  
    sta VERA_L1_TILEBASE 
    stz VERA_L1_HSCROLL_L       ; horizontal scroll = 0
    stz VERA_L1_HSCROLL_H 
    stz VERA_L1_VSCROLL_L       ; vertical scroll = 0
    stz VERA_L1_VSCROLL_H 
    
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
    lda #%01010000              ; 16x16 , paletter offset 00
    sta VERA_DATA0 
    
    
    jsr build_sprite_ui  
    
    stz VERA_CTRL               ; Set DCSEL to 0
    lda #%01110001              ; enable sprites, layer 1, layer 0, and output mode to VGA
    sta VERA_DC_VIDEO 

    ; Initialize game variables
   ; lda #SPACE_DELAY            ; initialize our paralax counter
   ; sta parallax_scroll_delay   
    rts 

; Start Screen Init ------------------------------------------------------------
startscreen_init:

    ; configure layer 0 for background bitmaps
    lda #LAYERCONFIG_BITMP4BPP 
    sta VERA_L0_CONFIG 
    lda #(VRAM_BITMAP >> 9 )
    sta VERA_L0_TILEBASE 
    
    ; initial joystick state: Start & Select pressed
    lda #$CF
    sta joystick_latch 
     ; configure sprite for selection menu
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
    lda #%01010000              ; 16x16 , paletter offset 00
    sta VERA_DATA0 
    stz VERA_CTRL               ; Set DCSEL to 0
    lda #%01010001              ; enable sprites,layer 0, and output mode to VGA
    sta VERA_DC_VIDEO 
    
    lda #GAME_STATE_START_SCREEN ; Set game state to start screen
    sta game_state 
    
    rts 


; Pause Screen Init ------------------------------------------------------------
pause_init:
    ; First, clear the text layer to remove any garbage
    MACRO_VERA_SET_ADDR VRAM_TEXTMAP, 1
    
    ; Clear 2048 bytes (32x32 characters x 2 bytes per character)
    ldy #0                      ; Low byte counter
    ldx #8                      ; 8 pages of 256 bytes each (32x32x2 = 2048)
@clear_loop:
    lda #$20                    ; Space character
    sta VERA_DATA0 
    lda #1                      ; White text on black background
    sta VERA_DATA0 
    iny                         ; Next byte
    bne @clear_loop             ; Continue until Y wraps (256 bytes)
    dex                         ; Next page
    bne @clear_loop             ; Continue until all pages cleared
    
    ; Configure layer 1 for text mode
    lda #LAYERCONFIG_TEXT1BPP   ; 1bpp text mode
    sta VERA_L1_CONFIG 
    lda #(VRAM_TEXTMAP >> 9)    ; Set map base address
    sta VERA_L1_MAPBASE 
    lda #(VRAM_PETSCII >> 9)   ; Set tile base address for PETSCII charset
    sta VERA_L1_TILEBASE 
    stz VERA_L1_HSCROLL_L       ; No horizontal scrolling
    stz VERA_L1_HSCROLL_H 
    stz VERA_L1_VSCROLL_L       ; No vertical scrolling
    stz VERA_L1_VSCROLL_H 

    ; Enable layer 1 in addition to whatever is already enabled
    stz VERA_CTRL                ; Set DCSEL to 0
    lda #%00110001              ; disable sprites, layer 1, layer 0, and output mode to VGA ; 
    sta VERA_DC_VIDEO 
    
    ; Each character position = row*64 + column*2
    ; Position for "PAUSED" = (15*64) + (13*2) = 960 + 26 = 986
    
    MACRO_VERA_SET_ADDR (VRAM_TEXTMAP + ((12*64) + (16*2)) ), 1

    ; Write each character manually in uppercase which is more reliable
    lda #$10 ;P
    sta VERA_DATA0 
    lda #71                      ; White color
    sta VERA_DATA0 
    
    lda #$01 ;A
    sta VERA_DATA0 
    lda #71                      ; White color
    sta VERA_DATA0 
    
     lda #$15 ;U
    sta VERA_DATA0 
    lda #71                      ; White color
    sta VERA_DATA0 
    
     lda #$13 ;S
    sta VERA_DATA0 
    lda #71                      ; White color
    sta VERA_DATA0 
    
    lda #$05 ;E
    sta VERA_DATA0 
    lda #71                      ; White color
    sta VERA_DATA0 
    
    lda #$04 ;D
    sta VERA_DATA0 
    lda #71                      ; White color
    sta VERA_DATA0 
    rts 

; Unpause Screen ------------------------------------------------------------
unpause:   
    rts 


; ------------------------------------ End of Game Subroutines