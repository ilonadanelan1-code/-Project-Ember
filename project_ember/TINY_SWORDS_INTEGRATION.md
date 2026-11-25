# Tiny Swords combat sprites

This branch adds an optional AnimatedSprite3D combat renderer. The runtime atlas
is intentionally not tracked in the public repository because the Tiny Swords
asset terms prohibit redistribution of the artwork as a standalone asset pack.

## Enable the sprite renderer

1. Download the free Tiny Swords pack from https://pixelfrog-assets.itch.io/tiny-swords.
2. Run python3 tools/assets/build_tiny_swords_atlas.py with the ZIP file path as its first argument.
3. The builder writes assets/combat/tiny_swords/combat_units_atlas.png and its
   local manifest. Keep both files in the project folder.
4. Open the project in Godot 4.7.2 and let the editor import the PNG.

If the atlas is absent or cannot be loaded, infantry units automatically use
the existing fallback renderer. Gameplay collision, health, unit stats and AI do
not change. Mounted cavalry is supplied separately by the user-provided horse
sprite pack; see `assets/combat/cavalry/SOURCE_NOTICE.txt` for its source and
license status.

The source pack is Tiny Swords (Free Pack) by Pixel Frog. Attribution is
appreciated. Do not distribute the atlas or extracted source frames separately.


## v0.19.1 notes
- The atlas now contains 12 strips per faction (including Lancer_Right_Defence).
- Melee contact and bow-release timing are coordinated by the combat controller.
- Unit sprites flip to face their selected enemy; recovery uses guard/defence loops.

## v0.20.0 combat rendering
- Cavalry now uses its own mounted pixel-art SpriteFrames: idle, gallop/run, rearing attack and jump/charge.
- Both factions have separate mounted sheets; the red faction is horizontally flipped for opposing facing.
- All combat roles use billboarded animated sprites in the full local package. The original collision capsule and tactical logic remain unchanged.
