# GRIDFALL

A single-player first-person horde defense game made with Godot 4. Survive endless waves, construct defenses between attacks, adapt when fixed world gates open, and spend Technology Points earned on defeat to unlock equipment for future runs.

## Run

Requires **Godot 4.4 or newer**, Windows 10/11, and an OpenGL 3.3 compatible GPU. Development verification uses Godot 4.7.2. No .NET, Python, Node, asset downloads, or external services are needed to play.

- Windows: double-click `run.cmd`, or run `./run.ps1` in PowerShell. The launcher uses `GODOT_BIN`, Godot on PATH, or the locally cached development engine.
- The local Windows export is `build/GridFall.exe`; keep `GridFall.pck` beside it. This export runs without installing Godot.
- Any supported desktop platform: open `project.godot` in Godot and press F6 on `scenes/main.tscn`, or run `godot --path .`.
- Editor: `./run.ps1 -Editor`.
- Forward+ rendering: `./run.ps1 -ForwardPlus`. On a Vulkan-capable GPU, Settings additionally exposes screen-space reflections, ambient occlusion, and volumetric lighting. Compatibility rendering remains the default.

## Controls

| Action | Default |
| --- | --- |
| Move / look | WASD / mouse |
| Fire / aim | Left / right mouse |
| Dash / jump or wall jump / crouch, slide or slam | Shift / Space / Ctrl |
| Reload / switch weapons | R / 1, 2 or mouse wheel |
| Collect nearby loot / use supply station / open door | E |
| Pulse ability / medkit / grenade | Q / C / G |
| Restoration matrix (Ascension unlock) | X |
| Inventory / planning | Tab / B |
| Begin next wave | Enter |
| Pause / close interface | Escape |
| Performance overlay | F3 |
| Sandbox controls | F4 |

Movement and interaction keys can be rebound in Settings. Mouse sensitivity, field of view, recoil, crosshair, HUD text size, audio, shadows, frame limit, VSync, fullscreen, and window size can also be changed.

Movement takes inspiration from fast arena shooters: run at 12 m/s, tap Shift for a ground or air dash, and hold Ctrl while moving to slide. Dashes use three recharging charges, shown below the crosshair, and briefly avoid direct damage; damage-over-time and falling remain dangerous. Air control preserves momentum, including slide jumps and jumps out of a dash. Space near a wall permits up to three wall jumps before landing. Tap Ctrl in the air to slam down, damaging nearby enemies on impact; jump just as you land for a higher rebound. A short jump buffer and ledge grace period make timing forgiving. Movement research and terrain still affect speed. Settings can disable movement speed lines, FOV expansion, and camera tilt; slide stamina is optional. Movement state persists in paused combat checkpoints.

## Play

Deploy into The Foundry or Relay Station. Start with a primary weapon, service pistol, 300 scrap, two medkits, and two grenades. Use preparation to build on permitted tiles, buy supplies, repair, upgrade, or sell structures. Construction and all structure management stop during combat. The core, roads, fixed walls, portals, and scheduled gate tiles are protected.

The west gate opens after clearing wave 4; the east gate opens after wave 8. These changes and additional build permissions happen once, before the next preparation phase. Enemies can destroy player defenses and designated destructible sandbox geometry. Permanent world geometry ignores damage. Defenses can be rotated, moved for a 10% base-cost fee, or replaced using their remaining resale value. All management actions require preparation.

Kills award scrap and XP, and can drop rolled weapons, consumables, armor, shield packs, or attachments. Pick up with E. The backpack starts with 20 slots; equip or unequip either weapon slot, compare rolls, use equipment, sell, scrap, reorder, or drop items. Weapons have independent optic, barrel, magazine, grip, and elemental-module slots; attachments can be detached and reused. The Shock Blade accepts only an elemental module. Higher weapon rarities roll up to three compatible modifiers. Ammunition is replenished partly between waves; supplies sell more. Each cleared wave offers up to three functional temporary upgrades or supplies. Stat upgrades stop appearing at their effective caps; salvage remains available when all other rewards are exhausted. Temporary progression disappears when the run ends.

