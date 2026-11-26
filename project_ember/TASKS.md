## v0.34.0 — Stage IV: Hero Roster & Recruitable Lords

- [x] Add stable hero IDs and a persistent player hero roster while retaining the legacy player_hero save field.
- [x] Migrate existing single-hero campaigns into a one-entry roster without changing SAVE_VERSION.
- [x] Add three recruitable lords with distinct commander specializations and a 100-gold hire cost.
- [x] Add city-panel recruitment, roster display and active-commander selection for the existing player army.
- [x] Preserve each hero's level, experience, skill ranks, health and wounds when switching commanders.
- [x] Add recruitment, duplicate-hire, roster-cap, commander-switch and legacy-save smoke coverage.
- [ ] Verify the commander roster UI and battle handoff on the target Android device.

## v0.35.0 — Stage V: Multiple Armies & Hero Assignments

- [x] Introduce stable player army records with independent unit rosters and strategic map positions.
- [x] Allow creation by splitting the selected army, map selection and independent movement for multiple player armies.
- [x] Assign one available hero to each army and prevent assigning the same hero twice.
- [x] Migrate legacy player_units and player_cell into the original primary army while retaining legacy save fields.
- [x] Preserve existing unit records, role IDs, per-army upgrades, movement allowance and campaign save version.
- [x] Add smoke coverage for army creation, assignment, recruitment targeting, movement, combat handoff/results, legacy migration and save/load.
- [ ] Validate map readability, touch selection and performance on the target Android device.

## v0.36.0 — Stage VI: Hero Equipment & Loot

- [x] Add persistent weapon, armor and relic slots with data-driven item definitions and per-hero inventory.
- [x] Add deterministic battle rewards using campaign seed, turn, reward sequence and encounter identity without adding a new campaign resource.
- [x] Apply equipment modifiers through one shared commander-stat calculator used by campaign and tactical combat.
- [x] Add mobile inventory/equipment UI with item comparison and equip/unequip actions.
- [x] Preserve old hero records and normalize missing equipment/inventory fields safely without changing SAVE_VERSION.
- [x] Add smoke coverage for item definitions, inventory, equip/unequip, deterministic rewards, commander stats and save/load.
- [ ] Verify equipment UI and battle stat feedback on the target Android device.

## v0.33.1 — Pixel Art Restoration & Release Guard

- [x] Restore the owner-provided Tiny Swords blue/red pixel infantry atlas and matching animation manifest in playable release archives.
- [x] Keep nearest-neighbour, unshaded animated pixel sprites as the only production unit renderer.
- [x] Disable the procedural low-poly BattleUnit fallback.
- [x] Add a permanent sprite-art policy and static regression checks.
- [x] Add a playable-release packager that refuses to emit a sprite-less archive.
- [x] Prevent source-only GitHub CI from uploading a misleading game archive when required art is absent.
- [ ] Verify restored pixel soldiers and pixel-isometric battlefield on the target Android device.

# Project Ember — Tasks

## v0.33.0 — Territorial Control & Frontier Fortifications

- [x] Derive territorial influence from cities, armies and watchtowers instead of fixed city-adjacency rings.
- [x] Resolve equal rival influence as disputed land and render it with a distinct border.
- [x] Add watchtower province construction, persistent influence and nearby tactical armour.
- [x] Let threatened AI kingdoms prioritize frontier watchtowers.
- [x] Restrict new settlements in rival-owned and contested territory.
- [x] Add deterministic ownership, fortification and save-compatibility smoke tests.
- [ ] Balance border pressure, tower placement and expansion pacing in long campaign playthroughs.
- [ ] Verify map rendering cost and tactical armour feedback on the target Android device.


## v0.32.0 — Strategic Kingdom AI

- [x] Evaluate treasury, resource income, army upkeep, population and current military pressure for every living AI kingdom.
- [x] Set an economy focus and a sustainable army-size target instead of using a fixed troop-count script.
- [x] Choose recruitment roles by doctrine and active enemy composition, with valid unlock-building decisions.
- [x] Prioritize market, farm or workshop development according to the kingdom's economic needs.
- [x] Gate settlement founding on reserves, net income and nearby threats.
- [x] Score expansion sites by terrain yield, local resources, neutral-site proximity and rival-city spacing.
- [x] Select war targets by distance, relative army strength and danger to the kingdom's own cities.
- [x] Add deterministic strategic AI smoke tests and static QA guards.
- [ ] Balance long campaigns and AI decision quality using real multi-dozen-turn Android playthroughs.
- [ ] Verify CPU/FPS and player-facing outcomes on the target Android device.


