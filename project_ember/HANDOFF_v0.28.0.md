# Project Ember — Handoff v0.28.0

## Current package
- Version: v0.28.0 — Faction Founding & Kingdom Identity
- Base: v0.27.2 GDScript Hotfix
- Engine target: Godot 4.7.2 / GL Compatibility
- Platform: Android landscape
- Save schema: 1

## Implemented
- `scripts/faction_catalog.gd` contains four peoples, four cultures and six traits. Exactly two distinct traits are required.
- `scripts/campaign_state.gd` stores the player selection, gates new campaigns until confirmation, applies one-time start bonuses and applies effects to income, recruitment, upkeep, vision and province capacity.
- `scripts/kingdom_ai.gd` assigns deterministic factions to all nine AI kingdoms, gives equivalent one-time bonuses to new AI starts and uses faction-aware city income, recruit prices and upkeep.
- `scripts/strategy_map.gd` includes the new faction-foundation panel, editable kingdom name, effect preview and a scrollable content area with a fixed bottom confirmation button. Map commands remain hidden until confirmation.
- `tests/faction_setup_smoke_test.gd` covers catalog cardinality, effect stacking, recruitment/upkeep multipliers, player confirmation, prevention of double bonuses, AI identities and AI starting bonuses.

## Compatibility
- `SAVE_VERSION` remains 1.
- `player_faction` is optional; old player saves load as neutral `legacy`.
- `kingdoms[].faction` is normalized from the deterministic fallback kingdom record when absent. No one-time bonus is retroactively granted to an old save.
- Unit roles `melee`, `ranged`, `spear`, `cavalry`, building IDs and resource IDs are unchanged.

## Validation boundary
- Static QA: 140/140.
- Python QA validator syntax check passes.
- GDScript smoke-test source is included but not executed.
- Godot 4.7.2 parser/import, project run, save/load play test and Android touch/FPS validation still need to be performed on a machine/device with Godot installed.

## Next roadmap step
- G — Diplomacy and AI kingdoms: relations, personality weights, peace/trade/alliance/tribute, war reasons and war-weariness.
