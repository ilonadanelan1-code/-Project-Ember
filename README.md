# Project Ember — v0.18.1 QA

Source project: **Project Ember v0.18.1 — Hex Terrain API Fix**.

- Godot project: `project_ember/`
- Android import guide: `project_ember/ANDROID_START.md`
- Hex Terrain Bundle and license: `project_ember/assets/hex_terrain/`
- QA scripts and smoke tests: `project_ember/tools/qa/` and `project_ember/tests/`

The dedicated QA workflow imports the project with official Godot 4.7.2, parses GDScript, runs smoke tests, and captures the strategy map at four zoom levels using Mesa software OpenGL. Android device GPU performance still requires a report from the physical device.

This is a Godot source project, not an APK. The QA branch does not modify `main`.
