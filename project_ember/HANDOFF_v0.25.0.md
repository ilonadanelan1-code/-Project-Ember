# Project Ember — Handoff v0.25.0

## Package

Project Ember v0.25.0 — Army Veterancy & Upgrades, based on v0.24.1 Tactical Combat Expansion. Godot 4.7.2 stable, GL Compatibility, Android-oriented source project. This ZIP is a Godot project, not an APK.

## Implemented

- Every surviving non-commander troop gains individual XP at battle end.
- Veterancy ranks: Recruit 0, Trained 40, Veteran 100, Elite 180 cumulative XP.
- Bonuses: none, +3% damage, +6% damage/+1 armour, +10% damage/+2 armour.
- City Military Training grid: two rank upgrades for each role, paid in gold and gated by existing barracks/archery_range/stable.
- Battle result reports survivor XP and promotion count.
- AI survivors gain XP using the same formula; kingdom normalization preserves it.
- New detailed rules and balance values are in ARMY_PROGRESSION.md.

## Compatibility

- Role IDs remain `melee`, `ranged`, `spear`, `cavalry`.
- The 24-troop cap and separate commanders are unchanged.
- Save schema remains version 1. Missing unit XP defaults to zero; missing `army_upgrades` defaults to four zero ranks.
- Upgrade ranks are empire-wide for the player and apply when a unit next spawns into battle.
- No new resource or building ID is added.

## Validation status

- Static validation: 78/78 passed.
- Python static QA script passes `py_compile`.
- 26 smoke-test source files included; new unit progression test is registered by the existing wildcard QA runner.
- Godot 4.7.2 parser/import and runtime smoke tests were not run because the engine executable is unavailable in this build environment.
- Android on-device save/load, city UI layout, combat balance and GPU/FPS checks remain pending.

## Next phone check

Open `project.godot` in Godot 4.7.2 Android Editor and import resources. Load a copy of a v0.24.1 campaign. Fight a battle and verify XP appears for surviving troops; open the city and inspect the rank counts and four Military Training buttons. Build each required building, purchase a role upgrade, fight again, then save/reload and confirm that individual XP and all upgrade ranks persist.
