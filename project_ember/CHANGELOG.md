## v0.10.1 — Render Batch Performance Hotfix

- Replaced per-hex drawing of terrain fills, shadows, outlines and grass/forest/hill/water details with one viewport-scoped `MultiMeshInstance2D` batch.
- The batch uses a single compact procedural hex texture and per-instance terrain/faction tinting; visible map cells remain generated on demand.
- Removed the high-frequency per-tile CanvasItem drawing methods from the strategic map.
- Replaced repeated per-cell city ownership scans with a compact local lookup built from city claim rings.
- Added a renderer smoke test that populates 1,024 tile instances and verifies that they are submitted as one terrain batch.
- Extended the performance overlay with CPU process time, visible hex count and terrain batch count.
- Preserved map coordinates, terrain generation, player movement, AI turns, city ownership, campaign saves and the nine-kingdom simulation.
- Android device FPS and real GPU draw-call reduction still require physical validation; CI verifies the renderer's one-batch contract but cannot emulate the target phone's GPU.

## v0.10.0 — Living World & Nine AI Kingdoms

- Expanded the strategic world from the original 91-hex radius-5 map to a radius-89 hexagon containing exactly 24,031 hexes.
- Added deterministic procedural terrain lookup. Hex terrain is generated from coordinates and a persisted world seed; the game does not allocate a scene node or save record for every tile.
- Changed strategic rendering to generate and draw only the visible viewport cells. Added map navigation with one-finger drag, two-finger pan, pinch zoom, mouse-wheel zoom and keyboard panning.
- Added nine independent AI kingdoms with named rulers, capitals, cities, armies, treasuries, food, production, buildings, build queues and military objectives.
- Each campaign turn, all nine kingdoms collect city income, grow populations when food allows, progress construction, recruit role-specific troops, found additional cities when developed and move field armies.
- Added faction-coloured territory/city/army map markers and a scrollable Kingdoms overview panel.
- Tactical combat now targets whichever kingdom army the player selects; post-battle survivors, commander health and army position are written back to that kingdom.
- Added additive save fields for world seed and kingdom states without changing SAVE_VERSION or removing existing JSON keys. Older v0.9.x saves preserve the player's city, army and enemy army as the first realm, then generate the remaining eight kingdoms.
- Added CI smoke tests for exact world size, deterministic terrain, kingdom spawn safety, per-turn AI development, army aggregation and campaign save/load.
- Procedural terrain is deterministic and currently visual/strategic passability only; biome combat still uses the local terrain sample. Advanced diplomacy, treaties, siege warfare and full AI-vs-AI battles remain future work.
- Real-device performance and touch-navigation feel still require Android verification.

## v0.9.5 — Compact Mobile HUD Fix

- Replaced the permanent multi-row strategic command grid with a compact dock: Army, City, Turn and More.
- Moved Attack, New Campaign, Found City and Settings into a secondary panel that is collapsed by default.
- Reduced the strategic top status panel and clipped long status/help strings to a single line so the map remains visible.
- Replaced the permanent tactical 4×3 command grid with a compact dock: Select All, March, Pause and Commands.
- Moved selection/order/formation/retreat/speed/zoom/Battle Cry, group controls and Settings into a scrollable command drawer, collapsed by default.
- Android Back closes an open command drawer before navigating other panels.
- Preserved the existing callbacks, campaign rules, combat orders, control groups and touch target sizes.
- Added CI smoke coverage for collapsed/expanded drawers, dock height budgets and the clear central map/battlefield area.
- Physical Android testing is still required for actual touch reach, drawer scroll feel and different screen aspect ratios.

## v0.9.4 — Mobile UX Foundation (UI-1)

- Added DPI-aware `UiMetrics` with physical-pixel-to-reference-pixel dp conversion, 120–640 dpi clamping, 160 dpi fallback, live resize/UI-scale refresh and the 0.8–1.6 scale range.
- Added a resize-aware `SafeAreaContainer` and placed the strategy, battle and FPS overlay HUD roots inside safe content bounds.
- Added a shared `TouchGestureRouter` foundation for indexed touch, tap/double-tap/long-press, drag, pinch, two-finger pan and Control hit-testing. Raw touch is separated from emulated mouse input; existing Control buttons and legacy world input remain active.
- Added reusable `Haptics`, `ToastManager`/`Toast`, `ConfirmDialog`, `BottomSheet` and `IconButton` components with a starter SVG icon set.
- Connected vibration feedback to army/settler selection, orders, group recording and Battle Cry, respecting the existing vibration setting and an 80 ms rate limit.
- Added Android Back handling: closes the top modal/panel first; battle Back pauses the fight, while map Back opens the existing settings panel rather than quitting.
- Added app-background handling: the map saves its strategic state; tactical combat pauses and leaves the previous strategic checkpoint unchanged, matching the existing no-save-during-battle guard.
- Changed handheld orientation to Sensor Landscape (both landscape directions) and disabled automatic exit on Back.
- Protected New Campaign with a one-second hold confirmation; a normal tap no longer resets the campaign.
- Changed campaign persistence to write/flush/validate `.tmp`, rotate the previous valid save to `.bak`, then replace the primary. Loading can recover from `.bak` and still uses the existing `.corrupt` preservation path. JSON v1 keys are unchanged.
- Converted shared theme, settings, strategy/battle panel offsets, touch targets and FPS overlay dimensions to dp-based values.
- Added CI smoke tests for dp calculation, touch routing, UI components, destructive reset confirmation, atomic saves and backup recovery.
- Existing map/battle layouts and legacy mouse-world interactions are retained for this foundation pass; full gesture-driven HUD replacement remains UI-2/UI-3. Physical Android verification is still required.

