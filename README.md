# Boss Battle Belay

A mobile roguelike where the final boss is stuck in the same time loop you are.
Each run is ~10 minutes. The boss starts as a normal boss fight, then over
many runs he stops attacking, starts talking, and asks to be freed. The only
way out is to delete him from the game's own files. After that, the next
incoming "hero" defeats you-as-boss using a replay of your first run.

This repository contains the **v1 skeleton**: a bootable Godot 4 project with
scenes, autoloads, save schema, narrative phase machine, file browser, and
replay recorder all wired up with placeholder gameplay. Real combat, art,
audio, and procgen are deferred to subsequent passes.

## Stack

- **Engine:** Godot 4.3+ (GDScript)
- **Target:** Mobile (iOS / Android), portrait 1080×1920
- **Dev platform:** Desktop (Linux / macOS / Windows) with touch emulated from mouse
- **Controls:** Auto-battler / steer-only — player steers, attacks fire automatically

## Run locally

1. Install Godot 4.3 or newer (mobile renderer build).
2. Open the project: `godot --editor` from this directory, or use the Godot
   project manager and import `project.godot`.
3. Press **F5** to run. The first boot creates `user://loop_state.json` and
   `user://boss.dat`.

The `user://` data directory location depends on the OS:
- Linux: `~/.local/share/godot/app_userdata/Boss Battle Belay/`
- macOS: `~/Library/Application Support/Godot/app_userdata/Boss Battle Belay/`
- Windows: `%APPDATA%\Godot\app_userdata\Boss Battle Belay\`

## Project layout

See `docs/SCOPE.md` for the frozen v1 scope and `docs/ARCHITECTURE.md` for the
file-by-file architecture.

## Dev cheats

From the main menu **Debug** panel:
- Bump run counter (advances narrative phase)
- Force phase
- Toggle `boss_deleted` flag
- Reset save (deletes `user://loop_state.json` and recreates `boss.dat`)

Keyboard while in a run:
- **F1** — advance narrative phase
- **F2** — instakill boss
- **WASD / arrows** — steer (in addition to virtual joystick)
