# 03 — Gameplay Loops

Source: `enemy.asm`, `projectiles.asm`, `collision.asm`, `effects.asm`.

## Enemy update dispatch (`enemy_update_loop`)

```mermaid
flowchart TD
    L["X = 0"] --> LOOP{"enemies_state,X\n& ENEMY_ACTIVE_MASK"}
    LOOP -->|0| SKIP["inx"]
    LOOP -->|set| IDX["enemy_index = X"]
    IDX --> GP["get_sprite_position\nVERA read -> enemy_x/y_pos scalars"]
    GP --> PAT["get_enemy_pattern (0-7)"]
    PAT --> TBL["pattern_functions,Y\n-> pattern_vector"]
    TBL --> RUN["run_pattern: jmp (pattern_vector)"]
    RUN --> PATF["pattern_straight_down\nread y, add enemy_speed_y,X\ncheck_enemy_offscreen"]
    PATF --> SP["set_sprite_position\nVERA write-back"]
    SP --> SKIP
    SKIP --> CMP{"X == MAX_ENEMIES?"}
    CMP -->|no| LOOP
    CMP -->|yes| RTS["rts"]
```

### Pattern contract

- `.X` = enemy index and **must be preserved**; read/write the `enemy_x/y_pos`
  scalars (not per-enemy arrays — those are scalars in the current build).
- Patterns must **not** touch VERA; the loop does the single write-back.
- `run_pattern` is `jmp (pattern_vector)`; the caller's `jsr run_pattern` leaves
  the return address so the pattern's `rts` lands correctly (no
  self-modifying code needed).
- `pattern_functions` has 8 `.word` entries (pattern ID is 3 bits). Only entry 0
  (`pattern_straight_down`) is implemented; 1-7 alias it as placeholders.
- Patterns may call `check_enemy_offscreen` / `deactivate_enemy` (both live in
  `enemy.asm`). `check_enemy_offscreen` culls **vertically only**.
- `activate_enemy` sets the active bit, resets `enemy_hp`, and clears all
  pattern state. **Any new spawn path must set the active bit** or collision
  will skip the enemy.

## Projectile lifecycle (`projectiles.asm`)

```mermaid
flowchart TD
    F["fire_projectile"] --> FS["@find_slot\n(proj_states = 0)"]
    FS --> NS{"slot free?"}
    NS -->|no| FAIL["@no_slots -> rts"]
    NS -->|yes| SET["set pos from player\nset dir_x / dir_y\nset lifetime + type"]
    SET --> CD["weapon cooldown\n(rapid / spread / power)"]
    CD --> SND["play_sfx_shoot / blaster / laser / photon / plasma"]
    SND --> US["update_projectile_sprite"]

    U["update_projectiles"] --> UL["for each proj slot"]
    UL --> UA{"proj_states = 1?"}
    UA -->|no| UN["next"]
    UA -->|yes| UM["update_projectile_pos\n(uses direction_x/y_table)"]
    UM --> UB["check_projectile_bounds\ncull off-screen"]
    UB --> US2["update_projectile_sprite"]
    US2 --> UN
```

- Pool: `PROJ_MAX_COUNT` slots with `proj_states`, `proj_x/y_pos_l/h`,
  `proj_dir_x/y`, `proj_lifetime`, `proj_type`.
- `proj_cooldown` is a single global cooldown shared by all weapons.
- Known TODO in the current build: `update_projectile_sprite` hardcodes
  `lda #5` for the frame and `lda #0` for direction.

## Collision pipeline (`collision.asm`)

```mermaid
flowchart TD
    CO["update_collisions\n(proj vs enemy)"] --> CE["@enemy_loop\nstore col_enemy FIRST"]
    CE --> CA{"enemy active?"}
    CA -->|no| NE["next enemy"]
    CA -->|yes| CP["@proj_loop / col_proj"]
    CP --> PA{"proj active?"}
    PA -->|no| NP["next proj"]
    PA -->|yes| DX["abs_dx / col_dx"]
    DX --> DY["abs_dy / col_dy"]
    DY --> HIT{"within AABB threshold?"}
    HIT -->|no| NP
    HIT -->|yes| PHE["projectile_hit_enemy\n- dec enemy_hp\n- if 0: spawn_explosion,\ndeactivate_enemy, play_sfx_explode"]
    PHE --> NP

    PC["update_player_enemy_collisions"] --> PS["scan each enemy\nstore col_enemy FIRST"]
    PS --> PH{"hit?"}
    PH -->|yes| PHIT["player_hit\n- explosion + deactivate enemy\n- dec player_lives\n- player_invuln = PLAYER_INVULN_FRAMES"]
    PHIT --> GO{"lives == 0?"}
    GO -->|yes| OV["@game_over:\nplay_sfx_gameover\nrequest_state_change(START_SCREEN)"]
    GO -->|no| DONE["done"]
    PH -->|no| DONE
```

- Geometry: sprite coords are **top-left corners**. 8x8 player projectile
  (half 4) vs 16x16 enemy (half 8) -> centre test biases the delta by
  `ENEMY_HALF - PROJ_HALF = 4` before `abs_dx`/`abs_dy`.
- The ship hitbox is a small centred core: `PLAYER_HIT_HALF = 3` (6x6),
  `PLAYER_HIT_THRESH = 3 + 8 = 11`, biased by 5.
- While `player_invuln != 0`, `update_player_enemy_collisions` decrements it and
  **returns** — enemies pass through and no life is lost.
- **`col_enemy` must be stored at the top of the loop, before the active-mask
  skip.** Storing it after the skip makes the loop reload a stale index and spin
  forever inside the IRQ (total freeze).
- Relative branches only reach +/-128 bytes here; use a nearby `beq`/`bne`
  trampoline then `jmp` for far targets.

## Explosions (`effects.asm`)

```mermaid
flowchart TD
    I["init_explosions\n(called by gameplay_init)"] --> C["clear all EXPL_MAX slots"]
    S["spawn_explosion\n(called on enemy kill)"] --> F["@find free slot"]
    F --> OK{"free?"}
    OK -->|no| R1["rts"]
    OK -->|yes| W["copy enemy_x/y_pos scalars\nset frame 0 + EXPL_FRAME_TIME"]
    U["update_explosions"] --> LO["for each active slot"]
    LO --> T["decrement expl_timer"]
    T --> ADV{"timer == 0?"}
    ADV -->|yes| NX["advance explosion_frames index"]
    NX --> END{"past last frame?"}
    END -->|yes| KILL["@kill: free slot,\ndisable_explosion_sprite"]
    END -->|no| D["@draw: draw_explosion"]
    ADV -->|no| D
```

- 5 slots at `sp_att_effects = $1FF88` (ends at `$1FFB0` = `sp_att_ui`).
- Uses big-sprite frames `$0F`/`$10` ("FlameSprites" in `sprites.bin`).
- `spawn_explosion` reads the `enemy_x/y_pos` scalars — call it while they still
  hold the dead enemy's position (order matters; see `02-irq-and-tick.md`).
- Tuning knobs: `EXPL_FRAME_TIME`, `explosion_frames`, `EXPL_MAX`.
