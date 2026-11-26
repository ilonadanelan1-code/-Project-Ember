# Project Ember v0.38.2 — Godot audit

Audit date: 2026-11-26  
Source examined: user-provided `Project-Ember-v0.38.1-AI-Expansion-Fix.zip`  
Engine: Godot 4.7.2.stable.official.ed1daf0bf (Linux x86_64)

## Corrections
- `scripts/kingdom_ai.gd`: restored a missing `#` comment marker that had made a prose line invalid GDScript.
- `scripts/campaign_state.gd`: explicitly typed the fallback kingdom collection as `Array[Dictionary]`.
- `tests/campaign_smoke_test.gd`: replenish test city gold and production before asserting city foundation.
- `tests/settlement_economy_smoke_test.gd`: use a save-enabled campaign for the persistence round trip.
- `tests/territory_control_smoke_test.gd`: place the AI fixture at its actual kingdom index for ownership lookup.
- Updated stale package/import metadata that still described v0.31.0.

## Results
| Check | Result |
|---|---:|
| Godot editor import | Passed; 0 script/resource load errors |
| Project-context GDScript parser | 91/91 |
| Runtime smoke suites | 37/37 |
| Runtime PASS assertions | 1,452 |
| 180-turn peaceful AI expansion regression | Passed |
| Strategic map visual captures | 4/4 zoom levels |
| Static QA | 233/233 |
| Python syntax compile of static validator | Passed |
| Playable ZIP integrity | Passed |
| Tiny Swords atlas | 1152x2304 RGBA; 24 animation entries |

Visual captures ran at 1280x720 in Xvfb with Mesa llvmpipe. This validates scene rendering, not Android FPS. Android device controls, performance and long-session stability remain unverified.

`SAVE_VERSION` remains 1.

## Publishing note
This report is a GitHub audit record. The full v0.38.2 playable archive was created in the ChatGPT session, but the current GitHub connector does not provide a binary release-asset upload action. Therefore no claim is made here that the full source ZIP has been uploaded. The licensed Tiny Swords atlas and manifest are also excluded from public source by project policy.
