# Project Ember — Tasks

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

- [ ] Add recruitable lords and allow heroes to be assigned to multiple armies.
- [ ] Add equipment slots and loot rewards for heroes.
- [ ] Add gameplay terrain modifiers for elevation, water, cover and movement; current biome dressing is visual-only.
- [ ] Add an auto-battle estimator using the same unit catalog and role matchups.
- [ ] Add neutral camps and resource sites to the strategic map.
- [ ] Add city list and quick switching between founded cities.
- [ ] Add roads, trade routes and AI settlement expansion.

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
