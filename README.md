# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat. Current source release: **v0.33.1 — Pixel Art Restoration & Release Guard**.

- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)
- [World exploration and neutral-site rules](project_ember/WORLD_EXPLORATION.md)
- [Territorial control and frontier fortifications](project_ember/TERRITORIAL_CONTROL.md)
- [Combat pixel-art policy](project_ember/SPRITE_ART_POLICY.md)

The current release adds deterministic territorial influence, disputed borders, frontier watchtowers, settlement restrictions and tactical fortification bonuses. Godot 4.7.2 CI validates project import, all GDScript sources, campaign smoke tests and strategic-map visual captures.

The archive is a Godot source project, not an APK. Test Android device performance separately in Godot Android Editor before replacing a previous working ZIP.

Combat presentation has a non-negotiable pixel-art requirement. The public source intentionally excludes the licensed Tiny Swords runtime atlas; every playable ZIP includes it. Use `project_ember/tools/assets/package_playable_release.sh` to validate and package a playable release. Source-only CI deliberately skips playable artifacts when the atlas is missing.
