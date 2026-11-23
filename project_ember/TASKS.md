# Project Ember — Tasks

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
- [ ] Add battlefield terrain modifiers and map-to-battlefield terrain transfer.
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
