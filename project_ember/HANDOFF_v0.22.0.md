# Project Ember — Handoff v0.22.0

## Current package

Project Ember v0.22.0 — Strategy & UI Icon Integration, based on v0.21.1 Pixel Terrain Type Fix. Godot 4.7.2 stable, GL Compatibility, Android-oriented source project. This ZIP is not an APK.

## Completed in this version

- Imported both user-provided icon packs: Pixel Fantasy Map Icons and Gridwright Strategy UI.
- Strategic city markers now distinguish player capitals (blue castle), AI capitals (red castle), player towns and AI villages.
- Army markers use crossed swords; moving settlers use a worker sprite.
- The top HUD and city panel show gold, food and stored production with icons.
- Building and recruitment buttons use contextual icons; attack, city, army and found-settlement actions have icons.
- Wood and stone are not shown as game stocks because they are not implemented in CampaignState.
- Both licences and source PNG variants are included under `assets/icons/`.
- No campaign rules, AI, combat, tactical art, save fields or save version were intentionally changed.

## Validation status

- Static validation and ZIP CRC are recorded in `QA_REPORT_v0.22.0.txt`.
- Godot 4.7.2 import/parser/runtime tests have not been run in this container.
- Android GPU/FPS and actual phone visual checks remain pending. User works from Android, so the next runtime check should be done in Godot Android Editor.

## Next development direction

Continue the world-expansion stage: improve settler movement and settlement founding, give founded cities their own territories and independent economies, then connect those systems to the strategic map and AI. Keep icon usage consistent with the new catalog.

## Continuation rules

- Use v0.22.0 as the new base; preserve v0.21.1 as a backup.
- Make changes in coherent batches and update version, changelog, QA report, manifest and this handoff for each deliverable.
- Do not claim Android runtime or performance validation without an actual device run.