## v0.24.1 — Tactical Combat Expansion

- [x] Add four symmetric, deterministic terrain zones to woodland, highlands and marsh battles; keep grassland neutral.
- [x] Add forest, high-ground and marsh movement/ranged/charge modifiers without physics or pathfinding changes.
- [x] Add side/rear melee flanking and the non-stacking exposed status.
- [x] Add the +1 frontal armour bonus for the existing HOLD order.
- [x] Add role-aware target scoring while preserving direct player attack orders and stable current targets.
- [x] Add flank-hit totals to the battle result and existing result dictionary.
- [x] Add three smoke-test source files and static validation guards.
- [x] Keep campaign unit IDs and save schema unchanged.
- [ ] Import and parse with Godot 4.7.2, run all smoke tests and inspect the four biomes.
- [ ] Verify mobile zone readability, touch interaction and GPU/FPS on the target Android phone.
- [ ] Verify an old campaign save loads and a new campaign can complete a battle and return to the map.

## v0.22.0 — Strategy & UI Icon Integration

- [x] Add both supplied icon packs with their licences and original PNG variants.
- [x] Replace generic strategic city stamps with player/AI settlement sprites.
- [x] Use map-pack army/settler markers and Gridwright resource/unit/command icons.
- [x] Add contextual building and recruitment button icons without changing their callbacks or costs.
- [x] Show only gold, food and stored production; do not invent wood/stone campaign stocks.
- [x] Add icon-catalog smoke coverage and static local-resource validation.
- [ ] Import v0.22.0 in Godot 4.7.2 Android Editor and verify the new textures and GDScript parser.
- [ ] Check icon readability, touch targets and visual density on the target phone.
- [ ] Confirm a v0.21.1 save loads and that the new HUD values update after advancing a turn.

## v0.21.1 — Pixel Terrain Type Fix

- [x] Replace the invalid CanvasItem texture-filter enum on both Sprite3D props with BaseMaterial3D.TEXTURE_FILTER_NEAREST.
- [x] Add a smoke-test assertion for SpriteBase3D nearest-neighbour filtering.
- [x] Add a static QA guard for the corrected enum type.
- [x] Preserve all battlefield artwork, units, cavalry, combat and campaign systems.
- [x] Run static validation (49/49) and verify the final ZIP archive.
- [ ] Confirm Godot 4.7.2 import and runtime smoke tests in the Android Editor.


## v0.21.0 — Mythryl Pixel Terrain Battlefield

- [x] Replace only the tactical battlefield ground with the supplied 64px isometric grass, dirt, transition and shallow-water tiles.
- [x] Batch the battlefield surface into one mesh and one atlas material with nearest-neighbour filtering.
- [x] Add pack-native trees, pines, bushes, rocks, flower patches and grass cliff sprites.
- [x] Give grassland, woodland, highlands and marsh distinct road, clearing, shoreline and decoration layouts.
- [x] Preserve the original flat movement plane, collider, camera, combat systems, every unit sprite and the cavalry assets.
- [x] Validate the source package and asset paths with 48/48 static checks.
- [ ] Import with Godot 4.7.2 Android Editor and run all runtime smoke tests.
- [ ] Inspect all four biomes at close/far zoom on the target phone and measure GPU/FPS impact.

## v0.10.2 — Fog of War & Chunked Map Streaming

- [x] Add current vision around the player army, cities and active settler.
- [x] Persist explored cells as sparse encoded IDs in campaign saves.
- [x] Keep explored terrain dimmed when outside current vision; hide unknown terrain.
- [x] Hide enemy field armies outside current vision and retain remembered enemy city markers.
- [x] Stream only explored cells that intersect the viewport instead of scanning all 24,031 world coordinates.
- [x] Aggregate discovered terrain into 6×6 chunks at continent zoom.
- [x] Add fog discovery, persistence, save/load and LOD regression checks.
- [ ] Validate fog edge quality and map readability on Android.
- [ ] Measure actual FPS, CPU time and terrain instance count while zoomed out on the target device.