The run ends when the player or core dies. Eligible runs award TP once, with persistent statistics, records, achievements, and 120 functional research nodes across six branches. The connected research graph supports pan, zoom, search, filters, prerequisite checks, and optional respec with a 90% TP refund. Research unlocks equipment or grants bounded upgrades that apply to subsequent runs. Challenge Defense defaults to reduced starting health, faster enemies, and disabled repairs. Configure these alongside limited ammunition, marked-pad construction, ballistic-only weapons, and permanent acid rain. Selected rules are fixed for the run and determine its TP multiplier. Sandbox unlocks all equipment and never awards TP or lifetime records.

Scavenger halves starting reserves, removes free wave ammunition, and raises supply prices. Siege Protocol unlocks at a wave-20 record and starts at wave 20 with 1,500 scrap and all approaches open; its TP and cleared-wave achievements use waves actually survived. Daily Defense uses the same UTC date seed for everyone. Research and selected settings still apply.

Ascension becomes available after reaching wave 25 and researching 20 technologies. It optionally resets ordinary research and TP for Ascension Cores while preserving records, achievements, settings, and Ascension purchases. Cores unlock a configurable secondary loadout, a restoration ability, Resonant tower evolution, and starting mutations. Ascension and respec require finishing or abandoning the saved run. Run perks are snapshotted in checkpoints.

From wave 12, optional adaptive factions react to tower, explosive, close-range, or elemental damage. Planning explains the next faction. Adaptation changes composition weights, with blast/status resistance limited to 20%; it can be disabled in Settings for subsequent runs. Elites and a third boss phase add later-wave pressure. Twenty-five achievements track combat, engineering, survival, modes, and Ascension.

Weather includes rain, thunderstorms, and acid-rain events; ceilings shelter the player from acid rain. Settings can disable weather visuals, enable restrained camera motion and slide stamina, or choose a pixelated Retro or High Contrast scene. UI text remains sharp. Ground materials use procedural normal maps, and bullet marks use a bounded reusable pool.

Content includes nine weapon classes, ten enemy types including a phased Siege Titan every tenth wave, sixteen defensive structures and machines, seven tower targeting modes, two upgrade specializations, elemental effects, chain lightning, penetrating rail fire, projectiles, grenades, shields, and procedural audio. No generated artwork or third-party game assets are included.

## Sandbox editor

The main-menu editor authors separate custom worlds. It supports seven layers, custom dimensions, paint/erase, rectangles, selection, flood fill, copy/paste, undo/redo, rotation, tile properties, visibility controls, zoom/pan, metadata, JSON import/export, validation, and immediate sandbox playtesting. From a playtest, pause and choose Return to map editor. The normal-run planning interface cannot access terrain authoring tools.

Maps use version-2 JSON with shared tile identifiers; version-1 maps migrate when loaded. Save maps independently of progression. Incomplete drafts can be saved and reopened; playtesting additionally requires valid markers and routes. Validation checks known tile types, coordinates, numeric properties, initial routes, and every evolution/spawn-unlock stage. Normal-run worlds are built into `scripts/world.gd`; custom map edits cannot make a run eligible for TP. Supply, shop, ammunition, upgrade, generator, and chest markers have runtime behavior. Tower-only and structure-only pads enforce their categories. Wood, brick, concrete, steel, reinforced, and glass structures have distinct durability and resistance.

World rules configure threat budget, spawn interval, enemy and objective health, boss frequency, hazard damage, sunlight, and fog. Evolution events can be added, edited, or removed with completed-wave thresholds, structure removal coordinates, newly permitted construction tiles, and player messages. Tile inspection exposes terrain movement costs, wall durability/resistance/destructibility, and light color, strength, and range. Navigation uses cached weighted paths, and movement respects the same terrain costs.

Generate seeded 8–96 tile worlds in Balanced, Foundry, or Overgrown styles, or begin from Foundry, Relay Station, and Crossroads templates. Generate, template, and shared-map imports can be undone. The community sharing dialog copies a compressed `GRIDFALL1:` code containing the full playable world; another player can paste that code to import it. Imports validate the decoded map before changing the canvas and enforce an 8 MB decompression limit.

## Saves

