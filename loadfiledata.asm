; ===================================================================
; File:         loadfiledata.asm
; Programmer:   Matt Heffernan modified by Dustin Taub
; Description:  binary file loading
;===================================================================
.ifndef _LOADFILEDATA_ASM 
_LOADFILEDATA_ASM = 1

.include "x16.inc"
.include "macros.inc"

filenames:
tilemap_fn:              .asciiz "tilemap.bin"
sprites_fn:              .asciiz "sprites.bin"
spritesmall_fn:              .asciiz "spritesm.bin"
tiles_fn:                .asciiz "tiles.bin"
startscreen_fn:          .asciiz "cover.bin"
uimap_fn:                .asciiz "uimap.bin"
;zsmkit_fn:  	         .asciiz "zsmkit.bin"
;song_fn:                 .asciiz "song1.zsm"

;music_fn:                .asciiz "musictst.bin"
;palette_fn:                .asciiz "pal.bin"
;spriteattr_fn:             .asciiz "sprtattr.bin"




; ===================================================================
; loadtovram - Loads a binary file to VRAM 
; Inputs:
;   A = VRAM address high (19:12)
;   X = VRAM address low (11:4) 
;   Y = filename address low (7:0)
; ===================================================================
loadtovram:          
    pha               ; push original A argument to stack, high address of VRAM
    txa               ; X to A = VRAM address low
    sta ZP_PTR_1      ; store VRAM low address argument to ZP
    tya               ; Y to A = filename address low
    sta ZP_PTR_1 + 1  ; store filename address argument to ZP + 1
    MACRO_SETLFS 1, HOST_DEVICE, 0 ; setup and use SETLFS macro
    ldx ZP_PTR_1 + 1  ; load filename address into X
    stx ZP_PTR_2      ; store filename address in ZP_PTR_2
    ldy #>filenames   ; Y = high byte of filename address (corrected to match filenames table)
    sty ZP_PTR_2 + 1  ; store high byte of filename address in ZP_PTR_2 + 1
    ldy #0
@loop:
    lda (ZP_PTR_2) , y; filename address
    beq @foundnull    ; jump if null terminator found
    iny               ; increment Y to next character
    jmp @loop         ; loop until null terminator is found
@foundnull:           
    tya               ; A = filename length
    ldy #>filenames   ; Y = high byte of filename address (fixed spacing issue)
    jsr SETNAM 
    pla               ; pull original A argument
    tax 
    and #$F0          ; mask VRAM bank << 4
    lsr 
    lsr 
    lsr 
    lsr 
    clc 
    adc #2
    pha               ; push VRAM bank + 2 (FILE HEADER LOCATION)
    txa 
    asl 
    asl 
    asl 
    asl 
    pha                ; push high nibble of VRAM address high byte (15:12)
    lda ZP_PTR_1 
    tax                ; X = VRAM Address (11:4)
    lsr 
    lsr 
    lsr 
    lsr 
    sta ZP_PTR_1       ; store VRAM Address (11:8) to ZP
    pla                ; pull VRAM address (15:12)
    ora ZP_PTR_1 
    tay                ; Y = VRAM Address high byte (15:8)
    txa 
    asl 
    asl 
    asl 
    asl 
    tax                ; X = VRAM Address low byte (7:0)
    pla                ; A = VRAM bank + 2 (FILE HEADER LOCATION)
    jsr LOAD 
    rts 

; ===================================================================
; loadtoram - Loads a binary file to RAM with banking support
; Inputs:
;   A = RAM bank number (0-255)
;   X = RAM address high byte ($00-$9F, $A0-$BF is banked)
;   Y = filename address (index into filenames table)
; ===================================================================
loadtoram:
    pha                         ; Save new RAM bank number
    txa 
    sta ZP_PTR_1                ; Store RAM address high byte
    tya 
    sta ZP_PTR_1 + 1            ; Store filename index
    MACRO_SETLFS 1, HOST_DEVICE, 0 ; setup and use SETLFS macro
  
    ; Set up filename
    ldx ZP_PTR_1 + 1            ; X = index into filenames
    stx ZP_PTR_2 
    ldy #>filenames             ; Y = high byte of filenames table
    sty ZP_PTR_2 + 1  ; store high byte of filename address in ZP_PTR_2 + 1
    ldy #0
@loop:
    lda (ZP_PTR_2) , y; filename address
    beq @foundnull    ; jump if null terminator found
    iny               ; increment Y to next character
    jmp @loop         ; loop until null terminator is found
@foundnull:           
    tya               ; A = filename length
    ldy #>filenames   ; Y = high byte of filename address (fixed spacing issue)
    jsr SETNAM 

    ; Set up load destination   
    pla                         ; Restore new RAM bank number
    tay                         ; Transfer to Y to preserve A
    sta RAM_BANK                ; Set the new RAM bank
    tya                         ; Restore A from Y
    lda #0                      ; 0 = load to address in X,Y
    ldx #0                      ; Low byte of RAM address
    ldy ZP_PTR_1                ; High byte of RAM address
    jsr LOAD                    ; Load the file
    rts 



; ===================================================================
; loadbankedtovram
; Inputs:
;   A = RAM source address high byte
;   X = VRAM destination address high byte (15:8)
;   Y = VRAM destination address low byte (7:0)
; ===================================================================
loadbankedtovram:
    sta ZP_PTR_1            ; Store RAM source address high byte in ZP
    stx ZP_PTR_2            ; Store VRAM destination address high byte in ZP
    sty ZP_PTR_2 + 1        ; Store VRAM destination address low byte in ZP
    lda #0                  ; Start with low byte of RAM source address
    sta ZP_PTR_1 + 1        ; Set low byte of RAM source address to 0
@transfer_loop:
    lda (ZP_PTR_1),y        ; Load byte from RAM source
    sta (ZP_PTR_2),y        ; Store byte to VRAM destination
    iny                     ; Increment low byte of VRAM address
    bne @transfer_loop      ; Continue if low byte hasn't wrapped around
    inc ZP_PTR_1            ; Increment high byte of RAM source address
    inc ZP_PTR_2 + 1        ; Increment high byte of VRAM destination low byte
    lda ZP_PTR_1            ; Check if RAM source address has reached the end
    cmp #$A0                ; Assuming $A0 is the end of the RAM bank
    bcc @transfer_loop      ; Continue if not reached
    rts                     ; Return from subroutine



.endif
