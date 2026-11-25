## v0.31.0 — AI Neutral Site Expeditions

- Gives each living AI kingdom a peaceful-world objective: it can reserve a nearby neutral site and move its army toward it when no active war target takes priority.
- Prevents living AI kingdoms from selecting the same reserved target; army size and estimated force strength gate expeditions against stronger guard tiers.
- Resolves AI-vs-neutral encounters through a deterministic, bounded strategic skirmish using unit role damage, veterancy, current health and armor. Defeated guards and guardian health persist for a later expedition.
- AI victories record the capturing kingdom and campaign turn, transfer the existing resource reward to the nearest AI city and apply location-specific effects to surviving troops.
- Gives AI-owned abandoned mines +2 stored production per turn for the nearest city; player mine income is restricted to player-owned sites.
- Shows the capturing kingdom when the player taps an explored, AI-cleared location.
- Adds regression coverage for AI target assignment, movement, victory, reward payment and ownership normalization. `SAVE_VERSION` remains 1; legacy cleared sites default to player ownership.
- Static project validation: 169/169 checks passed locally; Godot 4.7.2 import, parser, smoke tests and map captures run in GitHub Actions for the release branch.

## v0.30.0 — Neutral Sites & Exploration Expansion

- Gives all five existing neutral location types a distinct post-victory effect while retaining their original resource rewards and stable location IDs.
- Ancient ruins reveal a remote five-hex survey centered twelve hexes from the ruin; monster lairs grant +12 XP to each surviving troop; shrines restore the ruler; mercenary camps recruit one swordsman when army capacity allows or grant 25 gold when full.
- Cleared abandoned mines become persistent economic sites, granting +2 stored production per campaign turn to the nearest player city.
- Changes the scout-report event to reveal a deterministic remote radius-four area centered twelve hexes from the army, beyond normal army vision.
- Keeps neutral-site state in the existing location records and reuses the existing three resources; no save-schema version bump or new campaign resource is introduced.
- Fixes Godot 4.7.2 smoke-test regressions involving typed empty arrays, typed faction building lists, updated AI war-only movement, current animated-sprite rendering, the faction-founding restart flow and the current mobile HUD layout.
- Updates H regression coverage and static QA guards. Full Godot 4.7.2 runtime results are recorded in `QA_REPORT_v0.30.0.txt` after the branch run.

## v0.29.0 — Diplomacy & AI Kingdoms
- Adds five deterministic diplomatic personalities for the nine existing AI kingdoms.
- Adds a 45-pair player/AI relationship matrix with canonical keys and bounded relationship values.
- Adds peace, war, trade, alliance, tribute and vassal treaties with defined durations, income and capped gold transfers.
- Adds explainable deterministic acceptance weights, incoming proposals, stale-offer validation and negotiation cooldowns.
- Adds player/AI declarations of war, border tension, war causes, war exhaustion, AI-AI conflict resolution and four-turn truces.
- AI armies select only realms with an active war treaty as strategic targets.
- Adds the mobile diplomacy panel and relationship/treaty/war information.
- Adds optional `diplomacy_relations` and `pending_diplomacy_offers` save fields; `SAVE_VERSION` remains 1 and legacy saves receive defaults.
- Adds `DIPLOMACY.md`, `diplomacy_smoke_test.gd` and static QA guards.
- Static validation: 162/162. Godot parser/import, runtime smoke tests and Android validation remain pending because the Godot executable is unavailable in the build environment.

## v0.28.0 — Faction Founding & Kingdom Identity
- Adds a new-campaign founding panel with four peoples, four cultures, exactly two different traits and an editable kingdom name.
- Adds data-driven faction bonuses to the existing three-resource economy, recruitment costs, army upkeep, scouting radius and province capacity; no new resources or role IDs are introduced.
- Adds one-time starting resource/experience bonuses for the player and all nine AI kingdoms.
- AI kingdoms receive deterministic faction identities and use matching income, recruitment and upkeep modifiers.
- Adds a scrollable faction setup surface with a fixed 56 dp confirmation button and blocks map commands until founding is confirmed.
- Adds optional `player_faction` and `kingdoms[].faction` save fields; `SAVE_VERSION` remains 1 and legacy saves receive neutral/stable faction identities without retroactive starting bonuses.
- Adds `faction_setup_smoke_test.gd` and static QA guards for faction choices, modifiers, AI starting bonuses, save fallback and mobile setup behavior.
- Static validation: 140/140. Godot parser/import, runtime smoke tests and Android validation remain pending because the Godot executable is unavailable in the build environment.

