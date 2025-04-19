; //////////////////////////////////////////////////////////////////////
; File:         globals.asm
; Programmer:   Dustin Taub
; Description:  Global variables and constants for the game 
; //////////////////////////////////////////////////////////////////////
.ifndef GLOBALS_INC
GLOBALS_INC = 1


;----------------------------------- ZERO PAGE VARIABLES ----------------------------------
;ZP_PTR_1 to ZP_PTR_4 are temp and defined in x16.inc  ($7E, $22, $24, $26)

ZP_PTR_DIR      = $28 ; ZP pointer for direction  0 = no move, 1 = right, 2 = left, 3 = up, 4 = down
ZP_GAME_STATE   = $2A

ZP_DID_STATE_CHANGE = $2C ; 0 = no state change, 1 = state change


;------------------------------------ Constants
SCALE_160X120        = 32  ; 14 = 4x (160x120)
SCALE_320X240        = 64  ; 64 = 2x 320x240 or 40column
SCALE_640X480        = 128 ; 64 = 1x 640x480 or 80column


LAYERCONFIG_32x324BPP    = %00000010 ; 32x32 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp
LAYERCONFIG_64X324BPP    = %00010010 ; 64x32 | Text/Tile Mode | T256 0 | BMP 0 | Color 4bpp
LAYERCONFIG_BITMP4BPP    = %00000110 ; 00 00 | T256 0 | BMP 1 | Color 4bpp 10
LAYERCONFIG_TEXT1BPP     = %01100000 ; 64x128 | T256 0 | BMP 0 | Color 1pp 00

SCREEN_MIN_Y_L           = $05
SCREEN_MIN_Y_H           = $00
SCREEN_MAX_Y_L           = $E0
SCREEN_MAX_Y_H           = $00
SCREEN_MIN_X_L           = $05
SCREEN_MIN_X_H           = $00
SCREEN_MAX_X_L           = $30
SCREEN_MAX_X_H           = $01


SPACE_DELAY             = 16  ; Parallax Scrolling

SPRITE_SIZE             = 16 * 16 / 2 ; 4bpp 16x16 sprite

GAME_STATE_LOADING      = $00
GAME_STATE_START_SCREEN = $01
GAME_STATE_IN_GAME      = $02
GAME_STATE_PAUSED       = $03

;--------------------------------- Variables -------------------------------------------------------

game_state = ZP_GAME_STATE 
has_state_changed = ZP_DID_STATE_CHANGE 
player_xy_state = ZP_PTR_DIR 
; (fractional numbers 192 = 0.75, 128 = 0.5 , 64 = 0.25 , 32 = 0.125 , etc)
parallax_scroll_delay:      .byte 0
frame_num:                  .byte 0
player_sprite_x_l:          .byte 0       ; Low byte of X position
player_sprite_x_h:          .byte 0        ; High byte of X position
player_sprite_y_l:          .byte 0       ; Low byte of Y position
player_sprite_y_h:          .byte 0        ; High byte of Y position, don't really use this other than address loading
player_speed_x:             .byte 2
player_speed_y:             .byte 2
player_sprite_index:        .byte 0        ; sprite index in VERA
default_irq_vector:         .addr 0


pause_message:          .byte "GAME PAUSED PRESS ESC TO RESUME", 0



filenames:
tilemap_fn:     .asciiz "tilemap.bin"
sprites_fn:     .asciiz "sprites.bin"
tiles_fn:       .asciiz "tiles.bin"
startscreen_fn: .asciiz "cover.bin"
;palette_fn:    .asciiz "pal.bin"
;spriteattr_fn: .asciiz "sprtattr.bin"


;---------------------------------End of Variables -----------------------------------------------

.endif