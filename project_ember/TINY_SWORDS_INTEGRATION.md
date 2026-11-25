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

If the atlas is absent or cannot be loaded, BattleUnit automatically uses the
existing low-poly renderer. Gameplay collision, health, unit stats and AI do not
change. Cavalry intentionally retains its original mounted model because this
free pack does not include a horse-mounted unit.

The source pack is Tiny Swords (Free Pack) by Pixel Frog. Attribution is
appreciated. Do not distribute the atlas or extracted source frames separately.
