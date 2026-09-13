# 04 — State Machine & Screen Init

Source: `game.asm` (`request_state_change`, `handle_state_transitions`,
`init_new_state`, `gameplay_init`, `startscreen_init`, `pause_init`),
`input.asm`.

## Transitions

```mermaid
stateDiagram-v2
    [*] --> START_SCREEN
    START_SCREEN --> IN_GAME: menu "start"\nrequest_state_change
    IN_GAME --> PAUSED: START / P key\n(process_game_input)
    PAUSED --> IN_GAME: ESC / START\n(check_pause_input)
    PAUSED --> START_SCREEN: Q / SELECT
    IN_GAME --> START_SCREEN: lives == 0\n(player_hit -> @game_over)

    note right of START_SCREEN
        request_state_change:
        next_game_state, timer = state_trans_delay,
        has_state_changed = 1
        -> handle_state_transitions
        -> init_new_state dispatch:
           startscreen_init
           gameplay_init
           pause_init
    end note
```

## Transition mechanics

```mermaid
flowchart TD
    REQ["request_state_change(A = new state)"] --> A1["next_game_state = A\nstate_transition_active = 1\nstate_transition_timer = state_trans_delay\nhas_state_changed = 1"]
    A1 --> NEXT["next vsync"]

    NEXT --> HST["handle_state_transitions"]
    HST --> ACT{"transition active?"}
    ACT -->|no| DONE["rts"]
    ACT -->|yes| DEC["dec state_transition_timer"]
    DEC --> Z{"timer == 0?"}
    Z -->|no| DONE
    Z -->|yes| SET["game_state = next_game_state"]
    SET --> INS["init_new_state\ndispatch on game_state"]
    INS --> CLR["clear state_transition_active\nclear has_state_changed"]
    CLR --> DONE

    INS --> D1["START_SCREEN -> startscreen_init"]
    INS --> D2["IN_GAME -> play_sfx_sparkle + gameplay_init"]
    INS --> D3["PAUSED -> play_sfx_menu + pause_init"]
```

Because `has_state_changed` is set on the *request* frame and `game_tick_loop`
returns early when it is set, the requested frame and the transition frame both
skip normal tick logic. See `02-irq-and-tick.md`.

## Screen init routines

| Routine | Purpose | Key steps |
|---|---|---|
| `gameplay_init` | Set up the play field | Layer 0 = `LAYERCONFIG_64X324BPP` + tilemap/tiles; Layer 1 = `LAYERCONFIG_64X32UI` + UIMAP/PETSCII; write player sprite attrs; `build_sprite_ui`, `enemy_init`, `init_projectiles`, `init_explosions`, `player_reset`; `VERA_DC_VIDEO = %01110001` (sprites + L1 + L0) |
| `startscreen_init` | Title screen | Layer 0 = `LAYERCONFIG_BITMP4BPP` + cover bitmap; `joystick_latch = $CF`; `clear_all_sprites`; `stz player_invuln`; reset menu cursor to (99,132) index 0; `VERA_DC_VIDEO = %01010001` (sprites + L0); `game_state = START_SCREEN` |
| `pause_init` | Pause overlay | Clear 4096 bytes of `VRAM_TEXTMAP`; Layer 1 = `LAYERCONFIG_TEXT64X32`; `VERA_DC_VIDEO = %00110001` (sprites **off**, L1 + L0); print `pause_title` / `pause_resume_hint` / `pause_quit_hint` |

## Pause screen specifics

- Text map must be **>= 40 tiles wide** on the 40-column screen or VERA wraps
  and mirrors cols 0-7 at the right edge (symptom: stray leading chars like
  `ESC`/`Q`).
- `VRAM_TEXTMAP` ($0C000) + 64*32*2 = `$0D000` exactly meets `VRAM_TILEMAP` — no
  overlap, but no headroom either.
- Row stride for a 64-wide 1bpp map is **128 bytes**.
- Layout: `PAUSED` row 12 col 17, resume hint row 14 col 9, quit hint row 16
  col 10.
- The clear loop writes **2 bytes/iteration x 256 = 512 bytes** per outer pass,
  so `ldx #8` = 4096 bytes. Raising it overruns `$0CFFF` into `VRAM_TILEMAP`
  and corrupts the game background.
- `pause_init` disables sprites (`DC_VIDEO = $31`), `startscreen_init`
  re-enables them (`$51`) — leftovers reappear unless cleared, which is why
  `startscreen_init` calls `clear_all_sprites`.

## Input handlers per state

| State | Handler | Keys / inputs |
|---|---|---|
| START_SCREEN | `check_start_menu_input` | up/down (+ `menu_delay`), start to begin |
| IN_GAME | `process_game_input` | move, fire (`@check_fire` / `@check_autofire`), pause (`@pause_game`), `M` mute, `-`/`+` volume |
| IN_GAME | `check_pause_input` (polled via ESC) | ESC / START = resume; Q / SELECT = quit to menu |
| PAUSED | `check_pause_input` | ESC / START = resume; Q / SELECT = quit to menu |

Note: keyboard **Left-Shift maps to SELECT**, and the music mute/volume keys are
handled only in `process_game_input` — not in the start-screen or pause handlers.
