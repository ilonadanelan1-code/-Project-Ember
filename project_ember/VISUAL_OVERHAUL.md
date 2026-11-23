# Project Ember v0.8.0 — Visual Overhaul

## Visual direction

Stylized low-poly fantasy with illustrated map terrain, readable army markers, hand-built low-poly soldier silhouettes and a dark bronze / aged gold interface. The renderer remains Godot 4.3 GL Compatibility.

## Strategic map

The original 91-cell axial hex map is unchanged. Terrain IDs, traversal rules, city records, settler movement, army positions and tap-to-cell selection are still controlled by the original campaign scripts. The renderer now adds layered hex borders, directional shadows, grass strokes, tree canopies, hill silhouettes, water ripples, miniature castles, settlement pennants and shield-shaped army markers.

## Tactical battlefield

The field remains 38 × 26 world units and keeps the original StaticBody3D ground collision and orthographic camera. The new environment adds a subtle procedural ground texture, grass and stone scatter, forest-edge trees, small ruin pillars, ambient world lighting and directional shadows. Repeated vegetation and ground accents are batched with MultiMeshInstance3D.

## Army models

BattleUnit now delegates model construction to BattleUnitVisuals. Swordsmen receive sword and shield silhouettes, archers receive bow and quiver details, spearmen carry long polearms, cavalry uses a separate horse-and-rider model, and commanders receive a cape, crown and banner. The BattleUnit root keeps its collision capsule, health, combat stats, selection state, movement orders and AI.

## Android considerations

- No external models, texture packs or runtime downloads.
- GL Compatibility renderer retained.
- Repeated small scenery objects are batched.
- Model meshes use low segment counts and simple StandardMaterial3D materials.
- Touch controls, campaign logic and save data are unchanged.
- Physical-device checks are still required for frame pacing, shadow cost, UI scaling and model visibility.

## Validation

The package workflow imports and parses the Godot project, starts both main scenes, runs campaign / roster / hero progression smoke tests and adds visual builder smoke tests. The Android Editor smoke test remains the final check on the phone.
