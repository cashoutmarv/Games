# Architecture

File-by-file map of the v1 skeleton.

## Boot flow

```
project.godot  ->  scenes/main.tscn  ->  scenes/main_menu.tscn
                                   `->  scenes/epilogue.tscn  (if role_swap_active)
```

`Main` checks `SaveSystem.state.role_swap_active` and routes to either the
main menu or the role-swap epilogue.

## Autoloads (singletons)

| Name | File | Responsibility |
|---|---|---|
| `SaveSystem` | `autoload/save_system.gd` | Owns `user://loop_state.json` and `user://boss.dat`; load/save/delete |
| `RunState` | `autoload/run_state.gd` | Tracks the current run + phase; emits signals on phase change |
| `DialogueDirector` | `autoload/dialogue_director.gd` | Loads `data/dialogue.json`; returns lines per phase |
| `ReplayRecorder` | `autoload/replay_recorder.gd` | Records inputs each tick; flushes to `user://run1_inputs.dat` |
| `AudioBus` | `autoload/audio_bus.gd` | Stub — logs SFX/music ids in debug builds |

## Scenes

| Scene | Script | Purpose |
|---|---|---|
| `main.tscn` | `main.gd` | Boot router |
| `main_menu.tscn` | `main_menu.gd` | Start / Continue / Files + Debug panel |
| `run.tscn` | `run.gd` | 10-min run lifecycle; owns Stage + HUD |
| `arena.tscn` | `arena.gd` | Placeholder room w/ player + 1 enemy + "To Boss" button |
| `boss_room.tscn` | `boss_room.gd` | Boss encounter; routes boss dialogue → DialogueBox |
| `file_browser.tscn` | `file_browser.gd` | In-fiction Files UI; delete boss.dat (gated) |
| `epilogue.tscn` | `epilogue.gd` | Role-swap; replay drives the incoming Hero |
| `hud.tscn` | `hud.gd` | HP bar + joystick + timer (used by `run.tscn`) |
| `ui/virtual_joystick.tscn` | `ui/virtual_joystick.gd` | Touch + mouse steering pad |
| `ui/dialogue_box.tscn` | `ui/dialogue_box.gd` | Bottom-of-screen line display with queue |
| `ui/file_browser_row.tscn` | `ui/file_browser_row.gd` | One row in the file list |
| `actors/player.tscn` | `actors/player.gd` | Steering + auto-fire (also Hero in epilogue) |
| `actors/enemy.tscn` | `actors/enemy.gd` | Dummy that chases the player |
| `actors/boss.tscn` | `actors/boss.gd` | Phase-driven behavior; emits dialogue lines |
| `actors/projectile.tscn` | `actors/projectile.gd` | Travels, damages on hit |

## Systems

- `scripts/systems/phase_machine.gd` — `NarrativePhase` enum + static `evaluate(state)`. Pure; no I/O.
- `scripts/systems/auto_targeter.gd` — static `find_nearest(from, group, range)`.

## Data

- `data/dialogue.json` — line pools keyed by phase name + `ROLE_SWAP_END`
- `data/easter_eggs.json` — 5 egg definitions; 3 required to unlock delete
- `data/boss_phases.json` — HP-pct → behavior id (only `idle`/`hesitate`/`talk`/`hint`/`plea` are actually wired)

## Save schema (`user://loop_state.json`)

```json
{
  "schema_version": 1,
  "total_runs": 0,
  "successful_runs": 0,
  "dialogue_phase": "NORMAL_FIGHT",
  "easter_eggs_found": [],
  "boss_deleted": false,
  "role_swap_active": false,
  "first_run_recorded": false,
  "recorded_inputs_path": "user://run1_inputs.dat",
  "last_played_iso": "..."
}
```

- `user://boss.dat` — recreated on boot if missing AND `boss_deleted == false`. Header + signature + 1KB seeded random padding.
- `user://run1_inputs.dat` — binary: header, frame count, then `[i32 tick, f32 x, f32 y, u8 fired]` per frame.

## Run lifecycle

1. `MainMenu` → Start → `Run`
2. `Run._ready()` calls `RunState.start_run()` → starts `ReplayRecorder`
3. `Arena` loads; player can press "To Boss" to advance
4. `Run._enter_boss_room()` → swaps in `BossRoom` and calls `RunState.mark_reached_boss_room()`
5. Win (boss HP ≤ 0) or lose (player HP ≤ 0 or 10:00 expires) → `Run._finish(won)`
6. `RunState.end_run(won)` bumps counters, flushes replay if eligible, recomputes phase

## Verification (manual)

| # | Check | Pass |
|---|---|---|
| 1 | Open in Godot 4.3+ | No parser errors; all 5 autoloads listed |
| 2 | F5 | `Main` loads → routes to `MainMenu` |
| 3 | First boot | `user://loop_state.json` and `user://boss.dat` exist on disk |
| 4 | JSON shape | All fields present with defaults |
| 5 | Phase machine | Debug → "Bump runs +1" five times → phase becomes `BOSS_TALKS` |
| 6 | Egg gating | Debug → "Add 3 eggs" → "Files" button appears |
| 7 | Browser delete | Files → boss.dat row → Delete → file removed; `boss_deleted = true` |
| 8 | Tampering | Delete `boss.dat` externally with state intact → next boot flips flag |
| 9 | Replay record | Play → press "To Boss" → die → `user://run1_inputs.dat` > 0 bytes |
| 10 | Touch + desktop | Mouse-drag joystick and WASD both steer; identical velocity |
| 11 | Reset | Debug → "Reset save" → all `user://` files recreated cleanly |

## Headless test

```sh
godot --headless --script res://tests/test_save_roundtrip.gd
```

Exits 0 on success, 1 on any failed assertion.
