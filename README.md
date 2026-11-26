# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat. **Current published source line: v0.36.0 — Hero Roster, Multiple Armies & Equipment.**

- [v0.36.0 release notes](RELEASE_v0.36.0.md)
- [Published source branch](https://github.com/ilonadanelan1-code/-Project-Ember/tree/release/v0.36.0)
- [Godot 4.7.2 QA report](https://github.com/ilonadanelan1-code/-Project-Ember/actions/runs/45803647378)
- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)
- [Combat pixel-art policy](project_ember/SPRITE_ART_POLICY.md)

v0.36.0 includes the persistent hero roster, recruitable lords, multiple independently controlled player armies, per-army commanders, hero equipment and deterministic battle loot. Campaign saves remain compatible with SAVE_VERSION 1.

The public source intentionally excludes the licensed Tiny Swords runtime atlas. It is included with attribution in the separately distributed playable ZIP. Use `project_ember/tools/assets/package_playable_release.sh` to verify and package the integrated build.

The archive is a Godot source project for Android landscape, not an APK. Physical Android touch usability and GPU performance still require on-device validation.
