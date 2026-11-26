# Project Ember v0.36.1

**Map Motion Performance Hotfix**

## Published source

- Branch: https://github.com/ilonadanelan1-code/-Project-Ember/tree/release/v0.36.1
- Godot 4.7.2 QA: https://github.com/ilonadanelan1-code/-Project-Ember/actions/runs/45811713663

## Performance changes

- Adds a low-cost map rendering mode during continuous camera movement.
- Keeps terrain, fog-of-war visibility, settlement markers, army markers and selected-army movement indicators active.
- Defers territory ownership lookup, borders, roads, coastlines, province improvements, neutral-site details and city labels until 160 ms after the last pan/zoom input.
- Restores all map detail automatically after the camera settles.
- Does not change campaign simulation, combat, army movement, hero equipment, or saved data. SAVE_VERSION remains 1.

## Baseline report

The Android report supplied for v0.36.0 showed 32.3 average FPS over 10 seconds, with a 10 FPS minimum while moving the map. Static-map FPS was reported at approximately 60. The implementation specifically reduces work during the continuous redraws that occur while the camera moves.

## Validation status

The source branch is submitted to the Godot 4.7.2 import, parser, smoke-test and visual-capture workflow. A passing headless workflow verifies script/resource integrity but cannot measure Android GPU performance.

**Physical-device validation is still required.** Capture a new 10-second in-game performance report while dragging the map at the same zoom and viewport. The actual FPS gain is not claimed until that measurement is available.

## Distribution

This is a Godot source project targeting Android landscape, not an APK. Public source excludes the licensed Tiny Swords runtime atlas; the integrated atlas remains part of the separately distributed playable ZIP.
