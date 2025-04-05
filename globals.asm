.ifndef GLOBALS_INC
GLOBALS_INC = 1

;------------------------------------ Constants
SCALE_160X120        = 32  ; 14 = 4x (160x120)
SCALE_320X240        = 64  ; 64 = 2x 320x240 or 40column
SCALE_640X480        = 128 ; 64 = 1x 640x480 or 80column


LAYERCONFIG_32x324BPP    = %00000010 ; 32x32 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp
LAYERCONFIG_64X324BPP    = %00010010 ; 64x32 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp
LAYERCONFIG_BITMP4BPP    = %00000110 ; 00 00 | T256 0 | BMP 1 | Color 4bpp 10

; Keyboard Keys
SPACE             = $20
SPADE             = $41
CHAR_Q            = $51 ; "Q" key
CLR               = $93

SPACE_DELAY       = 16  ; Parallax Scrolling

; Game Asset Location - VRAM Addresses

VRAM_TILES          = $00000 ; 227 4bpp 16x16 tiles (may also be used as sprite frames)
; VRAM_LOADMAP        = $07800 ; 32x32 tilemap
VRAM_SPRITES         = $08000 ; 192 4bpp 16x16 frames
VRAM_BITMAP         = $0E000 ; 4bpp 320x240 bitmap
VRAM_TILEMAP        = $17800 ; 128x128 tilemap
VRAM_STARTSCRN      = $1F000 ; 64x32 tilemap
VRAM_SPRITE_ATTR    = $1FC00 ; sprite 0 attribute table



;--------------------------------- Variables -------------------------------------------------------
; (fractional numbers 192 = 0.75, 128 = 0.5 , 64 = 0.25 , 32 = 0.125 , etc)
parallax_scroll_delay:  .byte 0
frame_num:              .byte 0
player_sprite_x:        .byte 50
player_sprite_x_frac:   .byte 0        ; Fractional part of X position
player_sprite_y:        .byte 50
player_sprite_y_frac:   .byte 0        ; Fractional part of Y position
player_speed:           .byte 2
player_speed_frac:      .byte 128      ; factional part of peed in pixels 
default_irq_vector:     .addr 0

joystick_state:      .byte 0
joystick_latch:      .byte $CF


filenames:
tilemap_fn:     .asciiz "tilemap.bin"
sprites_fn:     .asciiz "sprites.bin"
tiles_fn:       .asciiz "tiles.bin"
startscreen_fn: .asciiz "cover.bin"
;palette_fn:    .asciiz "pal.bin"
;spriteattr_fn: .asciiz "sprtattr.bin"


;---------------------------------End of Variables -----------------------------------------------

.endif