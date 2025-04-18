; //////////////////////////////////////////////////////////////////////
; File:         x16.inc
; Description:  X16 System constants
; //////////////////////////////////////////////////////////////////////
.ifndef _X16_INC
_X16_INC  = 1

.ifndef __CX16__
__CX16__ = 1
.endif


SD_DEVICE          = 1
HOST_DEVICE        = 8
DISK_DEVICE = HOST_DEVICE

; I/O Registers
VERA_ADDR_LOW     = $9F20
VERA_ADDR_HIGH    = $9F21
VERA_ADDR_BANK    = $9F22
VERA_DATA0        = $9F23
VERA_DATA1        = $9F24
VERA_CTRL         = $9F25
VERA_IEN          = $9F26 ; VERA IRQ, IRQ line (bit7), SCANLINE (bit6)
VERA_ISR          = $9F27 ; VERA IRQ, Sprite Collision (bit 7-4)
VERA_IRQLINE_L    = $9F28 ; VERA IRQ Line low byte. 0-7 are VERA IRQs
VERA_DC_VIDEO     = $9F29
VERA_DC_HSCALE    = $9F2A
VERA_DC_VSCALE    = $9F2B
VERA_DC_BORDER    = $9F2C
VERA_DC_HSTART    = $9F29
VERA_dc_hstop     = $9F2A
VERA_dc_vsstart   = $9F2B
VERA_dc_vstop     = $9F2C
VERA_L0_CONFIG    = $9F2D
VERA_L0_MAPBASE   = $9F2E
VERA_L0_TILEBASE  = $9F2F
VERA_L0_HSCROLL_L = $9F30
VERA_L0_HSCROLL_H = $9F31
VERA_L0_VSCROLL_L = $9F32
VERA_L0_VSCROLL_H = $9F33
VERA_L1_CONFIG    = $9F34
VERA_L1_MAPBASE   = $9F35
VERA_L1_TILEBASE  = $9F36
VERA_L1_HSCROLL_L = $9F37
VERA_L1_HSCROLL_H = $9F38
VERA_L1_VSCROLL_L = $9F39
VERA_L1_VSCROLL_H = $9F3A
VERA_AUDIO_CTRL  = $9F3B
VERA_AUDIO_RATE   = $9F3C
VERA_AUDIO_DATA   = $9F3D
VERA_SPI_DATA     = $9F3E
VERA_SPI_CTRL     = $9F3F

ROM_BANK          = $01
RAM_BANK          = $00

YM_REG            = $9F40
YM_DATA           = $9F41

; ROM Banks
KERNAL_ROM_BANK   = 0
KEYBOARD_ROM_BANK = 1
CBDOS_ROM_BANK    = 2
GEOS_ROM_BANK     = 3
BASIC_ROM_BANK    = 4
MONITOR_ROM_BANK  = 5
CHARSET_ROM_BANK  = 6

; Banked Addresses
RAM_WIN           = $A000
RAM_WIN_SIZE      = $2000
ROM_WIN           = $C000

; Kernal Subroutines
ENTROPY_GET             := $FECF
CONSOLE_set_paging      := $FED5
CONSOLE_put_image       := $FED8
CONSOLE_init            := $FEDB
CONSOLE_put_char        := $FEDE
CONSOLE_get_char        := $FEE1
MEMORY_FILL             := $FEE4
MEMORY_COPY             := $FEE7
MEMORY_CRC              := $FEEA
MEMORY_DECOMPRESS       := $FEED
SPRITE_set_image        := $FEF0
SPRITE_set_position     := $FEF3
FB_init                 := $FEF6
FB_get_info             := $FEF9
FB_set_palette          := $FEFC
FB_cursor_position      := $FEFF
FB_cursor_next_line     := $FF02
FB_get_pixel            := $FF05
FB_get_pixels           := $FF08
FB_set_pixel            := $FF0B
FB_set_pixels           := $FF0E
FB_set_8_pixels         := $FF11
FB_set_8_pixels_opaque  := $FF14
FB_fill_pixels          := $FF17
FB_filter_pixels        := $FF1A
FB_move_pixels          := $FF1D
GRAPH_init              := $FF20
GRAPH_clear             := $FF23
GRAPH_set_window        := $FF26
GRAPH_set_colors        := $FF29
GRAPH_draw_line         := $FF2C
GRAPH_draw_rect         := $FF2F
GRAPH_move_rect         := $FF32
GRAPH_draw_oval         := $FF35
GRAPH_draw_image        := $FF38
GRAPH_set_font          := $FF3B
GRAPH_get_char_size     := $FF3E
GRAPH_put_char          := $FF41
MONITOR                 := $FF44
ENTER_BASIC             := $FF47
CLOSE_ALL               := $FF4A
CLOCK_SET_DATE_TIME     := $FF4D
CLOCK_GET_DATE_TIME     := $FF50
JOYSTICK_SCAN           := $FF53
JOYSTICK_GET            := $FF56
SCREEN_MODE             := $FF5F
SCREEN_SET_CHARSET      := $FF62
PFKEY                   := $FF65
MOUSE_CONFIG            := $FF68
MOUSE_GET               := $FF6B
JSRFAR_kernal_addr      := $FF6E
MOUSE_SCAN              := $FF71
FETCH                   := $FF74
STASH                   := $FF77
CMPARE                  := $FF7A
PRIMM                   := $FF7D
SCINIT                  := $FF81
IOINIT                  := $FF84
RAMTAS                  := $FF87
RESTOR                  := $FF8A
LKUPLA                  := $FF8D
SETMSG                  := $FF90
SECOND                  := $FF93
TKSA                    := $FF96
MEMTOP                  := $FF99
MEMBOT                  := $FF9C
SCNKEY                  := $FF9F
SETTMO                  := $FFA2
IECIN                   := $FFA5
IECOUT                  := $FFA8
UNTALK                  := $FFAB
UNLISTEN                := $FFAE
LISTEN                  := $FFB1
TALK                    := $FFB4
READST                  := $FFB7
SETLFS                  := $FFBA
SETNAM                  := $FFBD
OPEN                    := $FFC0
CLOSE                   := $FFC3
CHKIN                   := $FFC6
CHKOUT                  := $FFC9
CLRCHN                  := $FFCC
CHRIN                   := $FFCF
BASIN                   := CHRIN ; alias
CHROUT                  := $FFD2
BSOUT                   := CHROUT ; alias
LOAD                    := $FFD5
SAVE                    := $FFD8
SETTIM                  := $FFDB
RDTIM                   := $FFDE
STOP                    := $FFE1
GETIN                   := $FFE4
CLALL                   := $FFE7
UDTIM                   := $FFEA
SCREEN                  := $FFED
PLOT                    := $FFF0
IOBASE                  := $FFF3

; BASIC Vectors
BASIC_PANIC             := $C000
BASIC_INIT              := $C003




; IRQ Vectors
IRQVEC         := $0314
BRKVEC         := $0316
NMIVEC         := $0318
FETVEC         := $03AF


;Zero-Page userspace
ZP_PTR_1          = $7E	
ZP_PTR_2          = $22
ZP_PTR_3          = $24
ZP_PTR_4          = $26


.endif
