# Changelog

## v0.17.0 — 24-Scene Painted Biomes & World Details
- Replaced composite biome contact-sheet sampling with 24 independent source scenes (four per biome).
- Raised close-zoom sampling density by changing the global period to 430 world units.
- Added edge blending across neighboring surface variants and biomes.
- Expanded the foreground detail batch to 24 masked sprites across all six biomes.
- Softened the hex grid. No campaign/save schema change.

## v0.17.0 — 24-scene Painted Biomes
- Rebuilt the world atlas from 24 separate scene crops (four variants per biome) instead of sampling 2x2 contact sheets as one surface.
- Added deterministic 4x4 axial artwork regions and smooth crossfades across neighboring region/biome borders.
- Added second-nearest-edge blending near three-cell corners.
- Reduced repeat period to 560 world units and made each crop periodic through edge crossfading.
- Corrected mountain overlay masks so their left/right edges feather instead of forming rectangular cutouts.
- Reduced detail object footprint and replaced dynamic dictionaries with typed transform/color buffers.

# Changelog

## v0.17.0 — Painted Biome Blending & World Details

- Increased surface sampling density by reducing the world texture period from 1600 to 760 map units.
- Expanded the surface atlas to 4096x4096 with seven 1245px panels and mipmap-safe gutters.
- Added a campaign-seeded biome mask and symmetric shader blending between different neighboring biomes to remove hard per-hex color cuts.
- Added a 16-sprite detail atlas derived from existing artwork: forest groves, alpine ridges, meadow clusters, water/islet details, farmland patches and marsh reeds.
- Added one deterministic foreground-detail MultiMesh batch, streamed only for explored cells and culled at distant zoom.
- Softened the cartographic grid so it remains readable without dominating the painted terrain.
- Preserved old world-generator versions, saves, AI, combat and campaign logic.


## v0.15.0 — Varied Painted Terrain & Regional Start

- Replaced the one-image-per-biome atlas with 24 visual compositions from 12 distinct painted source images and mirrored counterparts: four visual variants each for meadows, forests, highlands, water, farmland and marsh.
- Added six rotations per painting, giving 144 terrain-art variants plus a dedicated distant LOD tile in a 13×12 atlas.
- Atlas tiles now use flat top-down terrain surfaces with subtle hex borders. A single batched grid overlay provides strategic cell readability.
- Per-cell art selection is deterministic and seeded by axial coordinates; neighboring cells in a biome can use different artwork rather than repeating the same stamp.
- Added world generator v3 with a more balanced opening region. Versions 1 and 2 remain available for old saves without changing their terrain.
- Kept the existing one-MultiMesh renderer, fog-of-war, roads, boundaries, cities, AI, combat and save structure.

## v0.14.0 — Coherent Biomes & Painted Hex World

- New campaigns use connected, multi-scale biome generation instead of independently randomized terrain per hex.
- Added farmland and marsh terrain families. Forest, highland and water zones form coherent regional shapes.
- Added world-generation versioning to saves. Legacy saves default to generator v1 and preserve their original terrain layout.
- Rebuilt the original painted atlas around eight terrain and landmark motifs.
- Enlarged settlement and capital silhouettes for mobile readability.
- Added regression checks for terrain distribution, biome adjacency, atlas selection and save migration.

## v0.13.3 — Painted Atlas Shader Correction

- Fixed the strategic terrain shader to capture MultiMesh instance COLOR in `vertex()` before Godot multiplies fragment `COLOR` by the default texture at unmodified UV coordinates.
- Atlas selection and tint now use the captured varying; this prevents double sampling and corrupted atlas-cell selection.
- Added shader-source regression checks.


## v0.16.0 — Continuous Painted World Surfaces
- Removed the per-hex art-stamp rendering model that caused a checkerboard/mosaic appearance.
- Added six large, mirrored-seamless painted biome surfaces sampled in shared world coordinates.
- Added a dedicated low-detail topographic surface for continent LOD.
- Added a procedural antialiased hex mask and reduced grid contrast.
- Kept the single MultiMesh draw batch and all campaign/world-generation versions.