Godot stores data in its `user://` directory, normally `%APPDATA%/Godot/app_userdata/GRIDFALL/` on Windows. `profile.json` contains research, TP, statistics, settings, and loadout. `maps/` is the default custom-world directory. Writes use a temporary file, replacement, and a backup; invalid primary profiles fall back to a valid backup.

Eligible runs autosave after a cleared wave, after the upgrade choice, before starting the next wave, and when closing during preparation or combat. Pause to save manually. Version-2 checkpoints also preserve remaining spawns, enemy positions, health and status effects, in-flight projectiles and their firing effects, cooldowns, player velocity/crouch/stamina, Challenge rules, and RNG state. Combat checkpoints restore paused so the player can resume deliberately. Legacy version-1 preparation checkpoints remain readable. A valid backup can be continued even if the primary file is missing; malformed combat data fails validation before it can replace a valid checkpoint. Sandbox defeat or abandonment preserves an unrelated eligible-run checkpoint. Abandoning a run awards no TP.

## Build

Install Godot's matching Windows export templates using its editor. They are installed on this development machine. Choose Project → Export → Windows Desktop → Export Project, or run:

```powershell
./run.ps1 -Export
```

The Windows preset exports the game and data catalog. `build/` and Godot's cache are ignored by Git. Linux support uses the same source; add a Linux export preset in Godot to package it. Linux exports have not been verified. Godot and third-party engine license notices are available in Settings → Credits & licenses.

## Development and verification

The game uses a 60 Hz fixed physics simulation. The grid owns map layers, construction, and navigation; meshes are representations. Cached reverse grid fields use BFS for uniform terrain and Dijkstra for weighted terrain. Small spatial buckets limit separation searches. Complete flat floors use one collision shape and grounded enemies avoid redundant floor sweeps; maps with holes, ramps, or stairs retain full character movement. Ground meshes are instanced and tracer effects use a fixed pool. Weapon/enemy/structure/research/upgrade balance, loot rarity weights, and modifier compatibility live in `data/catalog.json`.

Large hordes are represented by integer counts per enemy type, with at most 601 explicitly queued enemies and 64-entry reserve refills. Wave generation visits at most 600 individual enemies before compressing the remaining budget. Queue memory and spawning work therefore do not grow with millions of pending enemies. Only the configured active population receives physics, rendering, and combat updates: 100 by default, up to 250 in Settings. A billion queued enemies does not mean a billion simultaneous actors. Reserve counts and spawn RNG persist in combat checkpoints.

No test files or extra documentation are maintained. The development benchmark runs actual AI, tower targeting, weapons, damage, waves, rewards, and world evolution in sandbox:

```powershell
./run.ps1 -Benchmark
godot --headless --path . --fixed-fps 60 -- --benchmark
```

The benchmark logs wave clears, damage, kills, navigation time, simulation phases, memory, queue counts, and frame-time percentiles after a two-second warmup. `--benchmark-content` exercises every weapon and structure; `--benchmark-stress` maintains the configured enemy cap. `--benchmark-horde=1000000000` additionally queues a billion enemies in compressed form; `--benchmark-duration=30` changes the duration. Measure rendered performance without `--fixed-fps`, which supplies synthetic frame deltas for accelerated logic checks. Rendered captures can be generated with `godot --path . -- --capture=menu` (also `selection`, `planning`, `inventory`, `editor`, `research`, `settings`, `wave`, `boss`, `results`, `sandbox`, `credits`); source captures go into ignored `.godot/captures/`. Cosmetic randomness is independent of seeded gameplay.

Verification performed without test files:

- Godot parser/import checks, rendered menu/editor/inventory/research/settings/combat captures, and Windows export launch.
- A fresh standard run started with 300 scrap, built defenses using actual earnings, cleared 12 waves, killed a boss, and ended naturally on wave 13 with 122 kills and 112 TP. Buying the 90-TP SMG research and restarting restored its unlock in a fresh run, with temporary progress reset.
- A 190-second content scenario exercised all nine weapons and sixteen structures through waves 10–17. A separate 300-second core scenario cleared 14 waves with 155 kills.
- A fresh 30-second Windows release stress scenario maintained 100 enemies at 1920x1080 with sampled rates of 102-142 FPS (140 FPS final) on an RTX 3050 6 GB laptop GPU. Simulation samples were approximately 2.4-5.1 ms. These measurements are not a universal performance or long-term balance guarantee.
- Live movement, collision, jump, crouch, shooting, melee, and plasma damage; attachment reload/detach ammunition conservation; projectile effect snapshots; loot/equipment save/restore; duplicate-award rejection; invalid-map rejection; and backup recovery in isolated data directories.
- An actual tower-combat wave checkpoint restored its pending upgrade, structures, resources, and player cooldowns. Backup-only Continue, paused-close autosaving, Sandbox checkpoint isolation, and pad restrictions on moving/replacing structures were also exercised.

