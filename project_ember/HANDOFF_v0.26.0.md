# Project Ember — Handoff v0.26.0

## Package

Project Ember v0.26.0 — City Development & Economy, based on v0.25.0 Army Veterancy & Upgrades. Godot 4.7.2 stable, GL Compatibility, Android landscape source project. This ZIP is a Godot source project, not an APK.

## Implemented

- Three city levels based on population: 1–7, 8–13 and 14–20.
- Province capacity 1/3/5 and four one-time specializations.
- Four adjacent terrain-specific province improvements, each with one permanent +2 income bonus.
- Level-two and level-three data-driven upgrades for all six existing buildings.
- Central upkeep values in `unit_catalog.gd`; army upkeep is rounded up and paid from player/AI city treasuries after income.
- Mobile city panel shows specialization, province slots, upgrade prices and upkeep.
- AI develops cities and chooses a deterministic specialization; capital prioritizes a market before repeated recruitment.

## Economy values

- Base city income: +2 food, +4 gold, +4 production per turn.
- Starting army: three melee and two ranged troops; upkeep = 4 gold/turn.
- Upkeep per troop: melee 0.8, ranged 0.8, spear 0.9, cavalry 1.4.
- Specializations: +20% one income or −10% recruit gold.
- Province effects: +2 one existing resource per improved hex.
- Building discounts combine multiplicatively with specialization, floor 0.70.
- No happiness, trade routes, extra resource, starvation, desertion or revolt system is added.

See `CITY_DEVELOPMENT.md` for full balance tables, formulas, save schema, UI and deferred mechanics.

## Compatibility

- Existing resource IDs, building IDs and unit role IDs are unchanged.
- Army cap remains 24; commanders remain outside the troop cap.
- Save schema remains version 1.
- Legacy cities default to blank specialization, level 1 for their existing buildings, empty province improvements and zero previous upkeep.
- Queued building upgrades and province improvements are validated during save loading.

## QA status

- Static validation: 93/93 passed.
- Python static QA syntax check passed.
- 27 `*_smoke_test.gd` source files are present; the new city development test is included but was not executed here.
- Godot 4.7.2 parser/import/runtime tests and Android UI/device/FPS checks remain pending because no Godot executable is available in this build environment.

## Suggested phone validation

1. Open `project.godot` in Godot 4.7.2 Android Editor and import the project.
2. Load a COPY of a v0.25.0 campaign.
3. Open each existing city and confirm the level, income and upkeep display.
4. Let a city reach population 8; choose one specialization and verify the income changes once.
5. Build/upgrade a farm, market or workshop; confirm production and gold are deducted at the intended times.
6. Build a province improvement only on a suitable adjacent owned hex; end turns and verify the +2 income.
7. End turns with different army compositions and compare the displayed upkeep with the expected rounded-up sum.
8. Save/reload and verify all new city data remains intact.
