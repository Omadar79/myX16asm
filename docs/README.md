# Nebula Squadron — Debug Flow Docs

Flowcharts of the call graph and file responsibilities, generated from the actual
source in `game.asm` and its includes. Intended for debugging: find the routine
that owns a symptom, then trace its diagram.

## How to read these

`game.asm` owns **every** `.include`, so the diagrams follow the real link order.
`.include` order matters because `globals.asm`/`x16.inc` define symbols used by
later files.

Include order (from `game.asm`):

```
x16.inc -> macros.inc -> loadfiledata.asm -> globals.asm -> sprite.asm ->
input.asm -> projectiles.asm -> soundfx.asm -> music.asm -> enemy.asm ->
collision.asm -> effects.asm
; enemypatterns.asm is present but COMMENTED OUT (draft, does not compile)
```

## Diagrams

| Doc | Covers |
|---|---|
| [01-boot-and-init.md](01-boot-and-init.md) | Reset vector, `start_game` asset loads, `init_irq` |
| [02-irq-and-tick.md](02-irq-and-tick.md) | `custom_irq_handler`, scanline IRQ, `game_tick_loop`, in-game tick order |
| [03-gameplay-loops.md](03-gameplay-loops.md) | Enemy dispatch, projectile lifecycle, collisions, explosions |
| [04-state-machine.md](04-state-machine.md) | `request_state_change` / `handle_state_transitions` / `init_new_state` |
| [05-file-map.md](05-file-map.md) | Which file owns which routine |

## Debug quick-reference: symptom -> first place to look

| Symptom | Start here |
|---|---|
| Nothing runs at all / frozen input + audio | `custom_irq_handler` -> CPU stuck in IRQ (see loop-index gotcha below) |
| Music/sound stutters or dies | `irq_scanline_handler` -> `ZSMKIT_BANK` select, `zsm_tick`, `soundfx_play_irq` |
| One frame skipped after a menu action | `has_state_changed` / `state_trans_delay` in `handle_state_transitions` |
| Title screen garbage sprites | `startscreen_init` -> `clear_all_sprites`, `player_invuln` |
| Pause text wraps / background corrupted | `pause_init` clear loop count (`ldx #8` = 4096 bytes) and 64-wide map |
| Enemies don't move or never die | `enemy_update_loop` active-mask check, then `pattern_functions` table |
| Bullets pass through enemies | `update_collisions` -> `projectile_hit_enemy`, `abs_dx` / `abs_dy` thresholds |
| Ship takes no damage / instant game over | `update_player_enemy_collisions` -> `player_invuln`, `player_hit` |
| Sprites at wrong place | `get_sprite_position` / `set_sprite_position` (coords are **top-left corners**) |
| Assets garbled or missing | `loadfiledata.asm` filenames + `loadtovram` args |

## Gotchas worth pinning next to these diagrams

- **Loop counters must be stored before the active-mask skip.** A stale index
  reloads and spins forever inside the vsync IRQ, freezing input, sound and
  animation all at once. (`update_collisions` and
  `update_player_enemy_collisions` store `col_enemy` at the top of the loop.)
- **Relative branches are only +127/-128.** The collision loop bodies exceed
  that; use `beq`/`bne` to a nearby trampoline then `jmp` for the far target.
- **`sta VERA_DATA0` with `A=0` destroys bytes.** To touch only the Z-depth byte
  of a sprite attribute, set the address to `<sprite_attr> + 6`.
- **Sprite X/Y are top-left corners.** AABB centres need the half-width bias.
