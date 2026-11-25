# Project Ember — Campaign Victory & Campaign Tempo

**Release target:** v0.30.0  
**Base:** v0.29.0 — Diplomacy Expansion  
**Engine target:** Godot 4.7.2, GL Compatibility  
**Platform:** Android, landscape  
**Status:** implementation added to branch; Godot parser, runtime suite and device validation are still required.

## 1. Player-facing goal

**Build the strongest kingdom, unite the world through diplomacy, or establish economic dominance.**

A campaign can be completed through three independent victory paths. The player is not required to choose a path at campaign creation and may work toward more than one simultaneously.

The system reuses existing data. It does not add resources, unit roles, buildings, factions or kingdom IDs.

## 2. Shared rules

1. Victory conditions begin evaluating on turn 25.
2. The campaign checks progress once at the end of a strategic turn, after city income, army upkeep, diplomacy and kingdom AI processing.
3. Military victory is checked immediately after a successful battle against an AI kingdom so the result does not wait for an additional turn.
4. Once a path is unlocked, it remains available even if the player later loses the conditions used to unlock it.
5. If several paths are unlocked, the player chooses which one to declare.
6. The player may finish the campaign or continue in freeplay.
7. A finished campaign is saved and prevents further turn advancement until a new campaign is started.
8. The existing save schema remains `SAVE_VERSION = 1`. Missing victory data is initialized with safe defaults.

## 3. Victory paths

### Military — `military`

Requirements:
- At least 6 distinct AI kingdoms defeated in tactical battles.
- At least 8 surviving player troops when the sixth distinct victory is achieved.
- The turn number is at least 25.

A defeated kingdom is counted once. Neutral locations and repeat battles against the same kingdom do not increase the count. The count is based on unique existing kingdom IDs 0–8.

### Economic — `economic`

All conditions must remain true for 5 consecutive turns, beginning no earlier than turn 25:
- At least 2 player cities are Metropolises (population 14 or higher).
- Combined gold in all player city treasuries is at least 600.
- Recurring net gold income is at least 12 per turn.

Formula:

`net_gold_income = city_gold_income + diplomacy_gold_income - army_upkeep`

- `city_gold_income` is calculated per player city from the existing building, specialization and province catalogs, then faction modifiers are applied.
- `diplomacy_gold_income` includes +2 gold per active player trade or alliance treaty. Uncertain tribute receipts are intentionally excluded from the forecast.
- `army_upkeep` uses the existing centralized unit catalog and player faction modifiers.

The counter resets to zero as soon as any economic condition fails.

### Diplomatic — `diplomatic`

All conditions must remain true for 3 consecutive turns, beginning no earlier than turn 25:
- At least 5 living AI kingdoms have relation +55 or higher with the player.
- At least 3 active positive contracts are in force: trade, alliance, or player-led vassalage.
- At least 2 of those contracts are alliances or vassal agreements where the player is the overlord.

Peace and war are not counted as positive contracts. Expired treaties are not counted. The hold counter resets if any requirement fails.

## 4. Data model

New root save field:

```json
{
  "campaign_victory": {
    "military_wins": [0, 2, 4],
    "economic_hold_turns": 2,
    "diplomatic_hold_turns": 1,
    "unlocked_types": ["military"],
    "status": "offered",
    "type": "",
    "turn": 0
  }
}
```

Fields:
- `military_wins`: unique AI kingdom IDs already defeated by the player.
- `economic_hold_turns`: current consecutive-turn counter for economic conditions.
- `diplomatic_hold_turns`: current consecutive-turn counter for diplomatic conditions.
- `unlocked_types`: permanent list of paths the player has qualified for.
- `status`: `none`, `offered`, `continued` or `claimed`.
- `type`: chosen path when the player declares/continues victory.
- `turn`: turn when the player selected the outcome.

Old saves receive empty win/unlock arrays, zero counters, and status `none`. Invalid IDs, duplicates, unknown status values and negative counters are normalized. No schema version bump is required.

## 5. Mobile UI

The player opens **ЕЩЁ → ЦЕЛИ ПОБЕДЫ**.

The full-screen panel uses the existing dark-bronze theme, safe-area root and scroll container. Three large sections show:
- current numeric progress;
- the requirement;
- consecutive-turn progress when applicable;
- a selection button when a path is unlocked.

The player then chooses:
- **ЗАВЕРШИТЬ КАМПАНИЮ** — mark the campaign as complete and stop turn advancement;
- **ПРОДОЛЖИТЬ ИГРУ** — preserve the declared victory and continue in freeplay.

When a path first unlocks, the panel opens automatically once in the current UI session. It remains accessible later from the More menu.

## 6. AI scope

This release does not make the nine AI kingdoms race toward their own victory conditions. Their existing expansion, city development and diplomacy continue unchanged. AI ambition scoring and AI victory eligibility are deferred until inter-kingdom wars and battle resolution can support a fair comparison.

## 7. Performance and risks

- Evaluation runs once per strategic turn, not per frame.
- It loops over the existing player cities and nine kingdoms only.
- No new world entities, scene nodes or tactical effects are created.
- The UI is built once and refreshed from the existing campaign state.
- Tribute receipts are excluded from projected economic income because the current diplomatic transfer is treasury-limited.
- Military progress counts unique kingdoms to prevent repeat-battle farming.
- Unlocks are permanent so the player cannot lose a victory opportunity due to a later income dip or treaty expiry.

## 8. Implementation and verification

New:
- `scripts/campaign_victory_catalog.gd`
- `tests/campaign_victory_smoke_test.gd`
- `CAMPAIGN_VICTORY.md`

Updated:
- `scripts/campaign_state.gd`: new campaign defaults, battle-win tracking, turn evaluation, save/load and outcome selection.
- `scripts/strategy_map.gd`: More-menu entry, responsive scroll panel and completion/freeplay controls.
- `DESIGN.md` and `README.md`: release notes and feature link.

Automated checks cover unique battle wins, turn-25 gating, economic hold/reset, diplomatic hold/reset, treaty expiry semantics, multi-city gold/income aggregation, save normalization, freeplay and final completion.

Required external checks:
1. Godot 4.7.2 parse/import with warnings treated as errors.
2. Run `tests/campaign_victory_smoke_test.gd`.
3. Run the existing campaign, diplomacy, faction, city, army and world smoke tests.
4. Verify a copy of a v0.29.0 save loads with default victory fields.
5. On Android: verify panel scrolling, 48 dp tap targets, auto-opening on first unlock, saved completion, disabled turn progression after final victory and freeplay continuation.

No Godot runtime or physical Android test is claimed by this document.


## Release branch

This source snapshot is published from `release/v0.30.0-campaign-victory`, based on `release/v0.29.0-diplomacy-expansion`. The ZIP generated by GitHub for this branch is a Godot source project, not an Android APK.
