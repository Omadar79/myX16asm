# Nebula Squadron

## Commander X16 Project

Welcome to my first Commander X16 project! This project is a learning exercise where I am diving into assembly language to create a retro-style space shoot-em-up game. The game is being developed for the Commander X16, a modern 8-bit computer inspired by the classic computers of the 1980s. If it goes well, I might port it to other 6502-based systems like the Commodore 64 and/or the NES

### Project Overview

This project aims to recreate the nostalgic feel of a classic, vertical scrolling, space shooter game. The game features a spaceship that the player can control to navigate through space, avoiding obstacles, and shooting enemies while aiming to achieve a high score.  

If I can get the basic shooting mechanics locked in, I want add powerups and usable items, boss battles, story exposition via radio communication, and eventually even a level or progression selection map similar to Super Mario Bros 3 or Bionic Commando.

### Features

- **Retro Graphics**: Utilizing the New Retro Commander X16 VERA chip to render sprites and backgrounds.
- **Keyboard Controls**: Move the spaceship using the WASD or cursor keys.
- **joystick Controls**: Implement an SNES controller as another method to control the spaceship
- **Assembly Language**: Written in assembly language for an authentic retro programming experience. 

### Code Overview

Everything is assembled into a single program from `game.asm`, which `.include`s the other files, so the include order matters. Here is what each source file is responsible for:

#### Core / Engine

- **`game.asm`**: The program entry point. Loads all the assets at boot (`start_game`), sets up the custom IRQ handler, and drives the game from the 60 Hz VERA vsync tick (`game_tick_loop`). Contains the game-state machine (start screen / in-game / paused), the state-transition system, player movement and sprite updates, and the per-screen setup routines (`gameplay_init`, `startscreen_init`, `pause_init`).
- **`globals.asm`**: Shared constants and variables; zero-page assignments, screen boundaries, VERA layer configurations, game-state IDs, player/sprite state, and the on-screen text strings.
- **`macros.inc`**: Assembler macros. `MACRO_VERA_SET_ADDR` points a VERA data port at a VRAM address with a given stride; `MACRO_SETLFS` sets up a KERNAL logical file.
- **`x16.inc`**: Hardware definitions for the Commander X16; VERA registers and VRAM addresses, IRQ vectors, RAM/ROM bank registers, and KERNAL jump-table entries.
- **`loadfiledata.asm`**: Asset loading. Holds the asset filenames (`sprites.bin`, `tiles.bin`, `cover.bin`, etc) and `loadtovram`, which streams a binary file from the host device straight into VRAM.

#### Gameplay

- **`input.asm`**: All keyboard and joystick reading, with separate handlers for the title menu, in-game play (movement, fire, pause, music mute/volume keys) and the pause screen (resume / quit).
- **`sprite.asm`**: VERA sprite plumbing; the sprite-attribute address map (`sp_att_player`, `sp_att_playermisc`, `sp_att_playerproj`, `sp_att_enemy`, `sp_att_effects`, `sp_att_ui`), the `get_sprite_frame_addr` / `get_small_sprite_frame_addr` helpers that convert a frame index into a VERA image address, `clear_all_sprites`, and the HUD sprite layout.
- **`projectiles.asm`**: The player's bullet system; a pool of 10 projectiles holding position, direction, lifetime and type, plus `fire_projectile` (per-weapon cooldowns and sounds), per-frame movement, off-screen culling and sprite updates.
- **`enemy.asm`**: The enemy framework; the `enemies_state` bit-field (active flag / pattern ID / state), the per-enemy pattern variables, VERA sprite position read/write helpers, and `enemy_update_loop`, which dispatches each enemy to its movement pattern via the `pattern_functions` table. Also holds `deactivate_enemy` and `check_enemy_offscreen`, plus the straight-down pattern (the other patterns will move to `enemypatterns.asm`).
- **`collision.asm`**: All hit detection, using 16-bit AABB maths (`abs_dx` / `abs_dy`). Handles projectile-vs-enemy hits, and player-vs-enemy contact with a small centred core hitbox, 3 lives, respawn invulnerability, the death blink and game over.
- **`effects.asm`**: Transient visual effects; a 5-slot explosion pool that animates through the flame sprite frames and then frees the slot for reuse.

#### Audio

- **`music.asm`**: Background music. Loads `zsmkit.bin` into a RAM bank, loads and starts the ZSM songs, and provides mute and volume control by wrapping ZSMKit's `zsm_setatten`.
- **`soundfx.asm`**: Sound effects. A table of 10-byte PSG envelopes plus the `play_sfx_*` entry points; `soundfx_play_irq` advances the envelope from the scanline interrupt on PSG channel 15.
- **`zsmkit.inc`**: Entry-point addresses for the ZSMKit music/sound engine.

#### Not currently compiled

- **`enemypatterns.asm`**: Draft enemy movement patterns (sine wave, zigzag, circle, swoop). Not included in the build yet; it references variables that don't exist and duplicates the pattern table that now lives in `enemy.asm`.
- **`sinewaves.asm`**: A 256-entry sine table with `get_sine` / `get_cosine`, used by the wave patterns. Only gets pulled in once `enemypatterns.asm` is enabled.
- **`ui.asm`**: Draft HUD readouts (score / level / powerup). Not included: it references undefined symbols and a `MACRO_PRINT_STRING` that doesn't exist yet.



### Special Thanks and Credit

- **Mooinglemur**: For so much X16 work and the branch of the ZSMKit for streaming music/sound support.
    - https://github.com/mooinglemur/zsmkit 
- **The CommanderX16 Team**: including the 8-Bit guy for inspiring me to want to learn retro game dev
    - https://www.youtube.com/The8BitGuy
- **Matt Heffernan**: for all his youtube tutorials and code examples. 
    - https://github.com/SlithyMatt
    - https://www.youtube.com/@slithymatt