## v0.10.1 — Render Batch Performance Hotfix

- [x] Replace thousands of per-hex terrain draw commands with one MultiMeshInstance2D batch.
- [x] Preserve terrain colors and faction territory tinting through per-instance colors.
- [x] Replace repeated city-ownership scans with a compact claim lookup.
- [x] Extend the FPS overlay with CPU time, visible hexes and terrain batch count.
- [x] Add CI coverage for 1,024 hex instances in one batch.
- [ ] Confirm Android draw calls fall sharply on the target device.
- [ ] Measure FPS and CPU time at default, close and continent-wide zoom.
- [ ] Verify visual tile edges and faction tints on device.

## v0.10.0 — Living World & Nine AI Kingdoms

- [x] Expand the map to a radius-89 world with exactly 24,031 hexes.
- [x] Generate terrain deterministically by coordinate and world seed; avoid per-hex scene nodes and save records.
- [x] Render viewport-visible tiles only and add pan/zoom navigation for mobile and desktop.
- [x] Add nine independent AI kingdoms with capitals, rulers, cities, resources and field armies.
- [x] Advance AI economy, building queues, recruitment, population and expansion every player turn.
- [x] Give AI armies strategic movement objectives and block army/city cell overlap.
- [x] Add faction markers and the scrollable Kingdoms overview panel.
- [x] Allow tactical battles against any selected AI kingdom and save its post-battle survivors.
- [x] Preserve v0.9.x campaigns through additive world/kingdom save migration.
- [x] Add CI tests for world size, terrain determinism, AI turns and save/load.
- [ ] Verify large-map pan/zoom performance on the target Android phone.
- [ ] Verify kingdom panel readability and enemy army selection on device.
- [ ] Balance AI expansion, army sizes and movement aggression through longer campaigns.

## v0.9.5 — Compact Mobile HUD Fix

- [x] Replace the permanent strategic command grid with a compact quick dock.
- [x] Move secondary strategic actions into a collapsed-by-default drawer.
- [x] Replace the permanent tactical command grid with a compact quick dock.
- [x] Move tactical orders, control groups and settings into a scrollable command drawer.
- [x] Make Android Back close the open command drawer.
- [x] Add CI coverage for drawer default state, expand/collapse and central play-area space.
- [ ] Verify map and battlefield visibility on the target Android phone.
- [ ] Verify command drawer scrolling and one-handed access in both screen orientations.

## v0.9.4 — Mobile UX Foundation (UI-1)

- [x] Add dp conversion from screen DPI and reference viewport/window ratio; clamp DPI and support UI scale 0.8–1.6.
- [x] Refresh UI metrics on window/viewport resize and settings scale changes.
- [x] Add SafeAreaContainer with live inset recalculation and use it for strategy, battle and FPS HUD roots.
- [x] Add TouchGestureRouter with indexed multitouch, tap/double/long/drag/pinch/two-finger pan and UI input exclusion.
- [x] Retain Control-based button input and suppress duplicate emulated mouse world input in the router.
- [x] Add Haptics, Toast/ToastManager, ConfirmDialog, BottomSheet and IconButton base components.
- [x] Add initial menu, settings, confirmation and cancel SVG icons.
- [x] Handle Android Back on strategy and battle screens; handle background pause/save without writing an unfinished battle.
- [x] Set Sensor Landscape and disable automatic quit on Back.
- [x] Protect New Campaign behind a one-second destructive hold.
- [x] Add atomic .tmp/.bak campaign save replacement and backup recovery without changing JSON v1 keys.
- [x] Extend UI scale to 0.8–1.6 and migrate shared theme, SettingsPanel, legacy HUD geometry and FPS overlay dimensions to dp.
- [x] Add CI tests for dp calculation, gesture routing, UI components, destructive reset and atomic backup recovery.
- [ ] Import v0.9.4 in Godot Android Editor and verify landscape + reverse-landscape rotation.
- [ ] Verify real safe-area insets on a notched device and actual 48 dp targets at each UI scale.
- [ ] Verify one-hand right/left interaction; full left-handed mirroring is scheduled for UI-2.
- [ ] Test Back in battle/map/city, app background during battle, haptic feedback and backup recovery on device.
- [ ] Inspect UI screenshots and FPS overlay on 2400×1080, 1280×720 and 800×480 physical/emulated layouts.
- [ ] Capture and share a screenshot of battle with selected units and FPS readings.

