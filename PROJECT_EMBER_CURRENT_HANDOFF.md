# Project Ember — current handoff

Last audited working build: **v0.38.2 — Godot Audit Hotfix** (2026-11-26).

## Repository
- Repository: https://github.com/ilonadanelan1-code/-Project-Ember
- Default branch: `main`
- Upstream baseline: `release/v0.36.1`, commit `5ddd271c3ccda799e9db681680f59bd8bdb9e2da`
- **Current imported source branch:** `release/v0.38.2-godot-audited`
- **Current source commit:** `23c0d5c4580b4d5058579e8a0fb71e090ee2032a`
- Import metadata follow-up commit: `803f0dd58083df95e5ea6c421bb062f13394ec84`
- Latest CI workflow-only commits after import are recorded in the source branch history.

## Important publishing status
The full playable v0.38.2 ZIP is published as GitHub Release asset [`Project-Ember-v0.38.2-Godot-Audited.zip`](https://github.com/ilonadanelan1-code/-Project-Ember/releases/download/v0.38.2/Project-Ember-v0.38.2-Godot-Audited.zip). The source-only project snapshot has been imported to [`release/v0.38.2-godot-audited`](https://github.com/ilonadanelan1-code/-Project-Ember/tree/release/v0.38.2-godot-audited). The importer workflow completed successfully, including archive verification, source extraction and static validation.

The first post-import Godot QA run exposed a CI script permission issue, and the old package workflow assumed the licensed atlas existed in source. Both workflow defects were corrected in the release branch: smoke tests are called via bash, packaging now uses Godot 4.7.2, and the atlas/manifest are restored from the release ZIP in the temporary CI workspace only (not committed to the public source). The updated package workflow completed successfully and uploaded complete playable artifacts. The latest dedicated Godot 4.7.2 QA run is **currently in progress**: https://github.com/ilonadanelan1-code/-Project-Ember/actions/runs/45845170388. Recheck this run before starting new work.

The user-provided playable ZIP contains the Tiny Swords combat atlas and animation manifest. The project policy excludes those licensed binaries from the public source repository; they remain in the playable ZIP.

## Verified v0.38.2
- Engine: Godot 4.7.2.stable.official.ed1daf0bf, Linux x86_64.
- Editor import: passed, no script/resource load errors.
- Project-context GDScript parser: 91/91.
- Runtime smoke suites: 37/37, with 1,452 PASS assertions.
- Strategic AI regression: peaceful 180-turn multi-kingdom test passed; additional cities were created across several AI kingdoms.
- Visual QA: 4/4 strategic-map zoom captures passed at 1280x720 using Xvfb + Mesa llvmpipe software rendering.
- Python static QA: 233/233.
- Playable package ZIP integrity and 1152x2304 RGBA Tiny Swords atlas/24-animation manifest checks: passed.
- Android device FPS, touch controls and long-session stability still need user-side testing.

## v0.38.2 audit fixes
1. Fixed a missing comment marker in `scripts/kingdom_ai.gd` that caused a real GDScript parse failure.
2. Added an explicit `Array[Dictionary]` type to the fallback kingdom list in `scripts/campaign_state.gd`.
3. Fixed the city-foundation smoke fixture to replenish its test treasury/production before the foundation check.
4. Fixed the settlement economy smoke test to use a save-enabled campaign for save/load.
5. Fixed the territory test fixture so the AI kingdom appears at the correct kingdom index.
6. Replaced stale v0.31.0 package/import metadata.

## Implemented gameplay
- City/outpost foundation and separate outpost records.
- Outpost stock, income/upkeep, collection, annexation into nearby city and conversion into a full city.
- Influence order city > outpost > field army; ownership is calculated from live influence sources.
- Economy and upkeep accounting for settlements and armies.
- AI city/outpost expansion and annexation; long peaceful expansion is now regression-tested.
- Existing diplomacy, wars, neutral expeditions, events, factions, heroes/equipment, army progression and tactical combat retained.
- `SAVE_VERSION` remains 1.

## Next development target
Proceed with **v0.39 — deeper strategic AI and diplomacy**. Review the AI planner and diplomacy system before changing them. Improve long-term realm decisions, threat evaluation, border protection, expansion priorities, war readiness and treaty choices without destabilizing the economy or save compatibility.

## Working rules
- Start by reading the latest repository state and this handoff.
- Treat the v0.38.2 playable archive as the latest audited baseline until its source snapshot is imported to GitHub.
- Use Godot 4.7.2 parser + all 37 smoke suites after code changes; run visual capture QA for map/UI rendering changes.
- Keep licensed Tiny Swords binaries out of public source; keep them in the player's playable ZIP.
- Deliver full playable ZIPs for release-sized milestones, not scattered patches.
- Once source import is complete, update this handoff with the actual release branch and commit SHA.
