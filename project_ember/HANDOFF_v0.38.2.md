# Project Ember — handoff for the next chat

## Current audited build

- Version: **v0.38.2 — Godot Audit Hotfix**
- User-provided baseline: `Project-Ember-v0.38.1-AI-Expansion-Fix.zip`
- Engine: Godot `4.7.2.stable.official.ed1daf0bf`, Linux x86_64
- Save schema: `SAVE_VERSION = 1`
- Target: Android, landscape, GL Compatibility

## Project / GitHub identity

- Repository: `ilonadanelan1-code/-Project-Ember`
- URL: https://github.com/ilonadanelan1-code/-Project-Ember
- Upstream game branch used by the supplied build metadata: `release/v0.36.1`
- Upstream base commit: `5ddd271c3ccda799e9db681680f59bd8bdb9e2da`

**Publishing status:** v0.38.2 has been audited and packaged in the current conversation. The public GitHub repository still does not contain the complete v0.38.2 project source snapshot. The uploaded ZIP includes licensed Tiny Swords sprite binaries, which must remain outside the public source repository. Do not represent the full playable ZIP as published until the repository import is actually completed.

## Major implemented systems

- City and outpost foundation with different costs and placement rules.
- Outpost stock, income/upkeep, stock collection, annexation into a city and conversion into a full city.
- Dynamic influence ordering: city > outpost > field army; ownership is computed from source records, not a persistent owner grid.
- Economy aggregation and upkeep for cities, outposts and armies.
- AI city/outpost expansion, reserve protection and annexation.
- AI diplomacy and wars, neutral-site expeditions, campaign events, faction selection, lords, hero equipment, army progression and tactical combat.

## Verified by Godot 4.7.2

- Editor import: passed.
- GDScript parser: 91 / 91, no errors.
- Smoke suites: 37 / 37, 1,452 PASS assertions.
- Strategic AI smoke test includes a 180-turn peaceful simulation with new cities across multiple kingdoms.
- Visual capture: 4 / 4 map zoom levels pass with software rendering at 1280x720.
- Static QA: 233 / 233.
- Playable ZIP: archive integrity and required combat atlas validation passed.

Android hardware performance and input still require the user's device check.

## Next development target

Continue with **v0.39 — strategic AI and diplomacy depth**. Review the existing AI planner and diplomacy system before editing. Priority: make kingdom-level decisions coherent over many turns (threat evaluation, expansion priorities, war readiness, border protection, alliance/truce decisions) without destabilizing economy or save compatibility. Keep `SAVE_VERSION = 1` unless a schema bump becomes unavoidable and justified.

## Working agreement

1. Read the latest repository state and this handoff before editing.
2. Treat the user's latest tested ZIP as the reference for the active build; do not silently replace it with an older branch snapshot.
3. Use Godot 4.7.2 headless parser + all smoke tests after code changes; run visual map QA when UI/rendering changes.
4. Keep public GitHub source free of the licensed Tiny Swords atlas and `atlas_manifest.json`; the user's playable ZIP must retain them.
5. Deliver a complete playable ZIP after each release-sized milestone, not scattered patches.
6. When the full source snapshot is imported to GitHub, update the version pointer and this handoff with the real branch and commit SHA.