## v0.9.3 — Combat Effects & Sound

- [x] Connect impact feedback to melee, spear, cavalry and ranged damage events.
- [x] Add cavalry charge, commander rally, muzzle flash, death dust and projectile trail effects.
- [x] Generate original short combat sound cues at runtime and route them through the existing SFX bus.
- [x] Scale fixed visual and audio pools across Low / Medium / High graphics profiles.
- [x] Cache bolt meshes/materials and reuse effect slots instead of allocating nodes for every hit.
- [x] Add CI tests for audio sample data, pool sizing, effect reuse and node budgets.
- [ ] Import v0.9.3 in Godot Android Editor and listen to the combat sound cues.
- [ ] Verify effect readability and audio balance during 20–50 unit battles on the phone.
- [ ] Measure Low / Medium FPS during large engagements.

## v0.9.2 — Battlefield Biomes & Terrain

- [x] Add grassland, woodland, highlands and marsh tactical biome profiles.
- [x] Derive the battle biome from the six neighboring strategic hexes without changing the campaign save schema.
- [x] Generate deterministic biome dressing from the battle's strategic origin cell.
- [x] Add distinct ground palettes/textures, vegetation density, woodland logs, highland rock shelves and marsh pools/reeds.
- [x] Display the selected terrain name in the tactical HUD.
- [x] Keep the original flat battlefield collider and unit movement plane; biome props are visual-only.
- [x] Add CI coverage for biome selection, deterministic seeds, profile variation, collision bounds and decoration budgets.
- [ ] Import v0.9.2 in Godot Android Editor and compare all four biomes on the phone.
- [ ] Verify marsh pool transparency and highland/woodland contrast at tactical camera zoom levels.
- [ ] Measure Low/Medium FPS with 20–50 units in each biome.

## v0.9.1 — Units

- [x] Merge each team/role static silhouette into one vertex-coloured ArrayMesh.
- [x] Merge each role's weapon/arm/banner into one animated ArrayMesh; keep a shared vertex-colour material.
- [x] Cache the ten team/role static and action mesh combinations.
- [x] Add larger readable headgear, shoulder armour, role-specific weapons, horse/rider details and commander banner.
- [x] Add idle breathing and movement sway; add sword, spear, bow, cavalry and commander-ability motion.
- [x] Add cached hit flash without a unique material per unit.
- [x] Add death fall and capped 8–10 second corpses, with lower corpse limits on Low quality.
- [x] Keep one selection/target ring and show the health bar only when selected, targeted or wounded.
- [x] Add distance/zoom-based animation LOD.
- [x] Add CI checks for two core mesh instances, shared resources and the eight-node limit with 50 units.
- [ ] Import v0.9.1 in Godot Android Editor and verify each role's silhouette and attack animation.
- [ ] Measure FPS, Draw Calls, objects, primitives and nodes with 20–50 units on Low and Medium.
- [ ] Confirm selected/wounded health bars and death corpses remain readable on the phone.

## v0.9.0 — Foundation

- [x] Add central `ArtPalette` and `ART_BIBLE.md`.
- [x] Add shared runtime `UiTheme` for strategic and tactical interfaces.
- [x] Add separate `GameSettings` persistence at `user://settings.cfg`.
- [x] Add quality presets, audio levels, interface scale, overlay, vibration and camera speed controls.
- [x] Add first-run mobile-aware quality selection.
- [x] Add `PerfOverlay` with FPS, draw calls, objects, primitives, node count and available memory counters.
- [x] Add `VisualCache` for materials, meshes and battlefield ground texture.
- [x] Route existing soldier/environment builders through cached resources.
- [x] Add Foundation smoke tests for settings persistence, Theme and resource cache.
- [ ] Import v0.9.0 into Godot Android Editor and verify both scenes.
- [ ] Check touch targets and safe-area placement on the phone.
- [ ] Record FPS/draw calls/objects/primitives for 20–50 units on Low and Medium quality.

## v0.7.0 — Hero Commanders and Progression

