# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat. Current source build: **v0.30.0 — Campaign Victory** (development branch based on v0.29.0 Diplomacy Expansion).

- [Design source of truth](project_ember/DESIGN.md)
- [Campaign victory rules and save fields](project_ember/CAMPAIGN_VICTORY.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)

## v0.30.0 — Campaign Victory

Adds three independent campaign goals: military, economic and diplomatic. Progress is calculated from unique kingdom victories, player city economies, army upkeep and active diplomacy agreements. The player can finish the campaign or continue in freeplay. Old v0.29.0 saves use safe default victory fields; `SAVE_VERSION` remains 1.

The archive is a Godot source project, not an APK. It targets Godot 4.7.2 stable with GL Compatibility. Import and test it in Godot Android Editor before replacing a previous working build. The new victory smoke test is included; parser/runtime and physical Android checks must pass before treating this development build as device-verified.
