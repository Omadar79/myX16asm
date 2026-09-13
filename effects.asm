; ===================================================================
; File:         effects.asm
; Description:  Transient visual effects (explosions) using the free
;               sprite-attribute block at $1FF88 (5 slots).
;
; Uses big-sprite frames $0F/$10 ("FlameSprites" in sprites.bin) which
; are red/orange/yellow with palette offset 0.
;
; NOTE: relies on enemy_x/y_pos and get_sprite_frame_addr, so include
;       this AFTER enemy.asm / sprite.asm in game.asm.
; ===================================================================
.ifndef _EFFECTS_ASM
_EFFECTS_ASM = 1

.include "x16.inc"
.include "macros.inc"
.include "globals.asm"
.include "sprite.asm"

EXPL_MAX        = 5                 ; matches the 5 free sprite slots at $1FF88
EXPL_FRAME_TIME = 3                 ; ticks to hold each animation frame
EXPL_END        = $FF               ; animation terminator

; Animation: burst -> fireball -> hold -> flare -> fade
explosion_frames:
    .byte $0F, $10, $10, $0F, $10, EXPL_END

; Per-slot state
expl_state:     .res EXPL_MAX, 0    ; 0 = free, 1 = active
expl_frame:     .res EXPL_MAX, 0    ; index into explosion_frames
expl_timer:     .res EXPL_MAX, 0    ; ticks left on the current frame
expl_x_l:       .res EXPL_MAX, 0
expl_x_h:       .res EXPL_MAX, 0
expl_y_l:       .res EXPL_MAX, 0
expl_y_h:       .res EXPL_MAX, 0

; ===================================================================
; init_explosions - free every slot and hide its sprite
; ===================================================================
init_explosions:
    ldx #0
@clear:
    stz expl_state, x
    jsr disable_explosion_sprite
    inx
    cpx #EXPL_MAX
    bne @clear
    rts

; ===================================================================
; spawn_explosion - start an effect at the enemy position currently
;                   held in enemy_x_pos_l/h, enemy_y_pos_l/h
;                   (update_collisions loads those before calling)
; ===================================================================
spawn_explosion:
    ldx #0
@find:
    lda expl_state, x
    beq @found
    inx
    cpx #EXPL_MAX
    bne @find
    rts                             ; no free slot -> drop the effect
@found:
    lda #1
    sta expl_state, x
    lda enemy_x_pos_l
    sta expl_x_l, x
    lda enemy_x_pos_h
    sta expl_x_h, x
    lda enemy_y_pos_l
    sta expl_y_l, x
    lda enemy_y_pos_h
    sta expl_y_h, x
    stz expl_frame, x
    lda #EXPL_FRAME_TIME
    sta expl_timer, x
    rts

; ===================================================================
; update_explosions - call once per gameplay tick
; ===================================================================
update_explosions:
    ldx #0
@loop:
    lda expl_state, x
    beq @next

    dec expl_timer, x
    bne @draw                       ; still holding the current frame

    ; timer expired -> advance the animation
    inc expl_frame, x
    ldy expl_frame, x
    lda explosion_frames, y
    cmp #EXPL_END
    beq @kill
    lda #EXPL_FRAME_TIME
    sta expl_timer, x

@draw:
    jsr draw_explosion
    bra @next

@kill:
    stz expl_state, x
    jsr disable_explosion_sprite

@next:
    inx
    cpx #EXPL_MAX
    bne @loop
    rts

; ===================================================================
; draw_explosion - write this slot's sprite attributes
;   in: X = slot index
; ===================================================================
draw_explosion:
    lda expl_frame, x
    tay
    lda explosion_frames, y
    jsr get_sprite_frame_addr       ; -> ZP_PTR_1 (frame address)

    MACRO_VERA_SET_ADDR sp_att_effects, 1
    lda ZP_PTR_1
    sta VERA_DATA0
    lda ZP_PTR_1 + 1
    sta VERA_DATA0
    lda expl_x_l, x
    sta VERA_DATA0
    lda expl_x_h, x
    sta VERA_DATA0
    lda expl_y_l, x
    sta VERA_DATA0
    lda expl_y_h, x
    sta VERA_DATA0
    lda #%00001100                  ; z-depth 3 (in front of layer 1)
    sta VERA_DATA0
    lda #%01010000                  ; 16x16, palette offset 0 = red/orange/yellow
    sta VERA_DATA0
    rts

; ===================================================================
; disable_explosion_sprite - zero the Z-depth byte (hides the sprite)
;   in: X = slot index
; ===================================================================
disable_explosion_sprite:
    txa
    asl
    asl
    asl
    clc
    adc #<sp_att_effects
    sta ZP_PTR_3
    lda #>sp_att_effects
    adc #0
    sta ZP_PTR_3+1

    lda ZP_PTR_3+1
    sta VERA_ADDR_HIGH              ; A8-A15
    lda ZP_PTR_3
    clc
    adc #6                          ; Z-depth byte
    sta VERA_ADDR_LOW
    lda #%00010001                  ; auto-inc 1, bank 1
    sta VERA_ADDR_BANK
    stz VERA_DATA0
    rts

.endif
