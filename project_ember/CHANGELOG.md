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
