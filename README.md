# Project Ember

Current source release: **v0.17.1 — Godot 4.7.2 QA Pipeline**.

- [Project design](project_ember/DESIGN.md)
- [Art Bible](project_ember/ART_BIBLE.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [QA pipeline](project_ember/tools/qa/README.md)

The QA workflow pins the official Godot 4.7.2 editor binary, verifies its SHA-256, imports all resources, runs all GDScript smoke tests, and captures the strategic map at four zoom levels. Screenshots, render metrics and logs are uploaded as a GitHub Actions artifact. Android GPU performance still requires a physical-device report.

This is a Godot source project, not an APK.
