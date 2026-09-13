; ===================================================================
; File:         collision.asm
; Description:  Player projectile vs enemy AABB collision
; NOTE: relies on symbols from enemy.asm / projectiles.asm / soundfx.asm,
;       so it must be .include'd AFTER those in game.asm
; ===================================================================
.ifndef _COLLISION_ASM
_COLLISION_ASM = 1

; Assumes already defined: enemies_state, ENEMY_ACTIVE_MASK, MAX_ENEMIES,
; enemy_x_pos_l/h, enemy_y_pos_l/h, get_sprite_position, deactivate_enemy,
; proj_states, PROJ_MAX_COUNT, PROJ_INACTIVE, proj_x_pos_l/h, proj_y_pos_l/h,
; disable_projectile_sprite, play_sfx_explode

PROJ_HALF   = 4                     ; 8x8 sprite
ENEMY_HALF  = 8                     ; 16x16 sprite
HIT_THRESH  = PROJ_HALF + ENEMY_HALF ; 12 = max centre-to-centre distance for a hit

; The player ship uses a small centred core hitbox so near-misses feel fair
PLAYER_HIT_HALF   = 3               ; 6x6 core (the ship sprite is 16x16)
PLAYER_HIT_THRESH = PLAYER_HIT_HALF + ENEMY_HALF ; 11 = max centre distance for a hit

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
    jsr deactivate_enemy            ; shared routine in enemy.asm
    sec                             ; carry set = enemy destroyed
    rts
@survived:
    clc                             ; carry clear = enemy survived
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

; ===================================================================
; update_player_enemy_collisions - player ship vs enemy AABB
;   Uses a small centred core hitbox for the ship. On contact the enemy
;   is destroyed, the player loses a life and gains brief invulnerability.
;   Call once per gameplay tick, after update_collisions.
; ===================================================================
update_player_enemy_collisions:
    lda player_invuln
    beq @scan
    dec player_invuln               ; tick down the invulnerability window
    rts                             ; still invulnerable -> enemies pass through

@scan:
    ldx #0
@enemy_loop:
    stx col_enemy                   ; MUST be before the skip: @next_enemy reloads it
    lda enemies_state, x
    and #ENEMY_ACTIVE_MASK
    beq @next_enemy

    jsr get_sprite_position         ; X -> enemy_x/y_pos scalars (X preserved)

    ; ---- dx = |(player_x - enemy_x) - (ENEMY_HALF - PLAYER_HIT_HALF)| ----
    lda player_sprite_x_l
    sec
    sbc enemy_x_pos_l
    sta col_dx
    lda player_sprite_x_h
    sbc enemy_x_pos_h
    sta col_dx+1
    lda col_dx                      ; bias: both coords are top-left corners
    sec
    sbc #(ENEMY_HALF - PLAYER_HIT_HALF)
    sta col_dx
    lda col_dx+1
    sbc #0
    sta col_dx+1
    jsr abs_dx

    lda col_dx+1
    bne @next_enemy                  ; >= 256 apart, impossible
    lda col_dx
    cmp #PLAYER_HIT_THRESH
    bcs @next_enemy

    ; ---- dy = |(player_y - enemy_y) - (ENEMY_HALF - PLAYER_HIT_HALF)| ----
    lda player_sprite_y_l
    sec
    sbc enemy_y_pos_l
    sta col_dy
    lda player_sprite_y_h
    sbc enemy_y_pos_h
    sta col_dy+1
    lda col_dy
    sec
    sbc #(ENEMY_HALF - PLAYER_HIT_HALF)
    sta col_dy
    lda col_dy+1
    sbc #0
    sta col_dy+1
    jsr abs_dy

    lda col_dy+1
    bne @next_enemy
    lda col_dy
    cmp #PLAYER_HIT_THRESH
    bcs @next_enemy

    ; ---------------- the ship was hit ----------------
    ldx col_enemy
    jsr player_hit
    rts                             ; one hit per frame is plenty

@next_enemy:
    ldx col_enemy
    inx
    cpx #MAX_ENEMIES
    beq @player_col_done
    jmp @enemy_loop                 ; jmp: branch target is out of range
@player_col_done:
    rts

; ===================================================================
; player_hit - lose a life, destroy the colliding enemy, start invuln
; Input: X = enemy index that hit the player
; ===================================================================
player_hit:
    ; blow up the enemy that hit us
    stx col_enemy
    jsr spawn_explosion             ; effect at enemy_x/y_pos (clobbers X)
    ldx col_enemy
    jsr deactivate_enemy

    ; ...and a burst on the ship itself (reuses the enemy position scalars)
    lda player_sprite_x_l
    sta enemy_x_pos_l
    lda player_sprite_x_h
    sta enemy_x_pos_h
    lda player_sprite_y_l
    sta enemy_y_pos_l
    lda player_sprite_y_h
    sta enemy_y_pos_h
    jsr spawn_explosion

    jsr play_sfx_explode            ; clobbers X and Y

    dec player_lives
    beq @game_over

    lda #PLAYER_INVULN_FRAMES
    sta player_invuln
    rts

@game_over:
    lda #PLAYER_START_LIVES         ; ready for the next game
    sta player_lives
    stz player_invuln
    jsr play_sfx_gameover
    lda #GAME_STATE_START_SCREEN    ; back to the title screen
    jsr request_state_change
    rts

; ===================================================================
; player_reset - fresh lives and no invulnerability (start of a game)
; ===================================================================
player_reset:
    lda #PLAYER_START_LIVES
    sta player_lives
    stz player_invuln
    rts

; ===================================================================
; update_player_blink - during respawn invulnerability, blink the ship
;   by toggling only its sprite Z-depth byte (no new art needed).
;   Call once per tick; a no-op when the player is not invulnerable.
; ===================================================================
update_player_blink:
    lda player_invuln
    beq @visible
    and #%00000100                  ; toggles every 4 frames
    beq @hidden
@visible:
    lda #%00001100                  ; z-depth 3, in front of layer 1
    bra @write
@hidden:
    lda #0                          ; z-depth 0 = sprite disabled
@write:
    pha 
    MACRO_VERA_SET_ADDR (sp_att_player + 6), 1
    pla 
    sta VERA_DATA0
    rts 

.endif