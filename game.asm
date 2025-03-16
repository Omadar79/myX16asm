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

; Game Asset Location - VRAM Addresses
m_vram_L0_maps        = $00000
m_vram_L1_maps        = $00200
m_vram_tiles          = $00800
m_vram_sprite0        = $04000 ; sprite 0 data
m_vram_sprite0_attr   = $1FC00 ; sprite 0 attribute table


; *****Layer Config -  MAP_H | MAP_W | T256 |BMP MODE| COLOR DEPTH
; MAP_H/MAP_W 0 = 32,1 = 64,2 = 128,3 = 256
; BMP MODE 0 = Text/Tile, 1 = Bitmap
; T256 0 = 16 color, 1 = 256 color
; COLOR DEPTH 0 = 1bpp, 2 = 4bpp, 3 = 8bpp

; *****Layer Map Base -  tile map start address >> 9

; *****Layer Tile Base - tile graphic base address >> 11 | Tile_H | Tile_W 
; TILE_H/TILE_W 0 = 8,1 = 16


;------------------------------------ Constants
SCALE          = $28 ; $50 = 1x (640x480), $28 = 2x (320x240) , $14 = 4x (160x120)
LAYERCONFIG0   = $02 ; 00000010 = 32x32 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp
LAYERCONFIG1   = $C2 ; 11000010 = 64x64 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp

SPRITE_64H     = $C0
SPRITE_64W     = $30
SPRITE_32H     = $80
SPRITE_32W     = $20
SPRITE_16H     = $40
SPRITE_16W     = $10

; Keyboard Keys
SPACE           = $20
SPADE           = $41
CHAR_Q          = $51 ; "Q" key
CLR             = $93

;------------------------------------ Variables
sprite_x: .byte 80
sprite_y: .byte 50

.include "dataSprites.inc"
.include "dataMapTiles.inc"


start:

;------------------------------------ Initialize the game

    ;sta VERA_L0_config
    lda #SCALE ; 2x scale
    sta VERA_dc_hscale
    sta VERA_dc_vscale  
    
    ; configure layer 0: space
    lda #LAYERCONFIG1 
    sta VERA_L0_config
    lda #(m_vram_L0_maps >> 9)
    sta VERA_L0_mapbase
    lda #(m_vram_tiles >> 9) ; 8x8 tiles
    sta VERA_L0_tilebase
    stz VERA_L0_hscroll_l ; horizontal scroll = 0
    stz VERA_L0_hscroll_h
    stz VERA_L0_vscroll_l ; vertical scroll = 0
    stz VERA_L0_vscroll_h
    
   

    ;; configure layer 1: Front Layer
    lda #LAYERCONFIG1  
    sta VERA_L1_config
    lda #(m_vram_L1_maps >> 9)
    sta VERA_L1_mapbase
    lda #(m_vram_tiles >> 9) ; 8x8 tiles
    sta VERA_L1_tilebase
    stz VERA_L1_hscroll_l ; horizontal scroll = 0
    stz VERA_L1_hscroll_h
    stz VERA_L1_vscroll_l ; vertical scroll = 0
    stz VERA_L1_vscroll_h

    ; copy tile maps to VRAM
    RAM_TO_VRAM map_tiles, m_vram_L0_maps, MAPS_SIZE
    ; copy tiles to VRAM
    RAM_TO_VRAM tiles, m_vram_tiles, TILES_SIZE

    ;VERA_SET_ADDR m_vram_Sprite0,1
    RAM_TO_VRAM spaceship1, m_vram_sprite0, 128


    VERA_SET_ADDR m_vram_sprite0_attr,1
    lda #<(m_vram_sprite0 >> 5)
    sta VERA_data0
    lda #>(m_vram_sprite0 >> 5)
    sta VERA_data0

    lda sprite_x
    sta VERA_data0  ; x attribute
    stz VERA_data0  ; zero out high byte
    lda sprite_y
    sta VERA_data0 ; y attribute
    stz VERA_data0 ; zero out high byte
    lda #$0C        ; z-level
    sta VERA_data0
    lda #(SPRITE_16H | SPRITE_16W | 1)
    ;lda #$F0 ;(SPRITE_64H | SPRITE_64W)    ; palette offset
    sta VERA_data0


    ; Enable sprites
    stz VERA_ctrl        ; Set DCSEL to 0
    lda VERA_dc_video
    ora #$40          ; Enable sprites
    sta VERA_dc_video

;------------------------------------ Start the Game Loop
main_loop:

    jsr SCNKEY          ; Read a character from the keyboard
    cmp #$57           ; Compare with 'W' (up)
    beq move_up
    cmp #$41           ; Compare with 'A' (left)
    beq move_left
    cmp #$53           ; Compare with 'S' (down)
    beq move_down
    cmp #$44           ; Compare with 'D' (right)
    beq move_right
    cmp #$1E           ; Compare with cursor up
    beq move_up
    cmp #$1D           ; Compare with cursor left
    beq move_left
    cmp #$1F           ; Compare with cursor down
    beq move_down
    cmp #$1C           ; Compare with cursor right
    beq move_right
    cmp #$1B           ; Compare with ESC key
    beq exit_game
    jmp main_loop      ; Loop back to read the next character

;------------------------------------ End of Game Loop


;------------------------------------ Game Subroutines
move_up:
    lda sprite_y
    sec
    sbc #1             ; Decrease Y coordinate
    sta sprite_y
    jsr update_sprite_position
    jmp main_loop

move_left:
    lda sprite_x
    sec
    sbc #1             ; Decrease X coordinate
    sta sprite_x
    jsr update_sprite_position
    jmp main_loop

move_down:
    lda sprite_y
    clc
    adc #1             ; Increase Y coordinate
    sta sprite_y
    jsr update_sprite_position
    jmp main_loop

move_right:
    lda sprite_x
    clc
    adc #1             ; Increase X coordinate
    sta sprite_x
    jsr update_sprite_position
    jmp main_loop    


update_sprite_position:
    ; Update the sprite position in VRAM
    VERA_SET_ADDR m_vram_sprite0_attr,1
    lda sprite_x
    sta VERA_data0     ; Update X coordinate
    stz VERA_data0     ; Zero out high byte
    lda sprite_y
    sta VERA_data0     ; Update Y coordinate
    stz VERA_data0     ; Zero out high byte
    rts

exit_game:
    ; Code to exit the game
    rts    


;------------------------------------ End of Game Subroutines