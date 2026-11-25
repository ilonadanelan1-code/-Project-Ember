# Project Ember — Handoff v0.24.1

## Package

Project Ember v0.24.1 — Tactical Combat Expansion, based on v0.22.0 Strategy & UI Icon Integration. Godot 4.7.2 stable, GL Compatibility, Android-oriented source project. This ZIP is a Godot project, not an APK.

## Implemented

- Deterministic non-colliding terrain zones for woodland, highlands and marsh battles; grassland remains neutral.
- Local movement and ranged-damage modifiers; marsh disables cavalry charge.
- Side/rear flanking bonuses, exposed status, temporary overhead marker and the frontal HOLD armour bonus.
- Role-aware automatic target acquisition for the existing five battle roles.
- Flank-hit totals in the tactical results and the existing last_battle_result dictionary.
- Added three smoke-test sources and expanded static validation.

## Compatibility

- Campaign IDs and role IDs are untouched.
- No new stock, city economy field or campaign save-schema version is introduced.
- Tactical zone positions are recreated from the existing biome ID and battle seed; they are not saved.
- Exposed timers, facing vectors and per-unit flank counters are transient battle state.
- Added battle-result keys are additive dictionary values; old saves default to an empty last_battle_result dictionary.
- The existing flat collider, movement plane, unit collision capsules and formation slots remain unchanged.

## Validation status

- Static validation: 70/70 passed.
- 25 smoke-test source files are included. Three new tests cover terrain modifiers, flank/status values and AI target scoring.
- Godot 4.7.2 import/parser and runtime smoke tests were not run because the engine executable is unavailable in this build environment.
- Android GPU/FPS, texture import, touch UX and visual checks remain pending.

## Next phone check

Open this folder's `project.godot` in Godot 4.7.2 Android Editor, import resources, run the built-in QA tests if available, then start/load a campaign and enter woodland, highland and marsh battles. Check movement and ranged damage inside marked zones, cavalry charge in marsh, rear/side attacks, the exposed marker, HOLD defence and battle-result flank statistics.