## v0.9.3 — Combat Effects & Sound

- Connected pooled combat feedback to melee, spear, cavalry and ranged hits, projectile launches and trails, unit deaths, and the commander's Battle Cry.
- Added reusable low-poly impact sparks, cavalry charge bursts, rally pulses, death dust and bow muzzle flashes.
- Added seven original procedurally generated mono PCM sound cues: melee, spear, cavalry, bow, arrow impact, death and rally. No external audio files or licensed tracks are required.
- Scales fixed effect/audio pools by graphics quality: Low 8/4, Medium 14/6, High 18/8.
- Caches projectile mesh/material and effect meshes/materials; hit feedback reuses fixed slots rather than allocating scene nodes per strike.
- Preserves campaign saves, unit roles, damage/armor formulas, movement, formations, collision and tactical controls. The existing SFX volume setting remains in control.
- Adds CI coverage for generated sound data, quality-tier pool sizes, slot reuse and stable node budgets.
- Android sound balance, effect readability and FPS still require device validation.

## v0.9.2 — Battlefield Biomes & Terrain

- Added four tactical battlefield biomes: grassland, woodland, highlands and marsh.
- The biome is resolved from neighboring strategic hex terrain at battle start; a cell-derived seed keeps each battlefield's decorative layout repeatable.
- Added biome-specific ground textures and palettes, varied grass/stone/tree densities, fallen woodland logs, highland rock shelves, and marsh pools with reeds.
- Added the localized biome name to the tactical HUD.
- Kept the same flat ground collision bounds and unit movement plane. Terrain props remain visual-only and introduce no additional collision bodies.
- Did not change campaign save keys, unit role IDs, combat formulas, formation placement or tactical input mapping.
- Added biome smoke tests for all four profiles, deterministic resolution, resource variation, collision safety and scene-node budgets.
- Physical Android performance and visual readability across all biomes still require device validation.

## v0.9.1 — Units

- Replaced the multi-node procedural troop assembly with two merged, vertex-coloured ArrayMesh batches per team/role: a static silhouette and an animated action part.
- Added distinct low-poly headgear and role silhouettes for swordsmen, archers, spearmen, cavalry and commanders; cavalry now includes a larger horse/rider silhouette with caparison and bridle details.
- All ten team/role combinations cache their body/action meshes and share one vertex-colour material.
- Added manual idle breathing and movement sway; added role-specific sword swings, spear thrusts, bow draw/release, cavalry charge swings and commander banner raises.
- Added a short shared-material hit flash, falling death animation and 8–10 second corpse cleanup with quality-based corpse caps.
- Consolidated target/selection feedback into one cached ring. Health bars are shown only for selected, targeted or wounded units.
- Added distance/zoom-based animation LOD and extended visual tests to spawn 50 units, enforce the eight-node budget and verify mesh/material reuse.
- Existing campaign saves, unit role IDs, combat formulas, movement, formation slots, collision capsule and touch controls remain unchanged.
- Physical Android FPS, touch visibility and the feel/readability of the new animation pass remain pending device validation.

## v0.9.0 — Foundation

- Added a centralized `ArtPalette` and `ART_BIBLE.md` for the stylized low-poly fantasy direction.
- Added a shared runtime `UiTheme` for strategic and tactical screens, including panel and button states, progress bars, readable 16 px base text and minimum 48 px touch targets.
- Added `GameSettings` with independent `user://settings.cfg` persistence for graphics quality, master/music/SFX volume, UI scale, FPS overlay, vibration and camera speed. Campaign saves are untouched.
- Added three graphics-quality presets and a first-run mobile-aware quality heuristic.
- Added `PerfOverlay` for FPS, draw calls, rendered objects, primitives, node count and memory metrics where available.
- Added `VisualCache` for shared materials, primitive meshes and the battlefield ground texture. Existing procedural unit/environment builders now reuse cached resources.
- Added quality-aware battlefield decoration and shadow settings, plus Foundation tests for settings persistence, Theme construction and cache identity.
- Campaign save keys, role IDs, damage formulas, movement speed, formation slots, collision and touch-control mapping remain unchanged.
- Physical Android performance, touch response, safe-area placement and live UI scaling still require device validation.

## v0.8.0 — Visual Overhaul

