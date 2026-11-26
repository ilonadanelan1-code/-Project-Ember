# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat.

## Current project status — 2026-11-26

- **Latest audited playable build:** Project Ember v0.38.2
- **Engine:** Godot 4.7.2
- **Next development target:** v0.39 — Strategic AI and diplomacy
- **Current source branch:** [`release/v0.38.2-godot-audited`](https://github.com/ilonadanelan1-code/-Project-Ember/tree/release/v0.38.2-godot-audited)
- **Current source commit at import:** `23c0d5c4580b4d5058579e8a0fb71e090ee2032a`
- **Playable archive:** [GitHub Release v0.38.2](https://github.com/ilonadanelan1-code/-Project-Ember/releases/tag/v0.38.2)
- Dedicated GitHub Godot 4.7.2 QA is running on the imported source branch; see the [workflow run](https://github.com/ilonadanelan1-code/-Project-Ember/actions/runs/45845972194).

### Current handoff and audit

- [Current development handoff](PROJECT_EMBER_CURRENT_HANDOFF.md)
- [Godot 4.7.2 audit report for v0.38.2](QA_AUDIT_v0.38.2.md)
- [Importer workflow for the v0.38.2 release archive](.github/workflows/import-v0382-release.yml)

### Verified v0.38.2 results

- Godot editor import: passed
- GDScript parser: 91/91
- Runtime smoke tests: 37/37 (1,452 PASS assertions)
- Static QA: 233/233
- Strategic AI peaceful expansion regression: 180 turns passed
- Strategic map visual captures: 4/4

The visual QA uses Linux software rendering and does not replace Android device testing. Android FPS, touch controls and long-session stability remain to be verified on-device.

### Licensing

The playable archive includes the Tiny Swords combat atlas supplied for the user's project. Keep licensed atlas binaries and their animation manifest out of the public source repository; include them only in the playable ZIP according to the asset license and project policy.

The project archive is a Godot source project, not an APK.
