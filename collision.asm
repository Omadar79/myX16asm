; ===================================================================
; File:         collision.asm
; Description:  Player projectile vs enemy AABB collision
; NOTE: relies on symbols from enemy.asm / projectiles.asm / soundfx.asm,
;       so it must be .include'd AFTER those in game.asm
; ===================================================================
.ifndef _COLLISION_ASM
_COLLISION_ASM = 1

; Assumes already defined: enemies_state, ENEMY_ACTIVE_MASK, MAX_ENEMIES,
; enemy_x_pos_l/h, enemy_y_pos_l/h, get_sprite_position,
; proj_states, PROJ_MAX_COUNT, PROJ_INACTIVE, proj_x_pos_l/h, proj_y_pos_l/h,
; disable_projectile_sprite, sp_att_enemy, play_sfx_explode

PROJ_HALF   = 4                     ; 8x8 sprite
ENEMY_HALF  = 8                     ; 16x16 sprite
HIT_THRESH  = PROJ_HALF + ENEMY_HALF ; 12 = max centre-to-centre distance for a hit

; Optional: multi-hit enemies (1 = dies on first hit).
; In the CODE segment, so it loads as 1s. Reset it in activate_enemy.
enemy_hp:   .res MAX_ENEMIES, 1

; Module scratch
col_enemy:  .byte 0
col_proj:   .byte 0
col_dx:     .word 0
col_dy:     .word 0

; ===================================================================
; update_collisions - call once per gameplay tick, after
;                     update_projectiles and enemy_update_loop
; ===================================================================
update_collisions:
    ldx #0
@enemy_loop:
    stx col_enemy                   ; always valid, even if inactive
    lda enemies_state, x
    and #ENEMY_ACTIVE_MASK
    bne @enemy_active
    jmp @next_enemy                 ; jmp: branch target is out of range
@enemy_active:
    jsr get_sprite_position         ; X=index -> enemy_x/y_pos scalars (X preserved)

    ldy #0                          ; projectile index
@proj_loop:
    lda proj_states, y
    beq @next_proj                  ; slot empty

    ; ---- dx = |proj_centre_x - enemy_centre_x| ----
    lda proj_x_pos_l, y
    sec
    sbc enemy_x_pos_l
    sta col_dx
    lda proj_x_pos_h, y
    sbc enemy_x_pos_h
    sta col_dx+1
    ; stored coords are top-left corners; bias by the half-width difference
    ; so we compare centres (enemy centre sits ENEMY_HALF - PROJ_HALF further)
    lda col_dx
    sec
    sbc #(ENEMY_HALF - PROJ_HALF)
    sta col_dx
    lda col_dx+1
    sbc #0
    sta col_dx+1
    jsr abs_dx

    lda col_dx+1
    bne @next_proj                  ; dx >= 256, impossible
    lda col_dx
    cmp #HIT_THRESH
    bcs @next_proj                  ; dx >= 12

    ; ---- dy = |proj_centre_y - enemy_centre_y| ----
    lda proj_y_pos_l, y
    sec
    sbc enemy_y_pos_l
    sta col_dy
    lda proj_y_pos_h, y
    sbc enemy_y_pos_h
    sta col_dy+1
    ; same top-left -> centre bias as the X axis
    lda col_dy
    sec
    sbc #(ENEMY_HALF - PROJ_HALF)
    sta col_dy
    lda col_dy+1
    sbc #0
    sta col_dy+1
    jsr abs_dy

    lda col_dy+1
    bne @next_proj
    lda col_dy
    cmp #HIT_THRESH
    bcs @next_proj                  ; dy >= 12

    ; ---------------- HIT ----------------
    sty col_proj                    ; sfx/disables clobber X and Y
    jsr projectile_hit_enemy
    bcs @next_enemy                 ; enemy destroyed -> stop scanning it
    ldy col_proj

@next_proj:
    iny
    cpy #PROJ_MAX_COUNT
    beq @proj_done
    jmp @proj_loop                  ; jmp: branch target is out of range
@proj_done:

@next_enemy:
    ldx col_enemy
    inx
    cpx #MAX_ENEMIES
    beq @collisions_done
    jmp @enemy_loop                 ; jmp: branch target is out of range
@collisions_done:
    rts

; ===================================================================
; projectile_hit_enemy
;   in: col_proj  = projectile index
;       col_enemy = enemy index
; ===================================================================
projectile_hit_enemy:
    ; kill the projectile
    ldx col_proj
    lda #PROJ_INACTIVE
    sta proj_states, x
    jsr disable_projectile_sprite

    jsr play_sfx_explode            ; clobbers X and Y

    ; damage the enemy
    ldx col_enemy
    dec enemy_hp, x
    bne @survived
    jsr spawn_explosion             ; effect at enemy_x/y_pos (clobbers X)
    ldx col_enemy
    jsr enemy_deactivate
    sec                             ; carry set = enemy destroyed
    rts
@survived:
    clc                             ; carry clear = enemy survived
    rts

; ===================================================================
; enemy_deactivate - X = enemy index
;   stands in for the commented-out deactivate_enemy in enemy.asm
; ===================================================================
enemy_deactivate:
    lda enemies_state, x
    and #%11111110                  ; clear ENEMY_ACTIVE_MASK
    sta enemies_state, x
    jsr hide_enemy_sprite
    rts

; X = enemy index -> zero sprite Z-depth byte (hides it)
hide_enemy_sprite:
    txa
    asl
    asl
    asl
    clc
    adc #<sp_att_enemy
    sta ZP_PTR_3
    lda #>sp_att_enemy
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

; ===================================================================
; abs_dx / abs_dy - two's-complement negate if the diff went negative
; ===================================================================
abs_dx:
    lda col_dx+1
    bpl @done
    sec
    lda #0
    sbc col_dx
    sta col_dx
    lda #0
    sbc col_dx+1
    sta col_dx+1
@done:
    rts

abs_dy:
    lda col_dy+1
    bpl @done
    sec
    lda #0
    sbc col_dy
    sta col_dy
    lda #0
    sbc col_dy+1
    sta col_dy+1
@done:
    rts

.endif