- Added an illustrated hex-map renderer with layered terrain, tree silhouettes, hills, water details, miniature castles and shield/banner army markers.
- Added a procedural low-poly tactical environment with textured ground, MultiMesh vegetation and stones, forest edges, ruins, ambient lighting and directional shadows.
- Replaced capsule-only troop visuals with distinct swordsman, archer, spearman, cavalry horse-and-rider, and commander models.
- Added subtle unit idle/movement animation while keeping collision, movement, combat stats and selection on the existing BattleUnit controller.
- Updated strategy and battle panels to a dark bronze and aged-gold interface.
- Added visual-overhaul smoke tests; campaign saves, role IDs, tactical controls and campaign rules remain unchanged.

# Changelog — Project Ember

## v0.7.0 — Hero Commanders and Progression

- Added a persistent ruler hero and enemy commander to every campaign.
- Added commander combat units with their own health, level-scaled health/damage/armor, distinct 3D crown and armor visuals, and independent persistence outside the 24-troop recruitment cap.
- Added a passive commander aura that improves nearby allied damage and movement.
- Added the active **Battle Cry** ability: nearby allies receive healing and a temporary combat buff. It has a tactics-scaled cooldown and a touch-screen button plus the Q keyboard shortcut.
- Added enemy commander AI that uses Battle Cry when its nearby force is wounded.
- Added post-battle hero experience from kills, damage and victory; each level grants one skill point.
- Added Leadership, Tactics and Might skill branches, with five ranks each.
- Added commander health persistence, defeated-hero wounds and recovery over campaign turns.
- Added hero profile and skill-upgrade UI to the city panel, plus commander level and ability status in the tactical interface.
- Kept older saves compatible by supplying default hero records when hero data is absent.
- Added automated hero progression, ability, aura, wound recovery and save/load smoke tests.

## v0.6.0 — Expanded roster and battlefield command update

- Added a centralized unit catalog so economy, recruitment, campaign saves and tactical combat share one source of truth for unit data.
- Added spearmen with extra armor, longer melee reach and a damage bonus against cavalry.
- Added cavalry with higher health and movement speed plus a reusable charge strike after a fast approach.
- Added an archery range and stable as city buildings; both require completed barracks.
- Expanded army capacity from 16 to 24 units.
- Added persistent recruitment and save validation for all four unit roles while keeping old melee/ranged saves compatible.
- Updated city recruitment UI to show all roles and their specific building unlocks.
- Added cavalry wing placement and spear / sword / archer rank behavior to line, column and wedge movement orders.
- Added drag-box selection, additive selection support, four touch-screen and keyboard control groups, battlefield panning and gesture zoom.
- Added selected-army composition readout and surviving-unit composition to battle results.
- Added automated roster, unlock, recruitment, stat and save-normalization smoke tests.
- Android device testing is still required for touch gestures, UI fit and in-game balance.

## v0.5.3 — Audit fixes and strict validation

- Repaired the city production-queue summary parser error.
- Fixed the undefined recruitment label in `queue_recruit()`.
- Added explicit types where Godot 4.3 could not infer values from the campaign autoload.
- Changed the tactical scene root to Node3D to match its 3D script.
- Preserved unreadable campaign saves before starting a replacement campaign; disables automatic overwriting if preservation fails.
- Ensured newly produced settlers spawn on an in-bounds, unoccupied map hex.
- Made CI fail when Godot logs script, parse or engine errors, even if the process exits with code zero.
- Added campaign smoke tests for queueing, recruitment, army capacity, multiple-city income and save/load.
- Physical Android import, touch input and device runtime validation remain pending.

## v0.5.2 — Reliability and UI audit

- Replaced unbounded city production `while` loop with a bounded queue pass (maximum 32 orders per city turn).
- Added a defensive army-size check when completing recruitment orders.
- Repaired mojibake in campaign messages and queue labels.
- Explicitly set button focus and mouse-filter behavior in both strategic and tactical interfaces.
- Added Godot 4.3 headless import and startup checks to the packaging workflow.
- Android touch/runtime behavior still requires validation on a physical device.

## v0.5.1 — Tactical timer fix

- Fixed battle timer minute calculation to avoid integer-division warnings in GDScript.
- Explicitly typed elapsed seconds, minutes and remaining seconds; clamped negative elapsed time to zero.
- Runtime test on Godot Android Editor is still pending.

## v0.5.0 — Settlements and expansion

- Expanded the strategic map to 91 hexes and adjusted hex size for mobile viewport.
- Added up to five cities, each with independent population, food, gold, production, buildings and production queue.
- Added settler production (45 gold, 10 production, one population), movement and city founding at least three hexes from existing cities.
- Added city selection and claimed territory highlighting.
- Preserved legacy single-city save data when loading older campaigns.
- Restored tactical combat scripts and scenes in the extracted source tree.
- Runtime test on Godot Android Editor is still pending.

## v0.4.0 — First city and economy loop

- Added city resources, population, buildings, construction queue, recruitment and campaign saving.
