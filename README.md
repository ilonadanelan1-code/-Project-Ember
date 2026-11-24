# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat.

Current source release: **v0.9.5 — Compact Mobile HUD Fix**.

- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Visual overhaul notes](project_ember/VISUAL_OVERHAUL.md)
- [Art Bible](project_ember/ART_BIBLE.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)

v0.9.5 repairs the mobile HUD layout: map and battle screens now show a compact quick-action dock by default, while secondary commands open in a separate scrollable drawer. The battlefield/map is no longer covered by a permanent multi-row button grid. v0.9.4 mobile foundations remain included: DPI-aware metrics, safe-area handling, multitouch routing, haptics, Android lifecycle/Back handling and atomic save recovery. Campaign schema and combat rules are preserved. The package also includes combat effects/sound, four tactical biomes and role-specific unit visuals.

The archive is a Godot source project, not an APK. Import `project_ember/project.godot` in Godot 4.3 Android Editor.
