# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat.

Current source release: **v0.9.4 — Mobile UX Foundation (UI-1)**.

- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Visual overhaul notes](project_ember/VISUAL_OVERHAUL.md)
- [Art Bible](project_ember/ART_BIBLE.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)

v0.9.3 connects pooled hit sparks, cavalry charge bursts, commander rally pulses, death dust, muzzle flashes and projectile trails to combat events. Seven original procedural sound cues play through the existing SFX settings. Effect/audio pools scale with graphics quality and reuse fixed nodes (8/4 on Low, 14/6 on Medium, 18/8 on High). This release also includes four deterministic battlefield biomes, merged role-specific unit visuals and the Foundation settings/cache work. Campaign saves, role IDs, combat formulas, collision and tactical input remain compatible with earlier releases.

The archive is a Godot source project, not an APK. Import `project_ember/project.godot` in Godot 4.3 Android Editor.