- [x] Add persistent ruler and enemy commander records to campaign state and save/load.
- [x] Spawn commanders as separate tactical combat units outside the 24-troop army cap.
- [x] Add commander level-scaled health, damage, armor and battlefield visuals.
- [x] Add passive leadership aura to nearby allies.
- [x] Add Battle Cry with local healing, temporary buffs, cooldown and enemy AI use.
- [x] Award hero experience from kills, damage and battle victory/defeat.
- [x] Add Leadership, Tactics and Might skill branches with five ranks each.
- [x] Add skill-point spending UI to the city panel and cooldown control to the tactical UI.
- [x] Preserve hero wounds and recover defeated commanders over campaign turns.
- [x] Add automated progression, aura, Battle Cry and persistence smoke tests.
- [ ] Import and test v0.7.0 in Godot Android Editor.
- [ ] Validate new hero UI and Battle Cry button fit/touch response on the phone.
- [ ] Balance hero aura strength, experience rewards and ability cooldowns in live battles.

## Next gameplay targets

- [ ] Stage IV: recruitable lords and a persistent hero roster (see v0.34.0 above).
- [ ] Stage V: assign heroes to independent player armies (see v0.35.0 above).
- [ ] Stage VI: hero equipment slots and loot rewards (see v0.36.0 above).
- [x] Gameplay terrain modifiers for forest cover, high ground, marsh movement and flanking (v0.24.1).
- [x] Neutral camps, resource sites and exploration rewards (v0.27.0–v0.30.0).
- [x] AI kingdom settlement expansion and strategic target planning (v0.32.0).
- [x] Add a non-mutating battle estimate before kingdom engagements using unit stats, veterancy, upgrades, role counters, commander stats and terrain; keep the actual tactical battle unchanged.
- [ ] Add city list and quick switching between founded cities.
- [ ] Add roads and trade routes.

## Previous v0.6.0 roster and command status

- [x] Centralized unit role data for city, save validation and tactical combat.
- [x] Added spearmen and cavalry; archery range and stable recruitment unlocks.
- [x] Expanded army capacity to 24; preserved old role IDs and saves.
- [x] Added role-aware formations, drag-box selection, four control groups and tactical camera pan/zoom.
- [x] Added roster, recruitment and role combat profile tests.

## v0.5.3 audit status

- [x] Fixed GDScript parser error in the city production queue summary.
- [x] Fixed recruitment queue message referencing an undefined variable.
- [x] Added explicit GDScript types for Godot 4.3 inference failures.
- [x] Matched the tactical scene root type to its Node3D script.
- [x] Preserved unreadable saves before creating replacement data.
- [x] Added in-bounds settler spawn selection for cities founded near the map edge.
- [x] Made Godot log errors fail CI validation.
- [x] Added automated campaign logic smoke tests.


## v0.28.0 completed — faction founding
- [x] Data-driven peoples, cultures and two-trait selection.
- [x] Faction effects on the existing three-resource economy and army.
- [x] Nine AI faction identities and matching one-time starting bonuses.
- [x] Mobile founding panel and legacy-save fallback (schema v1 retained).
- [ ] Run Godot 4.7.2 parser/import and smoke tests.
- [ ] Verify founding UI and a new campaign on Android landscape.

## Next: G — diplomacy and AI kingdoms
- [ ] Relationship scale and nine AI personality profiles.
- [ ] Weighted AI decisions for peace, trade, alliance, tribute and war.
- [ ] War reasons, proposals and war-weariness.
- [ ] Save/load regression tests and Android panel UX.

  
## v0.39 — Block 6: tactical battle forecast

- [x] Add a read-only forecast before entering a kingdom battle.
- [x] Use existing unit catalogue values, current health, veterancy, army upgrades, anti-cavalry and charge modifiers, role-target preferences, commander stats and a bounded average of battlefield-biome effects.
- [x] Show estimated victory chance with an uncertainty interval, estimated survivors/losses and the battlefield biome.
- [x] Require explicit confirmation before entering the existing tactical battle scene; do not auto-resolve or mutate the campaign from the forecast.
- [x] Preserve the existing save schema at version 1 and leave neutral-location encounters unchanged.
- [x] Add regression tests for symmetry, force size, health, veterancy, upgrades, counters, terrain, commanders, deterministic output and non-mutation.
