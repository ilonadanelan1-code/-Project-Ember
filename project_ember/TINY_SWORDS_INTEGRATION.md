# Tiny Swords combat sprites

The animated pixel-art unit renderer is **required in every playable release**. It is not an optional graphics mode.

The public source repository does not track the runtime atlas or manifest because the supplied Tiny Swords artwork must not be redistributed as a standalone asset pack. The playable game ZIP integrates the generated atlas inside the complete Project Ember project.

## Restore the local runtime atlas

1. Use the owner-provided Tiny Swords (Free Pack) ZIP.
2. Run from the project folder:

   python3 tools/assets/build_tiny_swords_atlas.py "/path/to/Tiny Swords (Free Pack).zip"

3. The builder writes assets/combat/tiny_swords/combat_units_atlas.png and assets/combat/tiny_swords/atlas_manifest.json.
4. Open the project in Godot 4.7.2 and let the editor import the PNG.
5. Before sharing or installing a playable archive, run bash tools/assets/package_playable_release.sh.

The packager refuses to build a playable ZIP if either file is absent, the atlas dimensions are wrong, or the active unit runtime reintroduces the procedural 3D fallback.

## Runtime behavior

Infantry, archers, spearmen and commanders use the blue/red Tiny Swords SpriteFrames. Mounted cavalry keeps its separate blue/red pixel animation sheets in assets/combat/cavalry/. The battlefield floor keeps the established pixel-isometric ground atlas.

All unit sprites use nearest-neighbour filtering, fixed-Y billboarding, unshaded rendering and alpha-cut transparency. A source-only checkout without the licensed atlas logs a clear warning and does not replace pixel-art soldiers with low-poly models. Such a checkout is not a playable release.

## Attribution and redistribution

Tiny Swords (Free Pack) — Artist: Pixel Frog.
Source: https://pixelfrog-assets.itch.io/tiny-swords

The supplied free pack permits use and modification in games; attribution is appreciated. The original source ZIP and extracted source sheets are not included in the public source repository or redistributed separately. The generated atlas is bundled only as part of the complete Project Ember playable game archive.

## Existing animation behavior

- Twelve animation strips per faction, including Lancer_Right_Defence.
- Melee contact and bow-release timing coordinated by the combat controller.
- Unit sprites flip to face their selected enemy; recovery uses guard/defence loops.
- Cavalry keeps separate blue/red mounted pixel sprites for idle, run, attack and charge.
