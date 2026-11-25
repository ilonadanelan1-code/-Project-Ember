# Project Ember — Handoff v0.27.0

## Package

Project Ember v0.27.0 — World Exploration & Neutral Sites, based on v0.26.0 City Development & Economy. Godot 4.7.2 stable, GL Compatibility, Android landscape source project. This ZIP is a Godot source project, not an APK.

## Implemented

- `scripts/world_location_catalog.gd`: deterministic catalog of up to 72 POIs, minimum distance 5, at least four opening targets in the start ring, five terrain-compatible location types, three guard tiers, reward tables and save normalization.
- `scripts/world_event_catalog.gd`: six deterministic campaign events every five turns, exactly two choices each.
- `campaign_state.gd`: persistent neutral battles, guardian health and guard survivor state, nearest-city rewards, event validation/effects and additive save fields.
- `strategy_map.gd`: fog-of-war-aware markers, tap-to-approach/engage behavior and a two-button event panel.
- `kingdom_ai.gd`: AI settlement and next-step army movement avoid POI hexes. AI neutral-site battles are intentionally deferred.
- Cleared sites remain as map history when the victorious player army occupies the same hex.

## Location values

- Maximum locations: 72.
- Minimum spacing: 5 hexes.
- Opening start ring: 4–13 hexes from initial army, with at least four available targets.
- Exclusion: within 3 hexes of player starting city or AI capital.
- Guard tier: 3 / 5 / 8 troops, XP 0 / 20 / 45, guardian current HP 95 / 125 / 155 (max 210).
- Reward multiplier: ×1.0 / ×1.5 / ×2.0. Each reward uses only gold, food and stored production and is paid into the nearest player city.
- Site victory clears the location; defeat persists surviving guard units and guardian health for a rematch.

## Campaign events

- Cadence: each fifth turn, one pending event at a time.
- Events: merchant caravan, refugees, scout report, abandoned wagon, veteran instructor and workshop wagon.
- Two choices per event; cost and population validations occur before the choice is enabled.
- Event effects use existing resources, population, map exploration and troop XP only. No mana, wood, stone or other fourth resource.

## Compatibility

- Existing resource, building and unit role IDs remain unchanged.
- Army cap remains 24; commanders remain outside the troop cap.
- Save schema remains version 1.
- Old saves without POI fields regenerate neutral sites from their world seed/generation version and initialize no pending event, empty last-event text and zero event count.
- Cleared sites may share the player's occupied hex as inert history; uncleared sites on occupied legacy hexes are filtered.

## QA status

- Static validation: 112/112.
- Python static QA syntax validation passed.
- 29 `*_smoke_test.gd` source files are present; the new world-location and world-event tests are included but were not executed here.
- Godot 4.7.2 parser/import/runtime tests and Android UI/device/FPS checks remain pending because no Godot executable is available in the build environment.

## Suggested phone validation

1. Open `project.godot` in Godot 4.7.2 Android Editor and import the project.
2. Create a new campaign and explore until four nearby points of interest are visible.
3. Note the location type and reward estimate; stand adjacent and tap the POI to open combat.
4. Win one encounter and confirm the location is marked cleared and its reward reaches the nearest city.
5. Lose another encounter and confirm surviving guards and guardian health remain for a rematch.
6. End turns through turn 5, resolve the event and test both options in the abandoned wagon event when its seed-cycle event appears.
7. Test the refugee choice with a city at population 20; the option should be disabled and food unchanged.
8. Save/reload after a cleared location, an unresolved event and a partially defeated location; verify the state persists.
9. Confirm AI armies/city founders do not select POI cells and watch performance while panning/zooming the explored map.
