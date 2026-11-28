# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat.

**Published baseline:** v0.38.2 — Godot 4.7.2 audited build.  
**Current development:** v0.39.0-dev on `feature/v0.39-diplomacy-personalities`; draft [PR #9](https://github.com/ilonadanelan1-code/-Project-Ember/pull/9). This development branch is not merged or released.

- [Published audited source branch](https://github.com/ilonadanelan1-code/-Project-Ember/tree/release/v0.38.2-godot-audited)
- [v0.39.0-dev changes and review](https://github.com/ilonadanelan1-code/-Project-Ember/pull/9)
- [Latest Godot 4.7.2 QA run](https://github.com/ilonadanelan1-code/-Project-Ember/actions/runs/45904957409)
- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)
- [Combat pixel-art policy](project_ember/SPRITE_ART_POLICY.md)
- [Development changelog](project_ember/CHANGELOG.md)
- [Development task list](project_ember/TASKS.md)

v0.39.0-dev adds the diplomatic leader profiles, casus belli and allied war calls, arcane victory race and containment, relationship memory and gifts, containment coalitions, battle forecast, quick city switching, internal trade routes, peace-time defensive readiness, and integrated pixel-art visual atlas.

The campaign save version remains `SAVE_VERSION = 1`. The current CI run passed Godot 4.7.2 import, project-context GDScript parsing, smoke tests, and four strategic-map visual captures. Android touch behavior, on-device FPS, and long-session stability remain unverified and must be checked on the target phone before release.

The public source intentionally excludes the licensed Tiny Swords runtime atlas. Packaging restores the audited asset from the published v0.38.2 release and verifies its checksum. Use `project_ember/tools/assets/package_playable_release.sh` to build a complete playable Godot source ZIP. The archive is not an APK.
