# Project Ember

Godot 4 fantasy 4X strategy with real-time tactical combat.

Current source release: **v0.10.2 — Fog of War & Chunked Map Streaming**.

- [Design source of truth](project_ember/DESIGN.md)
- [Android import and play guide](project_ember/ANDROID_START.md)
- [Tactical controls](project_ember/TACTICAL_CONTROLS.md)
- [Visual overhaul notes](project_ember/VISUAL_OVERHAUL.md)
- [Art Bible](project_ember/ART_BIBLE.md)
- [Hero progression and commander abilities](project_ember/HERO_PROGRESSION.md)

v0.10.2 adds persistent fog of war and explored-cell streaming. Only cells previously discovered by the player's army, cities or settler are eligible for map rendering; currently visible terrain is bright, remembered terrain is dimmed, and unknown terrain is hidden. Enemy armies disappear outside current sight while known enemy settlements remain as remembered locations. Exploration is saved as sparse encoded cell IDs and is compatible with older saves. The map now iterates only the explored-cell index rather than scanning the full 24,031-hex grid each redraw. At continent scale, explored cells are aggregated into six-hex LOD chunks before being sent through the single MultiMesh terrain batch. The 24,031-hex world, nine AI kingdoms and mobile controls remain included.

The archive is a Godot source project, not an APK. Import `project_ember/project.godot` in Godot 4.3 Android Editor.