## v0.27.2 — GDScript Typing & Warning Hotfix
- Fixes the `valid_province` type-inference error by explicitly typing the source cell value, validated array and boolean result.
- Renames `_make_city_record()`'s `name` parameter to `city_display_name`, avoiding `Node.name` shadowing.
- Renames `get_world_owner_at()` city-cell locals to `player_city_hex` and `kingdom_city_hex`.
- Replaces two city-distance integer-division expressions with the existing typed `WorldGeneratorScript.hex_distance()` helper.
- Adds regression checks for each reported error/warning.
- No gameplay values, persistent JSON fields, unit/building/resource IDs or save schema changed; save schema remains version 1.
- Static validation: 117/117. Godot parser/import and Android runtime checks remain pending.

## v0.27.1 — Campaign Loading Hotfix
- Fixes the GDScript parse error in `CampaignState.load_campaign()`: the per-city buildings array is now named `city_buildings_data`, avoiding a second declaration of `loaded_buildings` in the same function scope.
- No gameplay values, save fields, city data, building IDs, resource IDs or serialization behavior are changed.
- Adds a static QA regression guard for the exact duplicate-local declaration.
- Keeps campaign save schema version 1.
- Static validation: 113/113. Godot parser/import and Android runtime checks remain pending.

## v0.27.0 — World Exploration & Neutral Sites
- Adds up to 72 deterministic neutral points of interest with five terrain-compatible types and minimum five-hex spacing.
- Ensures at least four opening exploration targets in the start ring through a deterministic fallback candidate pool.
- Adds three guard tiers (3/5/8 troops), veteran experience, separate guardian commanders and persistent retreat damage.
- Victory clears a site and transfers its existing-resource reward to the nearest player city; cleared map history persists under the player's army marker.
- Adds six deterministic campaign events every five turns, each with two choices and cost/population validation.
- Reuses only gold, food, stored production, population, fog-of-war reveal and existing troop experience; no fourth resource is added.
- AI city founding and next-step army movement avoid neutral site hexes; AI neutral battles remain deferred.
- Keeps save schema version 1 with deterministic defaults for legacy saves.
- Static validation: 112/112. Godot parser/import and Android runtime checks remain pending.

## v0.25.0 — Army Veterancy & Upgrades
- Gives each surviving non-commander troop individual battle XP using `clamp(6 + kills × 8 + floor(damage / 30), 6, 30)`.
- Adds Recruit, Trained, Veteran and Elite ranks at 0/40/100/180 cumulative XP.
- Adds modest veteran bonuses to attack damage and armour without increasing max HP or healing.
- Adds two city-purchased upgrade ranks for all four stable unit role IDs, gated by existing buildings.
- Adds survivor XP and promotions to the tactical battle report.
- Preserves enemy survivors' veterancy through AI kingdom normalization.
- Keeps save schema version 1; old unit records default to 0 XP and missing army upgrade data defaults to rank 0.
- Static validation: 78/78. Godot runtime/parser and Android tests remain pending.

# Changelog

## v0.24.1 — Tactical Combat Expansion
- Completes the planned tactical-combat batch: terrain gameplay, flanking/status effects, role-aware target selection and battle-result statistics.
- Adds four symmetric seed-derived gameplay zones for woodland, highlands and marsh battles; grassland remains neutral.
- Adds forest cover (−10% movement, −18% incoming ranged damage), high ground (archer +10% ranged damage, −8% incoming ranged damage, −5% movement), and marsh (infantry −18% speed, cavalry −35% speed and no charge).
- Adds side/rear melee damage bonuses (+10%/+20%), a 1.8-second exposed status (+10% incoming damage), and +1 frontal armour under HOLD.
- Adds a light temporary status marker, role-aware target scoring and flank-hit statistics.
- Preserves the flat collider, current unit IDs, unit base catalog values, army cap, commander data and save-schema version.
- Adds terrain, flanking/status and AI target scoring smoke-test sources.
- Static validation: 70/70. Godot runtime/parser and Android tests remain pending.

## v0.24.0 — Tactical Flanking & Status (merged into v0.24.1 package)
- Adds the flank arc classification, side/rear modifiers, exposed status and HOLD frontal armour bonus.

## v0.23.0 — Tactical Terrain Zones (merged into v0.24.1 package)
- Adds deterministic non-colliding forest, high-ground and marsh zones to existing battle biomes.

## v0.21.1 — Pixel Terrain Type Fix
- Fixes the Sprite3D pixel-filter assignments to use `BaseMaterial3D.TEXTURE_FILTER_NEAREST`, matching the property enum expected by Godot 4.7.2.
- Adds a battlefield smoke-test assertion for nearest-neighbour filtering on billboard terrain props.
- Adds a static QA guard against reintroducing the CanvasItem/BaseMaterial3D enum mismatch.
- No changes to terrain art, units, cavalry, combat, AI, input, collision or save data.
- Static validation and ZIP integrity are re-run for this hotfix. Godot runtime and Android testing remain separate checks.


