# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat.

Current source release: **v0.10.1 — Render Batch Performance**.

- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Visual overhaul notes](project_ember/VISUAL_OVERHAUL.md)
- [Art Bible](project_ember/ART_BIBLE.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)

v0.10.1 addresses the severe strategic-map render bottleneck reported on Android. The thousands of visible hex tiles are now drawn through a single MultiMeshInstance2D terrain batch instead of per-cell polygon, outline, shadow, grass, tree, hill and water commands. Terrain ownership is resolved through a compact city-claim lookup. The performance overlay now reports CPU frame time, visible hex count and terrain batch count. The 24,031-hex procedural world, nine autonomous AI kingdoms, save migration and mobile map controls remain included.

The archive is a Godot source project, not an APK. Import `project_ember/project.godot` in Godot 4.3 Android Editor.
