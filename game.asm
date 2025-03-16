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

   jmp start

.include "x16.inc"
.include "macros.inc"


;------------------------------------ VERA References---------------------------
; $9F29******* Display Composer (DC_Video) ***********
;   |CNTRFDL|SPRT|L1|L0|NTCS/RGB|NTSC/Ch| OUT_MODE |
;       CNTRFDL 0 = Interlaced, 1 = Progressive
;       SPRT = Enable Sprites | L1 = Enable Layer 1 ;| L0 = Enable Layer 0
;       NTCS/RGB 0 = NTSC, 1 = RGB | NTSC/Ch 0 = NTSC, 1 = PAL 
;       OUT_MODE 0 = Video Disabled, 1 = VGA, 2 = NTSC(Compos/S-video), 3 = RGB 15hz
;
;         31 = 0011|0001               71 = 01110001
;       ORA40 = 0100|0000 = Enable Sprites
;       ORA20 = 0010|0000 = Enable Layer 1
;       ORA10 = 0001|0000 = Enable Layer 0
;       ORA70 = 0111|0001 = Enable Sprites, Layer 1, Layer 0
;
; $9F2D LO / 9F34 L1  *********Layer Config ***********
;   |MAP_H | MAP_W | T256 |BMP MODE| COLOR DEPTH |
;        MAP_H/MAP_W 0 = 32,1 = 64,2 = 128,3 = 256
;        BMP MODE 0 = Text/Tile, 1 = Bitmap
;        T256 0 = 16 color, 1 = 256 color
;        COLOR DEPTH 0 = 1bpp, 2 = 4bpp, 3 = 8bpp
;
; $9F2E LO / 9F35 L1  *****Layer Map Base **************
;   |tile map start address >> 9 |
;
; $9F2F LO / 9F36 L1  *****Layer Tile Base *************
;   | tile graphic base address >> 11 | TILE_H | TILE_W |
;          TILE_H 0 = 8pixel, 1 = 16pixel 
;          TILE_W 0 = 8pixel, 1 = 16pixel
;


;------------------------------------ Constants
SCALE              = $50 ; $50 = 1x 640x480 or 80column, $28 = 2x 320x240 or 40column, $14 = 4x (160x120)
LAYERCONFIG_128x128= $F2 ; 00000010 = 16x16 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp
LAYERCONFIG_32x32  = $02 ; 00000010 = 32x32 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp
LAYERCONFIG_64x64  = $A2 ; 10100010 = 64x64 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp

SPRITE_64H        = $C0
SPRITE_64W        = $30
SPRITE_32H        = $80
SPRITE_32W        = $20
SPRITE_16H        = $40
SPRITE_16W        = $10

; Keyboard Keys
SPACE             = $20
SPADE             = $41
CHAR_Q            = $51 ; "Q" key
CLR               = $93

VSYNC_BIT         = $01
SPACE_DELAY       = 16  ; Parallax Scrolling

; Game Asset Location - VRAM Addresses
VRAM_L0MAPS       = $00000
VRAM_L1MAPS       = $00800
VRAM_TILES        = $01000
VRAM_SPRITE       = $04000 ; sprite 0 data
VRAM_SPRITE_ATTR  = $1FC00 ; sprite 0 attribute table

; Game Asset Sizes
.include "dataSprites.inc"
.include "dataMapTiles.inc"

;------------------------------------ Variables
m_space_move: .byte 0
m_sprite_x: .byte 180
m_sprite_y: .byte 150
default_irq_vector: .addr 0


start:
;------------------------------------ Initialize the game
    
    ; copy maps and tiles to VRAM
    RAM_TO_VRAM map_tiles, VRAM_L0MAPS, MAPS_SIZE
    RAM_TO_VRAM tiles, VRAM_TILES, TILES_SIZE

    ;copy sprites to VRAM
    RAM_TO_VRAM spaceship1, VRAM_SPRITE, 128

    ; Set the screen mode
    lda #SCALE ; 2x scale
    sta VERA_dc_hscale
    sta VERA_dc_vscale  
    
    ; configure layer 0:
    lda #LAYERCONFIG_32x32 
    sta VERA_L0_config
    lda #(VRAM_L0MAPS >> 9)
    sta VERA_L0_mapbase
    lda #(VRAM_TILES >> 9) ; 8x8 tiles
    sta VERA_L0_tilebase
    stz VERA_L0_hscroll_l ; horizontal scroll = 0
    stz VERA_L0_hscroll_h
    stz VERA_L0_vscroll_l ; vertical scroll = 0
    stz VERA_L0_vscroll_h
    
    ; configure layer 1: 
    lda #LAYERCONFIG_32x32
    sta VERA_L1_config
    lda #(VRAM_L1MAPS >> 9)
    sta VERA_L1_mapbase
    lda #(VRAM_TILES >> 9) ; 8x8 tiles
    sta VERA_L1_tilebase
    stz VERA_L1_hscroll_l ; horizontal scroll = 0
    stz VERA_L1_hscroll_h
    stz VERA_L1_vscroll_l ; vertical scroll = 0
    stz VERA_L1_vscroll_h
    

    VERA_SET_ADDR VRAM_SPRITE_ATTR,1
    lda #<(VRAM_SPRITE >> 5)
       sta VERA_data0
    lda #>(VRAM_SPRITE >> 5)
       sta VERA_data0

    lda m_sprite_x
    sta VERA_data0  ; x attribute
    stz VERA_data0  ; zero out high byte
    lda m_sprite_y
    sta VERA_data0 ; y attribute
    stz VERA_data0 ; zero out high byte
    lda #$0C        ; z-level
    sta VERA_data0
    lda #(SPRITE_16H | SPRITE_16W | 1)
    ;lda #$F0 ;(SPRITE_64H | SPRITE_64W)    ; palette offset
    sta VERA_data0

    ; Enable sprites
    stz VERA_ctrl        ; Set DCSEL to 0
    lda #$71  ;enable sprites, layer 1, layer 0
    sta VERA_dc_video

    lda #SPACE_DELAY ;initialize our paralax  counter
    sta m_space_move

