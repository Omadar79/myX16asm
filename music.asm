; ======================================================================
; File:         music.asm
; Programmer:   Dustin Taub 
; Description:  Attempt to play ZSM files for music based on MooningLemur's ZSMKIT
; ======================================================================
.ifndef _MUSIC_ASM
_MUSIC_ASM = 1

.include "x16.inc"
.include "zsmkit.inc"

zsmkit_lowram:              .res 256

zsmkit_filename:
	.byte "zsmkit.bin"
zsmkit_filename_end:

filename1:
	.byte "test1.zsm"
filename2:
	.byte "song2.zsm"
filename3:
	.byte "song3.zsm"
filename4:
	.byte "song4.zsm"
filename5:
	.byte "song5.zsm"
filename6:
	.byte "song6.zsm"
filename7:
song1:
	.byte 0,0,0
song2:
	.byte 0,0,0
song3:
	.byte 0,0,0
song4:
	.byte 0,0,0
song5:
	.byte 0,0,0
song6:
	.byte 0,0,0

; RAM Banks

ZSMKIT_BANK      = $05
ZSMKIT_BANK2     = $06
ZSMKIT_BANK3     = $07

; Music Sound Init ------------------------------------------------------------
music_init:
    ; Load ZSMKIT into RAM bank 5
    lda #ZSMKIT_BANK 
	sta RAM_BANK 
	lda #zsmkit_filename_end - zsmkit_filename 
	ldx #<zsmkit_filename 
	ldy #>zsmkit_filename 
	jsr SETNAM 

	lda #2
	ldx #8
	ldy #2
	jsr SETLFS 

	ldx #$00
	ldy #$a0
	lda #0
	jsr LOAD 

	lda #ZSMKIT_BANK 
	sta RAM_BANK
	ldx #<zsmkit_lowram 
	ldy #>zsmkit_lowram 
	jsr zsm_init_engine 

    ;-------- Load ZSM song 1 file into RAM bank 6
    
    ; ---------song1
	lda #ZSMKIT_BANK + 1
	sta RAM_BANK 
	sta song1 + 2
	lda #filename2 - filename1 
	ldx #<filename1 
	ldy #>filename1 
	jsr SETNAM 
	lda #2
	ldx #8
	ldy #2
	jsr SETLFS 
	ldx #$00
	stx song1 
	ldy #$a0
	sty song1 + 1 
	lda #0
	jsr LOAD 

    ; ---------song2
	stx song2 
	sty song2 + 1
	lda RAM_BANK 
	sta song2 + 2
	lda #filename3 - filename2 
	ldx #<filename2 
	ldy #>filename2 
	jsr SETNAM 
	lda #2
	ldx #8
	ldy #2
	jsr SETLFS 
	ldx song2 
	ldy song2 + 1
	lda #0
	jsr LOAD 

    ; ---------song3
	stx song3 
	sty song3 + 1
	lda RAM_BANK 
	sta song3 + 2
	lda #filename4 - filename3 
	ldx #<filename3 
	ldy #>filename3 
	jsr SETNAM 
	lda #2
	ldx #8
	ldy #2
	jsr SETLFS 
	ldx song3 
	ldy song3 + 1
	lda #0
	jsr LOAD 

    ; ---------song4
	stx song4 
	sty song4 + 1
	lda RAM_BANK 
	sta song4 + 2 
	lda #filename5 - filename4 
	ldx #<filename4 
	ldy #>filename4 
	jsr SETNAM 
	lda #2
	ldx #8
	ldy #2
	jsr SETLFS 
	ldx song4 
	ldy song4 + 1
	lda #0
    jsr LOAD 

    ; ---------song5
	stx song5 
	sty song5 + 1
	lda RAM_BANK 
	sta song5 + 2
	lda #filename6 - filename5 
	ldx #<filename5 
	ldy #>filename5 
	jsr SETNAM 
	lda #2
	ldx #8
	ldy #2
	jsr SETLFS 
	ldx song5 
	ldy song5 + 1
	lda #0
    jsr LOAD 

    ; ---------song6	
    stx song6 
	sty song6 + 1
	lda RAM_BANK 
	sta song6 + 2
	lda #filename7 - filename6 
	ldx #<filename6 
	ldy #>filename6 
	jsr SETNAM 
	lda #2
	ldx #8
	ldy #2
	jsr SETLFS 
	ldx song6 
	ldy song6 + 1
	lda #0
	jsr LOAD 

; Start Song Playback ------------------------------------------------------------
	lda #ZSMKIT_BANK 
	sta RAM_BANK 
	lda song1 + 2
	ldx #0
	jsr zsm_setbank 

	lda song1 
	ldy song1 + 1 
	ldx #0
	jsr zsm_setmem 

	ldx #0
	jsr zsm_play 

	lda #0
	sta ROM_BANK 

    lda #$00
    sta RAM_BANK 

   ; lda #ZSMKIT_BANK 
   ; sta RAM_BANK           ; Set the current RAM bank
   ; ldx #<zsmkit_lowram 
	;ldy #>zsmkit_lowram 
   ; jsr zsm_init_engine 

	;lda #ZSMKIT_BANK + 1
   ; sta RAM_BANK           ; Set the current RAM bank
	;sta songdata1 + 2
   ; 
   ; ;lda songdata1 + 2         ; RAM bank for this asset
   ; ldx #$A0                  ; High byte of address ($A000 in Bank ZSMKIT_BANK 5)
   ; ldy #<song_fn                
   ; jsr loadtoram 
	;tya 
   ; sta songdata1 + 1
   ; txa 
	;sta songdata1 

   ; lda #ZSMKIT_BANK 
	;sta RAM_BANK 
	;lda songdata1 + 2
	;ldx #0
	;jsr zsm_setbank 

	;lda songdata1 
	;ldy songdata1 + 1
	;ldx #0
	;jsr zsm_setmem 

	;ldx #1
	;jsr zsm_play 

    rts 

    .endif