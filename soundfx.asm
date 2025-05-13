; ======================================================================
; File:         soundfx.asm
; Programmer:   Dustin Taub (adapted from Dusan Strakl's effects.asm)
; Description:  Sound effects system for the game using VERA PSG
; ======================================================================
.ifndef _SOUNDFX_ASM
_SOUNDFX_ASM = 1

.include "x16.inc"

; ----VERA PSG channel 15 (last channel) is used for sound effects
PSG_CHANNEL = $1F9FC  ; Channel 15 (F*4 + 1F9C0)
PSG_VOLUME  = PSG_CHANNEL + 2

; ----Local variables for sound system
sfx_running:      .byte 0      ; 0 = not running, 1 = running
sfx_phase:        .byte 0      ; 0 = not playing, 255 = start, 1 = release
sfx_old_irq:      .word 0      ; Backup of the IRQ vector

; ----Sound effect parameters
sfx_channel:      ; Start of our parameter block
sfx_release_count: .byte 0      ; How many frames the release phase lasts
sfx_frequency:     .word 0      ; Current frequency (16-bit)
sfx_waveform:      .byte 0      ; Waveform type  ($00 = square, $01 = sawtooth, $10 = triangle, $11 = noise) | $00 0000 Pulse Width / XO
sfx_volume:        .word 0      ; Current volume (16-bit)
sfx_vol_change:    .word 0      ; Volume change per frame during release
sfx_freq_change:   .word 0      ; Frequency change per frame during release

; Sound effect definitions (10 bytes each)
sfx_sounds:
; Format--    release count, freq low, freq high, waveform, vol low, vol high, vol change low, vol change high, freq change low, freq change high
;0 ping
sfx_ping:       .byte 100  , 199      , 9       ,%10100000 , 0      , 63       , 161           , 0             , 0              , 0

;10 shoot
sfx_shoot:      .byte 20   , 107      , 17      ,%11100000 , 0      , 63       , 0             , 3             , 0              , 0

;20 zap 
sfx_zap:        .byte 37   , 232      , 10      ,%01100000 , 0      , 63       , 179           , 1             , 100            , 0

;30 explosion sound 
sfx_explode:    .byte 200  , 125      , 5       ,%11100000 , 0      , 63       , 80            , 0             , 0              , 0

; 40 Jump sound - rising tone with quick decay
sfx_squee_up:   .byte 15   , 125      , 6       ,%10100000 , 0      , 63       , 120           , 2             , 250            , 255

; 50 Coin/pickup sound - high ping with slight warble
sfx_squee_down: .byte 25   , 250      , 10      ,%00100000 , 0      , 63       , 100           , 2             , 10             , 0

; 60 Powerup sound - ascending tone pattern
sfx_jump:       .byte 60   , 100      , 5       ,%01100000 , 0      , 63       , 40            , 1             , 230            , 255

; 70 Hit/damage sound - harsh noise with quick decay
sfx_smallboom:  .byte 15   , 200      , 7       ,%11100000 , 0      , 63       , 150           , 4             , 0              , 0

; 80 Menu navigate sound - subtle click
sfx_menu:       .byte 5    , 220      , 8       ,%10100000 , 0      , 40       , 200           , 8             , 0              , 0

; 90 Door open/close - low frequency sweep
sfx_smallbounce:.byte 40   , 60       , 3       ,%01100000 , 0      , 63       , 60            , 1             , 10             , 0

; 100 Alarm/warning - alternating tones
sfx_sparkle:    .byte 120  , 150      , 8       ,%10100000 , 0      , 63       , 20            , 0             , 100            , 254

; 110 Game over - descending tone with long release
sfx_gameover:   .byte 100  , 200      , 12      ,%01100000 , 0      , 63       , 25            , 0             , 50             , 0

; 120 Landing/thud - low frequency with quick decay
sfx_land:       .byte 10   , 80       , 2       ,%11100000 , 0      , 63       , 180           , 6             , 0              , 0

; 130 Bounce - quick up-down tone
sfx_gasup:      .byte 20   , 150      , 7       ,%10100000 , 0      , 63       , 100           , 3             , 0              , 0

; 140 - Blaster - short punchy laser blast with quick decay
sfx_blaster:    .byte 12   , 230      , 12      ,%11100000 , 0      , 63       , 160           , 5             , 180            , 0

; 150 - Laser Beam - higher pitched sustained laser with descending tail
sfx_laser:      .byte 30   , 250      , 15      ,%01100000 , 0      , 63       , 60            , 2             , 200            , 0  

; 160 - Photon Torpedo - deeper whoosh with wobble effect
sfx_photon:     .byte 35   , 150      , 8       ,%10100000 , 0      , 63       , 50            , 1             , 50             , 0

; 170 - Plasma Rifle - high energy electric sounding discharge
sfx_plasma:     .byte 15   , 230      , 20      ,%11100000 , 0      , 63       , 120           , 4             , 220            , 0

; Storage for VERA register state
sfx_data_store: .res 4, 0

; ======================================================================
; Sound Functions
; ======================================================================
play_sfx_ping:
    ldx #0                  ; Offset to ping sound envelope
    jmp common_sfx_play 
play_sfx_shoot:
    ldx #10                 ; Offset to shoot sound envelope
    jmp common_sfx_play 
play_sfx_zap:
    ldx #20                 ; Offset to zap sound envelope
    jmp common_sfx_play 
play_sfx_explode:
    ldx #30                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_squee_up:
    ldx #40                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_squee_down:
    ldx #50                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_jump:
    ldx #60                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_smallboom:
    ldx #70                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_menu:
    ldx #80                 ; Offset to zap sound envelope
    jmp common_sfx_play 
; Play the 'explode' sound effect
play_sfx_smallbounce:
    ldx #90                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_sparkle:
    ldx #100                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_gameover:
    ldx #110                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_land:
    ldx #120                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_gasup:
    ldx #130                ; Offset to test sound 
    jmp common_sfx_play 
play_sfx_blaster:
    ldx #140                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_laser:
    ldx #150                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_photon:
    ldx #160                 ; Offset to explode sound envelope
    jmp common_sfx_play 
play_sfx_plasma:
    ldx #170                 ; Offset to explode sound envelope

    ; Fall through to common

; Common sound effect initialization
common_sfx_play:
    ldy #0                  ; Copy sound parameters
@copy_loop:
    lda sfx_sounds , x      ; Get parameter from sound table
    sta sfx_channel , y     ; Store in our parameter block
    inx 
    iny 
    cpy #10                 ; Copy all 10 bytes
    bne @copy_loop

    lda #255                ; Start playing (phase = start)
    sta sfx_phase 

    lda sfx_running         ; Is the sound system already running?
    bne @return             ; If yes, just return (IRQ handler already set up)
    
    lda #1                  ; Mark sound system as running
    sta sfx_running

@return:
    rts 


; ======================================================================
; IRQ Handler for Sound Playback
; ======================================================================
soundfx_play_irq:
    
    ; Save VERA registers
    lda VERA_ADDR_LOW 
    sta sfx_data_store
    lda VERA_ADDR_HIGH 
    sta sfx_data_store + 1
    lda VERA_ADDR_BANK
    sta sfx_data_store + 2
    lda VERA_CTRL
    sta sfx_data_store + 3

    ; Process based on current phase
    lda sfx_phase 
    beq @done_irq               ; If phase = 0, nothing to do
    
    cmp #1
    beq @release              ; If phase = 1, handle release phase
    
    ; Otherwise phase = 255 (start playing)
    lda #1                    ; Switch to release phase
    sta sfx_phase
    
    ; Set up VERA address to PSG channel 15
    stz VERA_CTRL             ; Select data port 0
    lda #((^PSG_CHANNEL) | $10)  ; Bank with auto-increment
    sta VERA_ADDR_BANK 
    lda #>PSG_CHANNEL         ; High byte
    sta VERA_ADDR_HIGH 
    lda #<PSG_CHANNEL         ; Low byte
    sta VERA_ADDR_LOW 
    
    ; Set initial sound parameters
    lda sfx_frequency         ; Set frequency (low byte)
    sta VERA_DATA0 
    lda sfx_frequency + 1     ; Set frequency (high byte)
    sta VERA_DATA0 
    lda sfx_volume + 1        ; Set volume with left and right enabled
    ora #%11000000
    sta VERA_DATA0 
    lda sfx_waveform          ; Set waveform
    sta VERA_DATA0 
@done_irq:  
    jmp @exit

@release:
    ; Check if release phase is complete
    lda sfx_release_count
    bne @continue_release      ; If not zero, continue release
    
    ; Release complete, turn off sound
    stz VERA_CTRL              ; Select data port 0
    lda #((^PSG_VOLUME) | $00) ; Bank without auto-increment
    sta VERA_ADDR_BANK 
    lda #>PSG_VOLUME           ; High byte
    sta VERA_ADDR_HIGH 
    lda #<PSG_VOLUME           ; Low byte
    sta VERA_ADDR_LOW 
    
    stz VERA_DATA0             ; Set volume to 0
    stz sfx_phase              ; Mark as not playing
    jmp @exit

@continue_release:
    ; Update volume (16-bit subtraction)
    sec 
    lda sfx_volume 
    sbc sfx_vol_change 
    sta sfx_volume 
    lda sfx_volume + 1 
    sbc sfx_vol_change + 1
    sta sfx_volume + 1
    
    ; Update frequency (16-bit subtraction)
    sec 
    lda sfx_frequency 
    sbc sfx_freq_change 
    sta sfx_frequency 
    lda sfx_frequency + 1
    sbc sfx_freq_change + 1
    sta sfx_frequency + 1
    
    ; Update PSG channel
    stz VERA_CTRL              ; Select data port 0
    lda #((^PSG_CHANNEL) | $10) ; Bank with auto-increment
    sta VERA_ADDR_BANK 
    lda #>PSG_CHANNEL          ; High byte
    sta VERA_ADDR_HIGH 
    lda #<PSG_CHANNEL          ; Low byte
    sta VERA_ADDR_LOW 
    
    ; Write updated values
    lda sfx_frequency          ; Set frequency (low byte)
    sta VERA_DATA0
    lda sfx_frequency + 1      ; Set frequency (high byte)
    sta VERA_DATA0
    lda sfx_volume + 1         ; Set volume with left and right enabled
    ora #%11000000
    sta VERA_DATA0
    
    ; Decrement release counter
    dec sfx_release_count

@exit:
    ; Restore VERA registers
    lda sfx_data_store
    sta VERA_ADDR_LOW 
    lda sfx_data_store + 1
    sta VERA_ADDR_HIGH 
    lda sfx_data_store + 2
    sta VERA_ADDR_BANK 
    lda sfx_data_store + 3
    sta VERA_CTRL
    
    rts 

.endif
