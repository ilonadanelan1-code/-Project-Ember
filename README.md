# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat.

Current source release: **v0.9.2 — Battlefield Biomes & Terrain**.

- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Visual overhaul notes](project_ember/VISUAL_OVERHAUL.md)
- [Art Bible](project_ember/ART_BIBLE.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)

v0.9.2 adds four tactical battlefield biomes selected from the neighboring strategic hex terrain, with deterministic ground palettes/textures, woodland logs, highland rock shelves, and marsh pools/reeds. Biome props are visual-only; the original flat battlefield collision and unit movement remain unchanged. It also includes the v0.9.1 two-batch unit visuals, shared resources, role-specific animations and the 50-unit node-budget test. Campaign saves, role IDs, combat formulas, collision and tactical input remain compatible with earlier releases.

The archive is a Godot source project, not an APK. Import `project_ember/project.godot` in Godot 4.3 Android Editor.
