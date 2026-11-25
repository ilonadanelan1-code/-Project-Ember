# Project Ember — Handoff v0.27.1

## Package

Campaign-loading hotfix based on v0.27.0 World Exploration & Neutral Sites. Godot 4.7.2 / GL Compatibility / Android landscape source project. Not an APK.

## Fix

- In `scripts/campaign_state.gd`, `load_campaign()` first declares `loaded_buildings` for the legacy capital.
- The loop loading additional cities previously declared another local with the same name, causing: `There is already a variable named "loaded_buildings" declared in this scope`.
- The second local is now `city_buildings_data` and is passed to `_make_city_record()`.
- No gameplay logic, city data, serialization fields or save schema changed.

## Validation

- Static QA: 113/113 passed, including a dedicated guard for this regression.
- Python static validator syntax check passed.
- Godot 4.7.2 parser/import and Android runtime validation remain pending because Godot is unavailable in the build container.
- Save schema remains version 1.

## Install

1. Extract this ZIP into a new folder, rather than overwriting the prior copy.
2. Open `project.godot` in Godot 4.7.2.
3. Let imports finish and check the Output panel for parser errors.
4. Load a copy of the existing campaign and confirm all cities/buildings load as before.
