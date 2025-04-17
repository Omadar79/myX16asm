; //////////////////////////////////////////////////////////////////////
; File:         globals.asm
; Programmer:   Dustin Taub
; Description:  Global variables and constants for the game 
; //////////////////////////////////////////////////////////////////////
.ifndef GLOBALS_INC
GLOBALS_INC = 1

;------------------------------------ Constants
SCALE_160X120        = 32  ; 14 = 4x (160x120)
SCALE_320X240        = 64  ; 64 = 2x 320x240 or 40column
SCALE_640X480        = 128 ; 64 = 1x 640x480 or 80column


LAYERCONFIG_32x324BPP    = %00000010 ; 32x32 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp
LAYERCONFIG_64X324BPP    = %00010010 ; 64x32 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp
LAYERCONFIG_BITMP4BPP    = %00000110 ; 00 00 | T256 0 | BMP 1 | Color 4bpp 10

SCREEN_MIN_Y_L      = $05
SCREEN_MIN_Y_H      = $00
SCREEN_MAX_Y_L      = $E0
SCREEN_MAX_Y_H      = $00
SCREEN_MIN_X_L      = $05
SCREEN_MIN_X_H      = $00
SCREEN_MAX_X_L      = $30
SCREEN_MAX_X_H      = $01


SPACE_DELAY       = 16  ; Parallax Scrolling

; Game Asset Location - VRAM Addresses

VRAM_TILES          = $00000 ; 227 4bpp 16x16 tiles (may also be used as sprite frames)
VRAM_SPRITES        = $08000 ;  4bpp 16x16 sprite frames  0-2 spaceshipt, 3-4 flame/jet 08C00-9000
VRAM_BITMAP         = $0E000 ; 4bpp 320x240 bitmap
VRAM_TILEMAP        = $17800 ; 32x32 tilemap
VRAM_PARALLAXMAP     = $18000 ; 32x32 tilemap
VRAM_SPRITE_ATTR    = $1FC00 ; sprite 0 attribute table, 1FD00 sprite 1 attribute table

SPRITE_SIZE = 16 * 16 / 2 ; 4bpp 16x16 sprite

;--------------------------------- Variables -------------------------------------------------------
; (fractional numbers 192 = 0.75, 128 = 0.5 , 64 = 0.25 , 32 = 0.125 , etc)
parallax_scroll_delay:      .byte 0
frame_num:                  .byte 0
player_sprite_x_l:          .byte 0       ; Low byte of X position
player_sprite_x_h:          .byte 0        ; High byte of X position
player_sprite_y_l:          .byte 0       ; Low byte of Y position
player_sprite_y_h:          .byte 0        ; High byte of Y position, don't really use this other than address loading
player_speed_x:             .byte 2
player_speed_y:              .byte 2


player_sprite_index:        .byte 0        ; sprite index in VERA
default_irq_vector:         .addr 0

joystick_state:             .byte 0
joystick_latch:             .byte $CF




filenames:
tilemap_fn:     .asciiz "tilemap.bin"
sprites_fn:     .asciiz "sprites.bin"
tiles_fn:       .asciiz "tiles.bin"
startscreen_fn: .asciiz "cover.bin"
;palette_fn:    .asciiz "pal.bin"
;spriteattr_fn: .asciiz "sprtattr.bin"


;---------------------------------End of Variables -----------------------------------------------

.endif