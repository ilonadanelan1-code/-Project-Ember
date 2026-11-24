# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat.

Current source release: **v0.9.4 — Mobile UX Foundation (UI-1)**.

- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Visual overhaul notes](project_ember/VISUAL_OVERHAUL.md)
- [Art Bible](project_ember/ART_BIBLE.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)

v0.9.4 adds the UI-1 mobile foundation: DPI-aware dp metrics, live safe-area handling, indexed multitouch routing, haptics/toasts/confirmation and bottom-sheet/icon components, Android Back/background handling, Sensor Landscape and atomic campaign save recovery. The existing JSON v1 campaign schema and combat/campaign rules are preserved. The legacy battle/map layouts and world input remain in place for this foundation pass; their full mobile redesign and gesture commands are the next UI-2/UI-3 stages. The package also contains v0.9.3 combat effects/sound, four tactical biomes and merged role-specific unit visuals.

The archive is a Godot source project, not an APK. Import `project_ember/project.godot` in Godot 4.3 Android Editor.
