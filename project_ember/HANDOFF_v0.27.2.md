# Project Ember — Handoff v0.27.2

## Package

GDScript typing and warning hotfix based on v0.27.1. Godot 4.7.2 / GL Compatibility / Android landscape source project. Not an APK.

## Fixes in `scripts/campaign_state.gd`

- `_read_city_queue()`: explicit `Variant`, `Array` and `bool` typing prevents the `Cannot infer the type of "valid_province"` parser error. The validated array is reused to normalize its two coordinates.
- `_make_city_record()`: parameter `name` renamed to `city_display_name` to avoid shadowing `Node.name`.
- `get_world_owner_at()`: local names changed to `player_city_hex` and `kingdom_city_hex` to avoid shadowing the class property and each other.
- `get_city_owner_at()` and `can_found_city()`: duplicated cube-coordinate arithmetic replaced with `WorldGeneratorScript.hex_distance()`.

No gameplay values, resource/building/unit IDs, JSON keys or save schema changed. Save schema remains version 1.

## Validation

- Static QA: 117/117 passed, including regression guards for all reported issues.
- Python static validator syntax check passed.
- Godot 4.7.2 parser/import, runtime smoke tests and Android validation are pending because the Godot executable is unavailable in the build container. Do not interpret static QA as a Godot compile result.
- 29 GDScript smoke-test sources are included; they were not executed here.

## Install

1. Extract this ZIP into a new folder; keep v0.27.1 as a backup.
2. Open `project.godot` in Godot 4.7.2.
3. Allow imports to finish and check the Output panel for errors/warnings in `campaign_state.gd`.
4. Load a copy of an existing campaign and confirm city/province build queues load, then save and reload.
