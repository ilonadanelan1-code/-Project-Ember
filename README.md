# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat.

Current source release: **v0.10.0 — Living World**.

- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Visual overhaul notes](project_ember/VISUAL_OVERHAUL.md)
- [Art Bible](project_ember/ART_BIBLE.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)

v0.10.0 expands the strategic world to 24,031 hexes (hex radius 89) using deterministic on-demand terrain generation and viewport-only drawing. Nine independent AI kingdoms begin in the world with their own capitals, cities, armies, resources and rulers. On each campaign turn they collect income, progress construction queues, recruit troops, expand settlements and move their armies toward strategic objectives. The kingdom roster and world seed are persisted in the existing save format; old v0.9.x campaigns keep the player's capital and army while receiving the new realms. Map navigation supports one-finger drag, two-finger pan and pinch zoom. The compact v0.9.5 mobile HUD and all prior combat, biome, unit and save foundations remain included.

The archive is a Godot source project, not an APK. Import `project_ember/project.godot` in Godot 4.3 Android Editor.
