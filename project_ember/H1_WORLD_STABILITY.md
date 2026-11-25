# H1 — World Stability

Base: Project Ember v0.30.0 — Campaign Victory  
Working branch: `release/v0.30.0-h1-world-stability`

## Scope

This pass stabilizes the existing world-event and neutral-location systems before adding more content. It does not introduce new location types, quest chains, or AI expansion behavior.

## Changes in this pass

- Scout-report choice now treats its four-hex value as an exploration bonus beyond the army's current vision radius. Faction vision bonuses are respected. The previous `reveal_radius` key remains accepted as a fallback for compatibility.
- The world-event smoke test checks both the extra reveal boundary and a cell just beyond it.
- The world-campaign smoke test explicitly establishes a wartime condition before expecting the first AI army to move. Peaceful armies are not expected to advance toward an enemy.
- The neutral-location smoke test uses a typed empty survivor array when resolving a victorious battle.

## H1 completion checklist

- [ ] Godot 4.7.2 resource import and script compilation pass.
- [ ] World-event, world-campaign, and neutral-location smoke tests pass.
- [ ] Full smoke-test suite passes.
- [ ] Legacy campaign save/load remains compatible.
- [ ] Android Editor test confirms touch behavior, fog of war, and stable performance.

Android device validation remains a separate requirement after CI.
