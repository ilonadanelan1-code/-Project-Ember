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

Visual captures ran at 1280x720 in Xvfb with Mesa llvmpipe. GitHub Actions run [45845972194](https://github.com/ilonadanelan1-code/-Project-Ember/actions/runs/45845972194) completed with conclusion **success**. The run re-imported all resources, restored the licensed Tiny Swords atlas and manifest into its temporary workspace after SHA-256 verification, compiled scripts, passed all 37 smoke suites, and passed all four map zoom captures. This validates Linux software-rendered scene startup and screenshots, not Android FPS. Android device controls, performance and long-session stability remain unverified.

`SAVE_VERSION` remains 1.

## Publishing note
The full playable archive is published in [GitHub Release v0.38.2](https://github.com/ilonadanelan1-code/-Project-Ember/releases/tag/v0.38.2). Public source is imported to [`release/v0.38.2-godot-audited`](https://github.com/ilonadanelan1-code/-Project-Ember/tree/release/v0.38.2-godot-audited). The licensed Tiny Swords atlas and manifest remain excluded from public source and are restored only inside temporary CI workspaces from the checksummed release asset.
