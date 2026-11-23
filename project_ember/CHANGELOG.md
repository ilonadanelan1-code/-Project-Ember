# Changelog — Project Ember

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

# Changelog — Project Ember

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
