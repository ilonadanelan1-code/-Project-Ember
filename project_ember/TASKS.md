# Project Ember — Tasks

## v0.6.0 — Expanded roster and battlefield commands

- [x] Centralize role data for city, save validation and tactical combat.
- [x] Add spearmen and cavalry as distinct roles.
- [x] Add archery range and stable recruitment unlocks.
- [x] Increase army capacity to 24.
- [x] Add role-aware placement for line, column and wedge orders.
- [x] Add drag-box selection and touch-screen / keyboard control groups.
- [x] Add tactical camera pan and gesture zoom input.
- [x] Add automated tests for role unlocks, recruitment and combat profiles.
- [ ] Validate touch gestures and drag selection in Godot Android Editor.
- [ ] Balance new unit costs, armor, reach and charge damage during real battles.
- [ ] Verify city panel layout on portrait and landscape phone screens.

## Next gameplay targets

- [ ] Add hero / commander data and connect hero bonuses to tactical armies.
- [ ] Add battle terrain modifiers and map-to-battlefield terrain transfer.
- [ ] Add an auto-battle estimator using the same unit catalog and role matchups.
- [ ] Add neutral camps and resource sites to the strategic map.
- [ ] Add city list and quick switching between founded cities.
- [ ] Add roads, trade routes and AI settlement expansion.

## Previous v0.5.3 audit status

- [x] Fixed GDScript parser error in the city production queue summary.
- [x] Fixed recruitment queue message referencing an undefined variable.
- [x] Added explicit GDScript types for Godot 4.3 inference failures.
- [x] Matched the tactical scene root type to its Node3D script.
- [x] Preserved unreadable saves before creating replacement data.
- [x] Added in-bounds settler spawn selection for cities founded near the map edge.
- [x] Made Godot log errors fail CI validation.
- [x] Added automated campaign logic smoke tests.
- [ ] Import and run in Godot Android Editor.
- [ ] Verify touch controls and UI scaling on a physical Android device.