# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat. **Current published source line: v0.36.1 — Map Motion Performance Hotfix.**

- [v0.36.1 release notes](RELEASE_v0.36.1.md)
- [Published source branch](https://github.com/ilonadanelan1-code/-Project-Ember/tree/release/v0.36.1)
- [Godot 4.7.2 QA run](https://github.com/ilonadanelan1-code/-Project-Ember/actions/runs/45811713663)
- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)
- [Combat pixel-art policy](project_ember/SPRITE_ART_POLICY.md)

v0.36.1 is based on v0.36.0 and adds a motion-aware map rendering mode. It keeps terrain, fog of war and key army/city markers active while deferring costly cartographic details during camera movement. Full detail returns after the camera settles. Campaign rules and SAVE_VERSION 1 are unchanged.

The public source intentionally excludes the licensed Tiny Swords runtime atlas. It is included with attribution in the separately distributed playable ZIP. Use `project_ember/tools/assets/package_playable_release.sh` to verify and package the integrated build.

The archive is a Godot source project for Android landscape, not an APK. The FPS improvement must be verified on the target Android device with a fresh in-game performance report.