## v0.21.0 — Mythryl Pixel Terrain Battlefield
- Replaces the previous tactical ground texture and Tactics Terrain dressing with the user-supplied Mythryl Studio 2D Pixel Terrain 64px Free Edition.
- Builds the battle surface from true isometric 64x32 diamond tiles: varied grass, dirt roads, grass/dirt corner blends, shallow water and shoreline transitions.
- Batches the complete ground surface into one mesh and one atlas material to avoid a draw call per tile.
- Adds pack-native trees, pines, bushes, rocks, flowers and grass-cliff sprites across the four tactical biomes.
- Keeps props visual-only; no terrain collision, height rules or pathfinding changes are introduced.
- Preserves the original battlefield dimensions, movement plane, ground collider, camera, all unit sprites/animations (including cavalry), combat logic, AI, orders, projectiles, strategic map, campaign and save schema.
- Static validation: 48/48. Godot runtime and physical Android validation remain pending.

## v0.20.0 — Pixel Cavalry & 2.5D Battlefield
- Replaces the procedural low-poly cavalry with mounted pixel-art sheets for both factions.
- Adds mounted idle, gallop/run, rearing attack and jump/charge animations.
- Adds a nearest-filtered pixel-style ground surface and biome-aware battlefield dressing.
- Preserves the original movement plane, ground collider and combat simulation.

## v0.19.3 — Attack Command Reliability
- Makes a direct attack order clear stale cooldowns and immediately activate the unit.
- Prevents ally-separation steering from pushing units away from an ordered enemy.
- Directly ordered archers fire inside attack range instead of retreating due to preferred spacing.
- Adds regression coverage for attack orders, pursuit, stale cooldown and close-range ranged fire.
- Preserves gameplay stats, damage, AI and saves.

## v0.19.2 — Melee Contact Hotfix
- Restores the original melee reach when starting an attack.
- Commits a melee strike through its visible contact frame rather than rechecking a smaller radius after the wind-up.
- Prevents small target movement from cancelling a valid hit.
- Adds a regression test for a moving target.
- Preserves combat stats, AI, ranged timing, animations and save data.

## v0.19.1 — Combat Readability Pass
- Applies melee damage at the weapon-contact frame rather than at swing start.
- Delays arrow creation until the bow release frame.
- Turns sprites toward active targets during movement and combat.
- Ignores dead/corpse targets and cancels unfinished hits/projectiles when new orders arrive.
- Adds guard and lancer defence recovery poses, with more proportional lancer scaling.
- Adds smoke tests for hit timing, arrow release, corpses and order cancellation.
- Preserves unit stats, damage, cooldowns, AI and save data.

## v0.22.0 — Strategy & UI Icon Integration
- Integrates both supplied icon sets while retaining their source licences and original variants in the project.
- Gives strategic capitals and towns distinct player/AI pixel-art settlement markers; uses crossed swords for armies and a worker sprite for settlers.
- Adds compact gold, food and stored-production indicators to the mobile HUD and city panel.
- Adds contextual icons to city buildings, troop recruitment, attack, army and city actions.
- Keeps only implemented resources visible; wood and stone are not added to campaign economy or saves.
- Does not change campaign balance, combat, AI, tactical battlefield, controls or save format.
- Static validation and archive integrity are checked; Godot runtime and Android checks remain pending.

## UI skin
- Panels, buttons and focus frame now use 9-slice textures from Pixel UI Fantasy Free (CC BY 4.0), recoloured to the game palette. Flat styles remain as fallback. Not runtime-tested; open in Godot to import the PNGs.

## v0.26.0 — City Development & Economy
- Adds three population-based city levels (Settlement 1–7, City 8–13, Metropolis 14–20) and province capacities of 1/3/5.
- Adds four one-time specializations: +20% food, +20% gold, +20% production, or −10% gold recruitment cost.
- Adds four terrain-bound adjacent province improvements, each producing +2 of one existing resource per turn.
- Adds level-two and level-three upgrades for all six existing building IDs.
- Adds per-troop gold upkeep: melee 0.8, ranged 0.8, spear 0.9, cavalry 1.4; total is rounded up and paid from city treasuries after income.
- Adds a mobile city panel section for specialization, province improvements, building upgrades and army upkeep.
- Extends the AI economy with specializations, province projects, building upgrades and upkeep; capital AI prioritizes a market before repeated recruitment.
- Preserves the three-resource economy, stable resource/building/unit IDs, 24-troop cap and save schema version 1.
- Static validation: 93/93. Godot parser/import/runtime and Android tests remain pending.