Very large custom maps and prolonged runs need more profiling. Release builds may not expose Godot's static-memory counter; the overlay reports it as unavailable in that case.

The expanded-content run exercised all nine weapons and sixteen structures through wave 17 over 190 simulation seconds, with 152 kills and a boss defeat. Isolated runtime checks covered maximum-rank research effects, Ascension reset/purchases, restoration, Resonant upgrades, perk checkpoint snapshots, 90% respec refunds, adaptive composition, and the new modes. Procedural maps validated at 8×8, 33×33, and 96×96; a generated map round-tripped through its share code. Native Compatibility and Forward+ launches verified weather, Retro rendering, advanced lighting, and the new authoring/research interfaces.

After optimizing navigation, crowd searches, floor collision, and grounded movement, the 30-second 1080p Windows release benchmark with one billion queued enemies and up to 250 active actors averaged 84.36 FPS on an RTX 3050 6 GB laptop GPU. Frame times were 16 ms at p95, 22 ms at p99, and 39.39 ms worst; 0.21% exceeded 33 ms. Simulation samples were 3.66–4.76 ms, with a 30.15 ms peak. Enemies dealt 57,482 core damage and 57 were killed, verifying continued combat rather than stalled actors. The sampled spawn buffer contained 56–61 entries. A separate million-enemy source run used approximately 61.5 MB of Godot-tracked static memory. These are bounded local measurements, not an unlimited-run or hardware-independent guarantee; the default remains 100 active enemies.

Combat checkpoint verification restored enemies with burn, poison, and slow effects, a live projectile, ability cooldowns, and the exact next RNG value; resuming another checkpoint completed its partially spawned wave through tower combat. Legacy checkpoint migration, malformed combat-data backup recovery, all-on/all-off Challenge rules, and capped-upgrade continuation passed isolated runtime checks.

The follow-up audit restored a billion-enemy reserve with exact RNG state, rejected fractional/unknown/overflow reserve data, and drained a small reserve through actual spawning and a single wave reward. A billion-scale wave composed in 461 microseconds with only 601 explicit queue entries. Another standard run naturally ended on wave 13 after 126 kills and awarded 112 TP; the content scenario exercised all nine weapons and sixteen structures, cleared wave 17, and defeated a boss. Engine-dispatched B opened planning and pause froze time and ammunition. Imported coordinate aliases are rejected, the boss HUD displays phase three, and enemies falling below custom-map terrain return to an active portal without healing, rewards, or consuming RNG.

The movement update passed live physics checks for 12 m/s running, dashing, momentum slides, jump/slam damage, wall-jump push and the three-jump limit, dash charge exhaustion, disabled FOV effects, and exact paused checkpoint restoration with legacy-save compatibility. Rendered captures verified the speed lines and dash meter. Movement decorations draw at most 20 speed lines and one fixed-segment impact ring; movement audio reuses the existing 16-voice pool. The updated Windows export's 30-second horde regression run averaged 92 FPS at an actual 1920×991 window size with 250 active enemies and a billion queued, with an 18 ms p99 and an 88.44 ms worst frame. This benchmark uses stationary autoplay; moving effects were visually checked separately.

The final audit added editable world rules and evolution events, version-1 map migration, intermediate route validation, weighted terrain navigation, and consistent platform collision/destruction. Runtime checks also verified construction and checkpoint restoration on newly cleared ground, lighting-event overrides, support healing cadence, and research unlock snapshots. Core and optional systems in this scope are implemented; the performance and platform limits above remain. Art uses engine-native primitives and procedural materials.
