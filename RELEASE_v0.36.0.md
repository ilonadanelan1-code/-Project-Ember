# Project Ember v0.36.0

**Hero Roster, Multiple Armies & Equipment**

## Published source

- Branch: https://github.com/ilonadanelan1-code/-Project-Ember/tree/release/v0.36.0
- Source baseline: `d66fe96040e3d92d8f4e49be0b4e8bb73031dc1d`
- Automated QA: https://github.com/ilonadanelan1-code/-Project-Ember/actions/runs/45803647378

## Features

- Persistent hero roster with three recruitable specialist lords.
- Up to four independent player armies with separate troop rosters, map positions, movement and assigned commanders.
- Army splitting, touch selection, movement and recruitment orders tied to their target army.
- Per-hero inventory with weapon, armor and relic slots.
- Shared commander stat calculation for campaign and tactical combat.
- Deterministic equipment loot after victories.
- Additive migration from legacy single-hero and single-army saves; SAVE_VERSION remains 1.
- Existing pixel-art battle presentation retained.

## QA

Verified against Godot 4.7.2:

- Static QA: 213/213 checks passed.
- Smoke tests: 36 passed, 0 failed.
- Godot resource import and GDScript parsing passed.
- Four strategic-map zoom captures passed.

## Playable archive

File: `Project-Ember-v0.36.0-final.zip`  
Size: approximately 35 MB  
SHA-256: `399d8cf44fa3d6886a084ec7f541792e0760ef8a6df59cd9a27f056e3241779c`

The playable archive includes the integrated Tiny Swords pixel-art atlas and manifest with attribution. Those licensed binaries are deliberately excluded from this public source repository. The ZIP is distributed separately from this GitHub source branch.

This is a Godot project targeting Android landscape, not an APK. Physical Android touch usability, equipment feedback and GPU performance still need hands-on device validation; they are not claimed as completed by headless QA.
