# Project Ember — Army Veterancy & Upgrades

Release: v0.25.0  
Engine: Godot 4.7.2 stable · GL Compatibility  
Based on: v0.24.1 Tactical Combat Expansion

## 1. Goal and player-facing rule

Surviving troops learn from battle. Every unit stores its own experience and can rise through four ranks. In a city, the player can also pay gold for two permanent equipment-training ranks for each existing troop role.

Player phrase: **«Береги опытных бойцов и вкладывай золото в подготовку войск — ветераны становятся сильнее с каждым сражением».**

## 2. Experience and veterancy

Only surviving non-commander troops receive unit experience after a completed battle. Killed units are removed with their record; commanders continue to use the existing hero progression system.

Per-survivor formula:

`battle_xp = clamp(6 + kills * 8 + floor(damage_dealt / 30), 6, 30)`

Examples:

| Kills | Damage dealt | XP gained |
|---:|---:|---:|
| 0 | 0 | 6 |
| 1 | 30 | 15 |
| 2 | 80 | 24 |
| 10 | 1,000 | 30 (cap) |

The 6-point participation award applies to every deployed survivor, including a unit that did not land a hit. The maximum award per surviving unit per battle is 30 XP.

| Rank | ID | Cumulative XP | Combat bonus |
|---|---|---:|---|
| Recruit | `recruit` | 0 | None |
| Trained | `trained` | 40 | +3% attack damage |
| Veteran | `veteran` | 100 | +6% attack damage, +1 armour |
| Elite | `elite` | 180 | +10% attack damage, +2 armour |

Veterancy does not increase maximum health, heal a unit, change movement speed or grant additional attacks. Bonuses are recalculated when the unit enters the next battle. This avoids changing current HP during the battle-result transition.

## 3. Permanent city army upgrades

Upgrades are purchased in the active city's **Военная подготовка** section. They cost gold immediately and do not consume production. Each role has two ranks. The upgrade rank is empire-wide: it affects all current and future player units of that role the next time they enter a tactical battle.

| Role ID | Required building | Rank 1 | Cost | Rank 2 (total) | Cost |
|---|---|---|---:|---|---:|
| `melee` | `barracks` | +1 armour | 55 gold | +2 armour | 90 gold |
| `ranged` | `archery_range` | ×1.06 ranged damage | 65 gold | ×1.12 ranged damage | 105 gold |
| `spear` | `barracks` | +0.10 anti-cavalry multiplier | 60 gold | +0.20 anti-cavalry multiplier | 95 gold |
| `cavalry` | `stable` | +0.08 charge multiplier | 85 gold | +0.16 charge multiplier | 135 gold |

The second-rank values are totals, not additions on top of the first rank. For example, a rank-two archer upgrade multiplies base ranged damage by 1.12, not by 1.06 × 1.12.

Base unit catalog values and the stable role IDs (`melee`, `ranged`, `spear`, `cavalry`) remain unchanged. The modifiers are applied after base role stats and veterancy stats are read.

## 4. Application order

1. Read the role's base values from `unit_catalog.gd`.
2. Apply per-unit veterancy damage and armour bonuses from stored experience.
3. Apply the player's current empire-wide upgrade rank from `CampaignState.army_upgrades`.
4. Apply existing commander aura, Battle Cry, terrain, flanking, charge and target armour rules through the existing combat methods.

Upgrade effects are prepared when the battle units spawn. Purchasing an upgrade during the strategy phase does not silently mutate an already-running tactical battle.

## 5. Save compatibility

The campaign save schema remains `SAVE_VERSION = 1`.

New data:

- Each troop record may contain `experience: int`, clamped to 0–999999.
- The root save may contain `army_upgrades`, a dictionary with ranks for `melee`, `ranged`, `spear` and `cavalry`, each clamped to 0–2.

Defaults for old saves:

- Missing troop `experience` becomes 0 XP (Recruit).
- Missing `army_upgrades` becomes all four roles at rank 0.
- Unknown role IDs continue to be rejected by the existing validation.

AI kingdom army records also preserve unit experience during kingdom normalization. Temporary battle award fields (`battle_xp_gained`, `previous_veterancy_rank`) are stripped before campaign records are saved. No battle node, timer or scene object is serialized.

No schema-version bump or destructive migration is required.

## 6. Mobile UI

- City overview adds one compact rank-count line: Recruit / Trained / Veteran / Elite.
- A two-column **Военная подготовка** grid adds four role buttons, each at least 64 dp high.
- Each button shows the current-to-next upgrade rank, gold cost, effect and missing required building.
- At rank 2, the button displays `МАКСИМУМ` and becomes disabled.
- The section sits inside the existing city ScrollContainer; no new full-screen panel is introduced.
- Battle results show total XP gained by surviving player troops and the number of rank promotions.

## 7. AI behaviour

- AI survivors receive the same per-unit battle XP formula as player survivors.
- AI kingdom normalization and campaign saves preserve that experience, so veteran enemy troops can appear in later battles.
- AI purchase of permanent equipment upgrades is intentionally not part of v0.25.0. It requires persistent per-kingdom upgrade ranks and a balancing pass across nine independent economies; it is a follow-up task, not an invisible player-only AI bonus.

## 8. Balance and performance constraints

- No new resource, building ID, unit ID, physics object, active entity or per-frame update is introduced.
- The unit cap remains 24; commanders remain outside the troop cap.
- XP is calculated once per survivor at battle completion, not every frame.
- Upgrade definitions are centralized in `scripts/army_upgrade_catalog.gd` so prices and effects can be balanced without editing the combat flow.
- If veterancy snowballs too quickly, adjust the XP thresholds or the per-battle cap in `unit_catalog.gd`; do not add a second progression currency.

## 9. Implementation and validation

Files changed:

- `scripts/unit_catalog.gd` — veterancy thresholds and battle XP formula.
- `scripts/army_upgrade_catalog.gd` — role-specific upgrade definitions and bonuses.
- `scripts/battle_unit.gd` — apply veterancy and upgrade stats at spawn.
- `scripts/combat_test.gd` — transfer unit experience, calculate survivor awards and display battle report.
- `scripts/campaign_state.gd` — purchase methods, save/load defaults and result summaries.
- `scripts/kingdom_ai.gd` — preserve AI troop experience through save normalization.
- `scripts/strategy_map.gd` — city training controls and veterancy summary.
- `tests/unit_progression_smoke_test.gd` — progression, upgrade, compatibility and catalog checks.

Static validation: 78/78 checks pass. Python QA script syntax check passes. Godot 4.7.2 import/parser, runtime smoke tests and Android device testing were not run in the build environment because the Godot executable is unavailable. Run `tools/qa/run_smoke_tests.sh` in Godot 4.7.2 before treating the release as runtime-certified.
