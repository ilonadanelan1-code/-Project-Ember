# Project Ember — Combat Pixel-Art Policy

## Non-negotiable visual rule

Playable combat units and the battlefield presentation remain pixel art. This is a project requirement, not an optional graphics preset.

- Melee infantry, archers, spearmen, commanders and mounted cavalry use the established animated pixel-art sprites.
- Blue and red faction variants, animation strips, frame timing and sprite proportions remain intact.
- Sprite rendering uses nearest-neighbour texture filtering, unshaded fixed-Y billboards and alpha-cut transparency.
- Tactical ground remains the pixel-isometric terrain atlas. Units, terrain, props and effects must not be replaced with smooth low-poly substitutes.
- New unit roles require matching pixel-art frames before appearing in a playable release.

## Forbidden regression

BattleUnitVisualsScript.build() is a legacy procedural 3D model builder. It must not be used in the active BattleUnit runtime path. If the licensed infantry atlas is absent, a source-only checkout emits a warning and does not substitute polygon/low-poly soldiers. Such a checkout is not a playable release.

## Required assets and release gate

The public source repository intentionally excludes the owner-provided Tiny Swords runtime atlas and manifest because the artwork must not be redistributed as a standalone asset pack. Every playable ZIP must include both files inside the complete Godot project:

- assets/combat/tiny_swords/combat_units_atlas.png — 1152×2304 RGBA atlas, 96×96 cells, 12 animation rows per faction.
- assets/combat/tiny_swords/atlas_manifest.json — matching animation/frame metadata.

The source pack is Tiny Swords (Free Pack) by Pixel Frog. The source ZIP is not copied into the game package. The generated atlas is included only inside the complete Project Ember game archive.

Before creating a playable release, run tools/assets/package_playable_release.sh. It validates both required art files, atlas dimensions, manifest animation metadata and the active runtime's no-low-poly rule, then creates and CRC-checks the ZIP. It must fail rather than emit a playable package when art is absent.

GitHub source-only CI may validate gameplay and scripts without the ignored atlas. It must skip the playable ZIP artifact if the required art files are not present; it must never upload a misleading sprite-less game archive.

## Regression checks

- combat_sprite_library_smoke_test.gd validates both teams and every required animation when the atlas is integrated.
- static_validate.py ensures the runtime cannot call the procedural unit-model builder and that the release packager enforces the atlas.
- TINY_SWORDS_INTEGRATION.md is the rebuild/import guide.
