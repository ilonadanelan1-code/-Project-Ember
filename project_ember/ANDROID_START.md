# Android Start — Project Ember v0.5.2

1. Extract the `project_ember` folder on Android.
2. Open Godot Android Editor and import `project_ember/project.godot`.
3. Wait for import, then press Play.

## Expansion loop

1. Open the capital city.
2. Queue a settler (45 gold, 10 production, one population).
3. End turns until the settler is ready.
4. Tap the settler marker to select it.
5. Tap adjacent passable land hexes to move it; one move is available each turn.
6. Move at least three hexes from any existing city.
7. Press `ОСНОВАТЬ ГОРОД`.
8. Tap either city to select it. Each city has its own resources, buildings and production queue.

## Test status

Source files were checked statically. Godot runtime validation on an Android device is still pending. Keep the original v0.4.0 ZIP backup until v0.5.2 has been tested.
