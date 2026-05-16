# Boss Battle Belay — v1 Scope (FROZEN)

The v1 skeleton's only goal is to prove the narrative arc end-to-end with
placeholders in every box. Subsequent passes flesh out one box at a time.

## In scope

- Godot 4.3+ project, mobile renderer, portrait 1080×1920
- 5 autoloads: `RunState`, `SaveSystem`, `DialogueDirector`, `ReplayRecorder`, `AudioBus`
- Stub scenes: `Main`, `MainMenu`, `Run`, `Arena`, `BossRoom`, `FileBrowser`, `Epilogue`, `HUD`
- Save schema v1: `user://loop_state.json` + `user://boss.dat` created on first boot
- Narrative `PhaseMachine` enum + transitions driven by run count + flags
- Placeholder player (steers, auto-fires), 1 dummy enemy, boss with stubbed phases
- File browser UI listing a fake `user://` tree; `boss.dat` gated behind 3 easter eggs;
  delete really removes the file
- Replay recorder writes input log; epilogue plays it back to drive a Hero actor
- Dev cheats on main menu: bump runs, force phase, kill boss, reset save

## Explicitly out of scope (deferred)

- Procgen rooms / level generation
- Final art, animations, particles, shaders
- Music, sound effects, voice
- Difficulty curve / balancing / damage numbers
- Multiplayer, leaderboards, analytics
- iOS / Android export configs, signing, store metadata
- Localization
- Accessibility passes beyond defaults
- Tutorial / onboarding flow
- Settings menu (audio sliders, rebinding) — stub only

## Defaults adopted

- Easter eggs to unlock delete: **3 of 5**
- Run length: **10 minutes**
- `loop_state.json` is **human-readable** (tampering is part of the meta)
- Epilogue boss AI is **scripted, no RNG**, so replay always lands

## Narrative phases

| Phase | Enter when |
|---|---|
| `NORMAL_FIGHT` | `total_runs < 3` |
| `BOSS_HESITATES` | `3 ≤ total_runs < 5` |
| `BOSS_TALKS` | `5 ≤ total_runs < 8` |
| `EASTER_EGG_HUNT` | `total_runs ≥ 8 AND eggs_found < 3` |
| `FILE_BROWSER_UNLOCKED` | `eggs_found ≥ 3 AND NOT boss_deleted` |
| `BOSS_DELETED` | `boss_deleted AND NOT role_swap_active` |
| `ROLE_SWAP` | `role_swap_active` |
