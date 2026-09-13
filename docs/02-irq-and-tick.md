# 02 — IRQ, Tick Dispatch & Frame Order

Source: `game.asm` (`custom_irq_handler`, `irq_scanline_handler`,
`game_tick_loop`, `@handle_ingame_tick`).

## IRQ routing

```mermaid
flowchart TD
    IRQ["custom_irq_handler\n(game.asm)"] --> CHK{"VERA_ISR\nbit 1 (scanline)?"}
    CHK -->|yes| SL["irq_scanline_handler"]
    SL --> BANK["RAM_BANK = ZSMKIT_BANK"]
    BANK --> ZT["zsm_tick (music)"]
    ZT --> SFX["soundfx_play_irq\n(PSG ch15 envelope)"]
    SFX --> RTI["ply/plx/pla/rti"]

    CHK -->|no| VSYNC{"VERA_ISR\nbit 0 (vsync)?"}
    VSYNC -->|yes| GTL["game_tick_loop\n@60Hz"]
    VSYNC -->|no| DEF
    GTL --> DEF["jmp (default_irq_vector)\n-> KERNAL IRQ -> RTI"]
```

## `game_tick_loop` — state dispatch

```mermaid
flowchart TD
    START["game_tick_loop"] --> R1["stz has_state_changed\ninc frame_num"]
    R1 --> HST["handle_state_transitions"]
    HST --> CHG{"has_state_changed?"}
    CHG -->|yes| DONE["rts (skip rest of frame)"]
    CHG -->|no| F60{"frame_num == 60?"}
    F60 -->|yes| RST["frame_num = 0"]
    F60 -->|no| DISP
    RST --> DISP{"game_state?"}

    DISP -->|START_SCREEN| A["check_start_menu_input\nupdate_player_sprite"]
    DISP -->|IN_GAME| B["@handle_ingame_tick"]
    DISP -->|PAUSED| C["check_pause_input"]
```

`has_state_changed` short-circuits the frame entirely. A state transition takes
`state_trans_delay` frames (see `04-state-machine.md`), so "one frame did
nothing" right after a menu press is expected.

## In-game tick order (order is significant)

```mermaid
flowchart TD
    B["@handle_ingame_tick"] --> I1["process_game_input\n(input.asm)"]
    I1 --> MV{"player_xy_state == 0?"}
    MV -->|no| MP["movePlayer_tick\n-> check_boundaries"]
    MV -->|yes| PS
    MP --> PS["update_player_sprite"]
    PS --> PR["update_projectiles\n(projectiles.asm)"]
    PR --> EN["enemy_update_loop\n(enemy.asm)"]
    EN --> CO["update_collisions\nprojectile vs enemy"]
    CO --> PC["update_player_enemy_collisions\nship vs enemy"]
    PC --> BL["update_player_blink\n(Z byte only)"]
    BL --> EX["update_explosions\n(effects.asm)"]
    EX --> RTS["rts"]
```

### Why the order matters

- `process_game_input` runs first so a fire press is consumed by
  `fire_projectile` before projectiles are moved/rendered this frame.
- `spawn_explosion` (called from `update_collisions`) reads the `enemy_x/y_pos`
  scalars, so it must run while they still hold the dead enemy's position.
- `update_player_blink` writes **only** the player sprite's Z byte
  (`sp_att_player + 6`). Do not duplicate that logic in `update_player_sprite`.
- `update_explosions` runs last so a freshly spawned explosion is drawn on its
  first frame.

## Debug hooks

| Check | Where |
|---|---|
| Stuck / total freeze | `custom_irq_handler` — CPU spinning inside the IRQ (see README gotchas) |
| No music or SFX | `irq_scanline_handler` — bank select, `zsm_tick`, `soundfx_play_irq` |
| Player won't move | `process_game_input` sets `player_xy_state`; `movePlayer_tick` consumes it |
| Player leaves screen | `check_boundaries` (called from `movePlayer_tick`) |