;---------------IRQ Initializations
    
    ; backup default RAM IRQ vector
    lda IRQVec
    sta default_irq_vector
    lda IRQVec+1
    sta default_irq_vector+1

    ; overwrite RAM IRQ vector with custom handler address
    sei ; disable IRQ while vector is changing
    lda #<custom_irq_handler
    sta IRQVec
    lda #>custom_irq_handler
    sta IRQVec+1
    lda #VSYNC_BIT ; make VERA only generate VSYNC IRQs
    sta VERA_ien
    cli ; enable IRQ now that vector is properly set




;------------------------------------ Start the Game Loop
@main_loop:
    wai ; do nothing in main loop, just let ISR do everything

    bra @main_loop
   ; never return, just wait for reset


  ;  jsr SCNKEY          ; Read a character from the keyboard
  ;  cmp #$57           ; Compare with 'W' (up)
  ;  beq move_up
  ;  cmp #$41           ; Compare with 'A' (left)
  ;  beq move_left
  ;  cmp #$53           ; Compare with 'S' (down)
  ;  beq move_down
  ;  cmp #$44           ; Compare with 'D' (right)
  ;  beq move_right
  ;  cmp #$1E           ; Compare with cursor up
  ;  beq move_up
  ;  cmp #$1D           ; Compare with cursor left
  ;  beq move_left
  ;  cmp #$1F           ; Compare with cursor down
  ;  beq move_down
  ;  cmp #$1C           ; Compare with cursor right
  ;  beq move_right
  ;  cmp #$1B           ; Compare with ESC key
  ;  beq exit_game
  ;  jmp main_loop      ; Loop back to read the next character

;------------------------------------ End of Game Loop


;------------------------------------ Custom IRQ Handler

custom_irq_handler:
   lda VERA_isr
   and #VSYNC_BIT
   beq @continue ; non-VSYNC IRQ, no tick update

   ; scroll ground (layer 1)
   lda VERA_L1_vscroll_l
   clc
   sbc #1
   sta VERA_L1_vscroll_l
   lda VERA_L1_vscroll_h
   sbc #0
   sta VERA_L1_vscroll_h

   ; handle parallax delay
   dec m_space_move
   bne @continue 

   ; scroll  (layer 0) 
   lda VERA_L0_vscroll_l
   clc
   sbc #1
   sta VERA_L0_vscroll_l
   lda VERA_L0_vscroll_h
   sbc #0
   sta VERA_L0_vscroll_h

   ; reset parallax counter
   lda #SPACE_DELAY
   sta m_space_move

@continue:      ; continue to default IRQ handler backed up earlier
   jmp (default_irq_vector)
   ; RTI will happen after jump


;;------------------------------------ Game Subroutines
;move_up:
;    lda m_sprite_y
;    sec
;    sbc #1             ; Decrease Y coordinate
;    sta m_sprite_y
;    jsr update_sprite_position
;    jmp main_loop
;
;move_left:
;    lda m_sprite_x
;    sec
;    sbc #1             ; Decrease X coordinate
;    sta m_sprite_x
;    jsr update_sprite_position
;    jmp main_loop
;
;move_down:
;    lda m_sprite_y
;    clc
;    adc #1             ; Increase Y coordinate
;    sta m_sprite_y
;    jsr update_sprite_position
;    jmp main_loop
;
;move_right:
;    lda m_sprite_x
;    clc
;    adc #1             ; Increase X coordinate
;    sta m_sprite_x
;    jsr update_sprite_position
;    jmp main_loop    
;
;
;update_sprite_position:
;    ; Update the sprite position in VRAM
;    VERA_SET_ADDR VRAM_SPRITE_ATTR,1
;    lda m_sprite_x
;    sta VERA_data0     ; Update X coordinate
;    stz VERA_data0     ; Zero out high byte
;    lda m_sprite_y
;    sta VERA_data0     ; Update Y coordinate
;    stz VERA_data0     ; Zero out high byte
;    rts
;
;exit_game:
;    ; Code to exit the game
;    rts    
;
;
;;------------------------------------ End of Game Subroutines