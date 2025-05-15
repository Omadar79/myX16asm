; ===================================================================
; File:         sinewaves.asm
; Programmer:   Dustin Taub
; Description:  lookup table for sine and cosine values
;               quick lookup for enemy movements
;===================================================================

; Sine wave table (256 values covering 0-360 degrees)
; Values range from 0 to 255 (128 is the zero point)
sine_table:
    .byte 128, 131, 134, 137, 140, 144, 147, 150
    .byte 153, 156, 159, 162, 165, 168, 171, 174
    .byte 177, 179, 182, 185, 188, 191, 193, 196
    .byte 199, 201, 204, 206, 209, 211, 213, 216
    .byte 218, 220, 222, 224, 226, 228, 230, 232
    .byte 234, 235, 237, 239, 240, 241, 243, 244
    .byte 245, 246, 248, 249, 250, 250, 251, 252
    .byte 253, 253, 254, 254, 254, 255, 255, 255
    .byte 255, 255, 255, 255, 254, 254, 254, 253
    .byte 253, 252, 251, 250, 250, 249, 248, 246
    .byte 245, 244, 243, 241, 240, 239, 237, 235
    .byte 234, 232, 230, 228, 226, 224, 222, 220
    .byte 218, 216, 213, 211, 209, 206, 204, 201
    .byte 199, 196, 193, 191, 188, 185, 182, 179
    .byte 177, 174, 171, 168, 165, 162, 159, 156
    .byte 153, 150, 147, 144, 140, 137, 134, 131
    .byte 128, 125, 122, 119, 116, 112, 109, 106
    .byte 103, 100,  97,  94,  91,  88,  85,  82
    .byte  79,  77,  74,  71,  68,  65,  63,  60
    .byte  57,  55,  52,  50,  47,  45,  43,  40
    .byte  38,  36,  34,  32,  30,  28,  26,  24
    .byte  22,  21,  19,  17,  16,  15,  13,  12
    .byte  11,  10,   8,   7,   6,   6,   5,   4
    .byte   3,   3,   2,   2,   2,   1,   1,   1
    .byte   1,   1,   1,   1,   2,   2,   2,   3
    .byte   3,   4,   5,   6,   6,   7,   8,  10
    .byte  11,  12,  13,  15,  16,  17,  19,  21
    .byte  22,  24,  26,  28,  30,  32,  34,  36
    .byte  38,  40,  43,  45,  47,  50,  52,  55
    .byte  57,  60,  63,  65,  68,  71,  74,  77
    .byte  79,  82,  85,  88,  91,  94,  97, 100
    .byte 103, 106, 109, 112, 116, 119, 122, 125

; ===================================================================
; get_sine - Get sine value from lookup table
; Input: A = angle (0-255 representing 0-360 degrees)
; Output: A = sine value from 0-255 (128 is the zero point)
; ===================================================================
get_sine:
    tax                     ; Use angle as index
    lda sine_table , x      ; Load sine value (0-255)
    rts 

; ===================================================================
; get_cosine - Get cosine value from lookup table
; Input: A = angle (0-255 representing 0-360 degrees)
; Output: A = cosine value from 0-255 (128 is the zero point)
; ===================================================================
get_cosine:
    clc 
    adc #64                 ; Add 90 degrees (64 = 256/4)
    tax                     ; Use as index
    lda sine_table , x      ; Load value (cosine = sine + 90°)
    rts 