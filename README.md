# GRIDFALL

A single-player first-person horde defense game made with Godot 4. Survive endless waves, construct defenses between attacks, adapt when fixed world gates open, and spend Technology Points earned on defeat to unlock equipment for future runs.

## Run

Requires **Godot 4.4 or newer**, Windows 10/11, and an OpenGL 3.3 compatible GPU. Development verification uses Godot 4.7.2. No .NET, Python, Node, asset downloads, or external services are needed to play.

- Windows: double-click `run.cmd`, or run `./run.ps1` in PowerShell. The launcher uses `GODOT_BIN`, Godot on PATH, or the locally cached development engine.
- Any supported desktop platform: open `project.godot` in Godot and press F6 on `scenes/main.tscn`, or run `godot --path .`.
- Editor: `./run.ps1 -Editor`.

## Controls

| Action | Default |
| --- | --- |
| Move / look | WASD / mouse |
| Fire / aim | Left / right mouse |
| Sprint / jump / crouch | Shift / Space / Ctrl |
| Reload / switch weapons | R / 1, 2 or mouse wheel |
| Collect nearby loot / use supply station / open door | E |
| Pulse ability / medkit / grenade | Q / C / G |
| Inventory / planning | Tab / B |
| Begin next wave | Enter |
| Pause / close interface | Escape |
| Performance overlay | F3 |
| Sandbox controls | F4 |

Movement and interaction keys can be rebound in Settings. Mouse sensitivity, field of view, recoil, crosshair, HUD text size, audio, shadows, frame limit, VSync, fullscreen, and window size can also be changed.

## Play

Deploy into The Foundry or Relay Station. Start with a primary weapon, service pistol, 300 scrap, two medkits, and two grenades. Use preparation to build on permitted tiles, buy supplies, repair, upgrade, or sell structures. Construction and all structure management stop during combat. The core, roads, fixed walls, portals, and scheduled gate tiles are protected.

The west gate opens after clearing wave 4; the east gate opens after wave 8. These changes happen once, before the next preparation phase. Enemies can destroy player defenses and designated destructible sandbox geometry. Permanent world geometry ignores damage.

Kills award scrap and XP, and can drop rolled weapons, consumables, armor, shield packs, or attachments. Pick up with E. The backpack starts with 20 slots; equip either weapon slot, compare rolls, attach an optic or barrel, use equipment, sell, scrap, reorder, or drop items in the inventory. Ammunition is replenished partly between waves; supplies sell more. Each cleared wave offers three temporary upgrades. These disappear when the run ends.

The run ends when the player or core dies. Standard, Seeded, and Challenge runs award TP once, with persistent statistics and 24 functional research nodes across six branches. Research unlocks new weapons and structures or grants bounded upgrades. Research applies to subsequent runs. Challenge reduces player health, increases enemy speed, and disables repairs. Sandbox unlocks all equipment and never awards TP or lifetime records.

Content includes nine weapon classes, ten enemy types including a phased Siege Titan every tenth wave, sixteen defensive structures and machines, seven tower targeting modes, two upgrade specializations, elemental effects, chain lightning, penetrating rail fire, projectiles, grenades, shields, and procedural audio. No generated artwork or third-party game assets are included.

## Sandbox editor

The main-menu editor authors separate custom worlds. It supports seven layers, custom dimensions, paint/erase, rectangles, selection, flood fill, copy/paste, undo/redo, rotation, tile properties, visibility controls, zoom/pan, metadata, JSON import/export, validation, and immediate sandbox playtesting. From a playtest, pause and choose Return to map editor. The normal-run planning interface cannot access terrain authoring tools.

Maps use a versioned JSON format with shared tile identifiers. Save maps independently of progression. Import and playtest validate mandatory markers, known tile types, coordinates, numeric properties, initial routes, and scheduled evolution. Normal-run worlds are built into `scripts/world.gd`; custom map edits cannot make a run eligible for TP.

## Saves

Godot stores data in its `user://` directory, normally `%APPDATA%/Godot/app_userdata/GRIDFALL/` on Windows. `profile.json` contains research, TP, statistics, settings, and loadout. `maps/` is the default custom-world directory. Writes use a temporary file, replacement, and a backup; invalid primary profiles fall back to a valid backup.

Standard runs autosave after a cleared wave and after the upgrade choice. Pause during preparation to save manually. Continue restores the preparation checkpoint, including world evolution, structures, equipment, random state, player/core health, temporary upgrades, and pending reward choices. Mid-combat checkpoints are deliberately unavailable. Abandoning a run awards no TP.

## Build

Install Godot's matching Windows export templates using its editor. Choose Project → Export → Windows Desktop → Export Project, or run:

```powershell
godot --headless --path . --export-release "Windows Desktop" build/GridFall.exe
```

The Windows preset exports the game and data catalog. `build/` and Godot's cache are ignored by Git. Linux support uses the same source; add a Linux export preset in Godot to package it.

## Development and verification

The game uses a 60 Hz fixed physics simulation. The grid owns map layers, construction, and navigation; meshes are representations. Cached reverse grid fields serve shared enemy destinations, with spatial buckets for separation, an active-enemy cap, bounded spawn queues, instanced ground meshes, and a fixed pool of tracer effects. Weapon/enemy/structure/research/upgrade balance lives in `data/catalog.json`.

No test files or extra documentation are maintained. The development benchmark runs actual AI, tower targeting, weapons, damage, waves, rewards, and world evolution in sandbox:

```powershell
./run.ps1 -Benchmark
godot --headless --path . --fixed-fps 60 -- --benchmark
```

The benchmark logs wave clears, damage, kills, navigation time, simulation time, and memory. Rendered captures can be generated with `godot --path . -- --capture=menu` (also `selection`, `planning`, `inventory`, `editor`, `research`, `settings`, `wave`, `results`, `sandbox`); captures go into ignored `.godot/captures/`.

Current verification: Godot parser check and rendered launches passed; a 180-second simulated combat run cleared 11 waves, defeated one boss, applied both gate events, recorded 101 kills, and exercised player/tower damage. This is not a claim of long-term balance or a hardware-independent 60 FPS guarantee. Full visual/runtime review and persistence checks remain in progress.

Advanced optional systems such as Ascension, reactive factions, weather, and community map sharing are not implemented. Art uses restrained engine-native primitives; this is an initial game, not an asset-rich commercial release. Research currently ships 24 real nodes rather than speculative entries for the later 100–150-node expansion.
