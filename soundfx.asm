; ===================================================================
; File:         soundfx.asm
; Programmer:   Dustin Taub
; Description:  Sound effects for the game
;===================================================================
.ifndef SOUNDFX_ASM
SOUNDFX_ASM = 1

.include "x16.inc"
.include "zsound.inc"
.include "globals.asm"


; Frequency
MIDDLE_C = 702
FREQ_STEP = 20

; Notes
C3 = MIDDLE_C - 12*FREQ_STEP
D3 = MIDDLE_C - 10*FREQ_STEP
E3 = MIDDLE_C - 8*FREQ_STEP
