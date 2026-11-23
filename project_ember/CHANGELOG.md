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
