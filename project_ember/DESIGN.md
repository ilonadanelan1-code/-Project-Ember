# Project Ember — Design Document

## Current release constraints — v0.34.0

- Tactical soldiers, commanders, cavalry, battlefield terrain and combat effects use the established pixel-art presentation.
- The historical v0.8.0 low-poly visual-overhaul notes below are superseded. They are not the current art target and must not be reintroduced into active combat rendering.
- SPRITE_ART_POLICY.md is authoritative: nearest-filtered animated pixel sprites are mandatory, the battlefield remains pixel-isometric, and the active runtime must never fall back to procedural low-poly soldiers.
- The active player field army still uses the legacy player_units / player_cell fields. Stage IV adds a hero roster; Stage V is responsible for independent player armies.
- Campaign save compatibility, stable unit/building/resource IDs and mobile performance remain release requirements.

## High concept

Fantasy 4X strategy with real-time tactical battles, built in Godot 4. The player rules a growing kingdom in a procedurally generated world, develops cities, recruits armies, commands heroes and decides between expansion, diplomacy and war.

The intended feel combines the strategic scope and hero progression of Age of Wonders, the personal army presence of Mount & Blade, and the readable group commands of classic RTS games such as Warcraft III. These are design references, not requirements to copy their exact systems.

## Core pillars

1. Player freedom: economy, warfare, exploration and diplomacy must all become viable paths.
2. Tactical readability: orders and unit intent must be understandable at a glance.
3. Meaningful heroes: rulers and lords influence both the campaign and combat.
4. A living procedural world: terrain, locations, settlements and events should feel authored even when generated.
5. Campaign continuity: losses, recruitment, construction and progression in one scene persist in the wider campaign.

## Core loop

Character and world setup → explore the hex map → found and develop cities → recruit and improve units → develop the ruler → fight tactical battles → apply survivors, losses and experience to the campaign → expand, negotiate or conquer.

## Major systems

### Strategic map

Hex-based overworld with terrain movement rules, cities, influence, armies, neutral locations and eventually multiple AI kingdoms. Generation settings should affect map dimensions, land/water distribution, islands, underground regions, neutral sites and difficulty.

### Cities and economy

Cities have independent population, food, gold, production, buildings and queues. Buildings unlock recruitment and provide economic bonuses. Current playable resources are food, gold and production; additional resources should wait until the core city/army loop is stable.

### Armies and units

An army is a campaign-level group of unit records plus heroes. Unit role identifiers are persistent save data and must remain stable. The current recruitable roster contains swordsmen, archers, spearmen and cavalry. Role data lives in `scripts/unit_catalog.gd` so recruitment, save validation and tactical combat use the same health, cost and combat profile values. Commanders are stored separately from the 24-troop recruitment capacity.

### Tactical combat

Real-time tactical battles run in a 3D Godot scene with a 2.5D pixel-art visual layer. Players can directly command groups with selection, movement, attack, attack-move, hold, stop, retreat and formations. Melee, ranged, spear and cavalry roles have distinct behavior. Commanders provide a passive leadership aura and a tactical Battle Cry ability. Battle results return troop survivors and commander health to the campaign.

### Heroes and progression

The ruler begins as a persistent level-one commander. Battle kills, damage and victory grant experience; levels grant skill points. Leadership improves the passive aura, Tactics improves Battle Cry, and Might improves commander health, armor and damage. The enemy force also fields a commander with an automatic Battle Cry decision. Defeated rulers are wounded rather than permanently removed and recover over campaign turns.

Additional lords, inventory, equipment, branching skill prerequisites and direct hero movement control remain later extensions.

### Diplomacy

Diplomacy will support relations, war, peace, alliances and trade. These systems remain later priorities until the tactical and city loops are enjoyable.

## Production rules

- Read the current project structure and affected scripts before editing.
- Prefer coherent feature batches, but keep changes reviewable and testable.
- Avoid full rewrites when extending existing systems is safer.
- Keep systems separated: map, city, army, combat, heroes, diplomacy and UI.
- Stability and playability take priority over feature count and visual polish.
- Every significant change must include automated checks where possible and clear phone-testing steps.
- Do not add multiplayer, complex physics, large quest systems or many races before the solo core loop is ready.

## Current state — v0.7.0

- Working Godot project with a 91-hex strategy map, multiple cities, independent economies, construction/recruitment queues, settlers and save/load.
- Tactical scene has real-time combat, basic enemy AI, selection, formations, attack-move, hold, stop, retreat, pause, speed controls, results and campaign survivor transfer.
- Recruitable roster: swordsmen, archers, spearmen and cavalry. Archery range and stable unlock ranged and mounted recruitment. Army capacity is 24.
- Touch/keyboard selection, four control groups and tactical camera pan/zoom input are implemented.
- Player ruler and enemy commander spawn as separate tactical units. Ruler progression, three skill branches, passive aura, Battle Cry, commander wounds/recovery and save/load are implemented.
- Godot 4.3 CI validates import, both scene startups, campaign logic, unit roster and hero progression. Physical Android runtime, touch feel, UI scaling and balance for the new commander interface require a fresh on-device test.

## Priority order

1. Tactical combat quality and army control.
2. City construction, economy and recruitment.
3. Strategic army movement and map interaction.
4. Hero abilities, lords, equipment and direct hero control.
5. Diplomacy and AI kingdoms.
6. World generation and content.
7. Art, UI polish, animation and sound.


## Visual direction — v0.8.0

The visual target is stylized low-poly fantasy: readable unit silhouettes, painterly terrain colors, dark bronze UI frames and restrained gold accents. The visual layer is deliberately separate from campaign records and tactical combat stats.

- Strategic map hex coordinates, terrain IDs, movement validation and city ownership remain authoritative. The map renderer adds shadows, terrain motifs, settlement silhouettes and banner markers without changing cell interactions.
- Tactical terrain is generated from lightweight meshes and MultiMesh batches. The ground collision body and camera are returned to the existing tactical controller unchanged.
- BattleUnit retains all health, damage, pathing, selection, attack and order behavior. A dedicated visual layer supplies animated pixel sprites for infantry, archers, spearmen, cavalry and commanders; the existing collision capsule remains on the gameplay root.
- All props use built-in Godot meshes and runtime materials. No external asset downloads or heavy rendering features are required.
- Rendering remains on Godot 4.3 GL Compatibility. Battlefield shadows are enabled, but the environment uses compact geometry and batched vegetation to stay appropriate for Android.

## v0.8.0 implementation boundaries

The visual overhaul must not alter campaign save keys, unit role identifiers, tactical damage calculations, movement speeds, formation slot calculations or input mapping. Visual smoke tests cover the new procedural environment and unit-model builders; the existing campaign, roster and hero progression tests remain required.


## Art direction — v0.9.0

The visual constraints, palette, faction identifiers and readability rules are documented in [ART_BIBLE.md](ART_BIBLE.md). Runtime color constants live in `scripts/art_palette.gd`. The project remains on Godot 4.3 GL Compatibility.


## Unit visual architecture — v0.9.1

Each troop uses two merged vertex-coloured mesh batches: a static body and a single action part. Team/role combinations are cached, and both batches share one material. The selection/target ring is one mesh that switches cached material; the health bar appears only when the unit is selected, targeted or wounded.

Animation is driven by the existing BattleUnit process without Skeletons or extra animation nodes. Attack damage, attack cadence, movement, target selection, collision and formation placement remain controlled by the original combat methods. Defeated units leave the combat group immediately; a limited number of visual corpses remain for 8–10 seconds based on quality settings.

The core BattleUnit scene budget is eight nodes including its collision capsule, selection indicator and health-bar meshes. CI creates 50 units and verifies the node budget and mesh/material reuse.

## Tactical biomes and terrain — v0.9.2

Battlefield presentation now resolves one of four biomes — grassland, woodland, highlands or marsh — from the six neighboring strategic hexes around the player's battle-origin cell. A deterministic seed derived from that cell keeps the ground dressing repeatable between runs. The tactical biome ID and seed are runtime presentation state only and are not added to the campaign save format.

Each biome uses a dedicated ground texture/palette and quality-scaled decoration profile. Woodland adds fallen logs and denser tree dressing; highlands add low rock shelves and more stones; marsh adds shallow decorative pools and reeds. The biome name is shown in the tactical HUD.

Terrain geometry is currently visual-only. The existing flat ground collision body, collision bounds, unit movement plane, spawn positions and formation calculations remain authoritative and unchanged. This keeps decorative rocks, pools and vegetation from blocking unit control. Gameplay effects from elevation, water and cover remain a later balance feature.


## v0.24.1 — Tactical combat mechanics

The tactical battle still uses a flat 3D movement plane and the existing battlefield collider. Gameplay terrain is applied through deterministic, non-colliding zones derived from the existing biome ID and battle seed. The seed and biome remain runtime-only; zones are rebuilt on battle load.

### Terrain zones

- Grassland: no special zones; all terrain multipliers remain 1.00.
- Woodland: four symmetric forest-cover zones. Inside a zone, all roles move at ×0.90 and incoming ranged damage is ×0.82.
- Highlands: four symmetric high-ground zones. Inside a zone, all roles move at ×0.95; archers deal ×1.10 ranged damage; incoming ranged damage is ×0.92.
- Marsh: four symmetric mud zones. Infantry and commanders move at ×0.82; cavalry moves at ×0.65 and cannot arm or apply a charge.
- Zone positions are determined by the existing battle seed. Each zone is visually marked with a light fill and border; markers do not add collision bodies or alter pathing.

### Flanking, exposed and HOLD

- Melee attack arcs use the target's last combat-facing direction. Frontal attacks have ×1.00 damage, side attacks ×1.10, and rear attacks ×1.20.
- A confirmed side/rear melee hit applies `exposed` for 1.8 seconds. The effect does not stack; a new flank hit refreshes the timer. While exposed, the unit receives ×1.10 damage after armour and terrain protection.
- A unit with the existing `HOLD` order gains +1 effective armour against frontal attacks. Side and rear attacks bypass this bonus.
- Ranged attacks do not receive flank bonuses. Existing spear-versus-cavalry and cavalry charge multipliers remain active and are applied alongside the new modifiers.
- The `exposed` overhead marker is allocated only while the effect is active and is removed when it expires, keeping the normal BattleUnit node budget unchanged.

### Role-aware target selection

Automatic target acquisition uses the score `100 × role_preference − 4 × distance + 10 × missing_health_ratio`. Archers prefer cavalry, spearmen strongly prefer cavalry, cavalry prefer ranged troops, and commanders slightly prefer nearby cavalry/ranged threats. The current target remains stable until it becomes invalid; direct attack commands keep their existing priority.

### Battle report and saves

The result panel and `last_battle_result` dictionary receive additive `player_flank_attacks`, `enemy_flank_attacks` and `terrain_rules_version` keys. No campaign save-schema version bump is required. Terrain zones, exposed timers, facing direction and per-unit flank counters are transient battle state; survivor records retain their existing role/health shape.

### New source modules

- `scripts/battlefield_rules.gd` — deterministic zone data and gameplay multipliers.
- `scripts/battlefield_zone_visuals.gd` — non-colliding zone markers.
- `scripts/battle_flanking.gd` — attack-arc classification and damage modifiers.
- `scripts/combat_status_catalog.gd` — status data.
- `scripts/battle_ai_tactics.gd` — role-aware target scores.

### Validation boundary

Static validation checks the new rule values, source references and tests. The actual Godot 4.7.2 parser/import, runtime smoke-test suite and Android GPU/FPS tests still need to be run in Godot and on the target phone.


## v0.25.0 — Army veterancy and city upgrades

Surviving non-commander troops now retain individual experience in their campaign records. Battle XP is awarded once after battle using `clamp(6 + kills × 8 + floor(damage_dealt / 30), 6, 30)`. Unit ranks are Recruit (0 XP), Trained (40), Veteran (100) and Elite (180). Their bonuses are respectively none, +3% damage, +6% damage/+1 armour, and +10% damage/+2 armour. Maximum health and current HP are not modified by veterancy.

The city window includes a two-column Military Training grid. Each existing role has two empire-wide upgrade ranks purchased for gold, requiring that role's existing unlock building. Melee gains armour (+1/+2 total; 55/90 gold), ranged units gain damage (×1.06/×1.12 total; 65/105 gold), spearmen gain anti-cavalry multiplier (+0.10/+0.20; 60/95 gold), and cavalry gains charge multiplier (+0.08/+0.16; 85/135 gold). Rank-two values are totals, not additive to rank one. Upgrades affect current and future player troops when they next spawn into battle.

AI kingdom survivors receive the same battle XP and keep it through kingdom normalization. AI purchase of permanent upgrades is deferred until per-kingdom upgrade persistence and economy balance are implemented.

Save compatibility: `SAVE_VERSION` remains 1. Old troop records default to 0 XP; missing root `army_upgrades` defaults to rank 0 for all four stable roles. Temporary battle XP fields are removed before campaign save. No unit IDs, base catalog prices, resources or army cap are changed.

Validation: 78/78 static QA checks pass; the new `unit_progression_smoke_test.gd` covers XP thresholds, capped awards, legacy record defaults, upgrade costs/building requirements, save/load, AI normalization and combat modifiers. Godot parser/import/runtime tests and Android device validation remain pending because the engine executable is unavailable in the build environment.


## v0.26.0 — City development and economy

The city economy now adds three population-based city levels: Settlement (population 1–7, one province slot), City (8–13, three slots), and Metropolis (14–20, five slots). Reaching level 2 unlocks one permanent specialization: Agriculture (+20% food income), Commerce (+20% gold income), Industry (+20% stored production income), or Military (−10% gold recruit cost).

Cities can improve suitable adjacent owned hexes: farm plots on plains/farmland (+2 food/turn), trade posts on plains/farmland (+2 gold/turn), woodland camps in forests (+2 production/turn), and stone quarries on hills (+2 production/turn). Province capacity is limited by city level. All effects use only the existing gold, food and production resources.

The six existing buildings retain their IDs and gain level 2/3 improvements. Farms, markets and workshops increase the corresponding existing income; barracks, archery ranges and stables reduce gold recruitment costs for the roles they unlock. Building levels require corresponding city levels and are stored separately from the existing building ID list.

Living troops now cost upkeep per turn: melee 0.8, ranged 0.8, spear 0.9 and cavalry 1.4 gold. Total army upkeep is the rounded-up sum and is paid from player city treasuries after all city income is collected. A shortfall is displayed but does not cause desertion in this first pass. The AI uses the same rates and prioritizes a capital market before repeated recruitment so it does not spend its reserve without offsetting upkeep.

Save schema stays at version 1. Legacy cities default to no specialization, level 1 for existing buildings, no province improvements and zero prior upkeep. Queue records for building upgrades and province improvements are normalized on load. Detailed tables, formulas, UI behavior and deferred systems are documented in `CITY_DEVELOPMENT.md`.

Static validation: 93/93. The new `city_development_smoke_test.gd` source is included. Godot import/parser/runtime and Android UI/FPS tests remain pending; they were not executed in the build environment.

## Hotfix — v0.27.1 Campaign Loading

`CampaignState.load_campaign()` loads the legacy capital building list and then iterates over additional city records. The inner record previously redeclared the local name `loaded_buildings`, which Godot reports as a duplicate variable in the same function scope. The additional-city local is now named `city_buildings_data`; the contents passed to `_make_city_record()` and all save fields remain unchanged. Save schema remains version 1. Static validation: 113/113; the Godot parser and Android runtime still require device/editor verification.

## Current implementation — v0.27.0 World Exploration

- Adds up to 72 deterministic neutral points of interest with a minimum five-hex spacing and a minimum of four opening exploration targets for the supported start area.
- Adds five terrain-bound location types: ancient ruins, monster lairs, abandoned mines, forgotten shrines and mercenary camps.
- Neutral guards have three tiers (3/5/8 troops), persistent survivors and guardian health; victory clears the site and pays its three-resource reward into the nearest player city.
- The strategic map only reveals markers through explored fog-of-war cells. Tapping an adjacent site launches the existing tactical battle scene.
- Adds six concise campaign events on a five-turn cadence, each with two choices. Existing gold, food, stored production, population, map reveal and troop XP are reused; no fourth resource is introduced.
- AI kingdom expansion and its next-step army movement avoid POI hexes; AI neutral-site battles are deferred.
- Cleared points remain as inert map history if the victorious army occupies their hex. Legacy occupied, uncleared points are filtered on load.
- Adds `neutral_locations`, `pending_world_event`, `last_world_event_text` and `world_events_resolved` to save data without changing `SAVE_VERSION := 1`.
- See `WORLD_EXPLORATION.md` for exact tables, formulas, save fields, UI, AI rules, risks and release checks.
- Static validation for the v0.27.0 feature baseline: 112/112. Current v0.27.1 hotfix validation: 113/113. Godot parser/import, GDScript runtime tests and Android device checks remain pending because the build environment has no Godot executable.


## v0.28.0 — Создание королевства и фракционные стили

Перед новой кампанией игрок выбирает один из четырёх народов (`riverfolk`, `stoneborn`, `steppe_clans`, `woodland_kin`), одну из четырёх культур (`agrarian`, `mercantile`, `artisan`, `warrior`), ровно две разные черты из шести и название королевства. Народы и культуры не добавляют отдельные роли войск: они специализируют существующие `melee`, `ranged`, `spear`, `cavalry`, экономику и разведку.

Народ `riverfolk` даёт +12 стартовой еды и +1 еды/ход за ферму; `stoneborn` — +8 стартового накопленного производства и +1 производства/ход за мастерскую; `steppe_clans` снижают цену найма кавалерии до ×0,88 и её содержание до ×0,90; `woodland_kin` снижают цену найма лучников до ×0,88 и дают армии +1 гекс обзора. Культуры дают соответственно +2 еды за ферму, +2 золота за рынок, +2 производства за мастерскую или общую цену найма ×0,94.

Черты: `disciplined` — содержание армии ×0,92; `veteran_cadre` — +20 XP каждому стартовому бойцу; `frontier_guides` — +1 гекс обзора; `provincial_charters` — +1 провинциальный участок в каждом городе (общий максимум 6); `guild_charters` — цена найма ×0,94; `public_granaries` — +1 еды/ход в каждом городе. Фиксированные доходные бонусы складываются, множители скидок перемножаются. Совокупная скидка найма ограничена 25% (`clamp` множителя от 0,75 до 1,00).

Все девять ИИ-королевств получают детерминированные фракции и используют те же доходные, кадровые и содержательные модификаторы. Одноразовые стартовые запасы и опыт применяются к ИИ при новой генерации мира, без повторного начисления при загрузке старой кампании.

Новая кампания ждёт подтверждения выбора фракции; пока панель открыта, команды карты заблокированы. Описания прокручиваются в вертикальном ScrollContainer, кнопка основания остаётся закреплена внизу. Название королевства по умолчанию зависит от народа и может быть изменено.

Сохранение получает необязательные поля `player_faction` и `kingdoms[].faction`; `SAVE_VERSION` остаётся 1. Старые кампании без выбора получают нейтральную идентичность `legacy`, а стартовые бонусы задним числом не начисляются. ID ролей, зданий и ресурсов не меняются; четвёртый ресурс, уникальные расы/роли и дерево исследований отложены. Полные таблицы, формулы и UI описаны в `FACTION_CREATION.md`.

Статический QA: 140/140. `faction_setup_smoke_test.gd` добавлен, но не исполнялся; Godot 4.7.2 parser/import и Android device validation остаются обязательными внешними проверками.

## v0.29.0 — Дипломатия и характеры королевств

Все девять ИИ-королевств получают один из пяти детерминированных характеров: завоеватель, торговец, изоляционист, хранитель клятв или покоритель рубежей. Между игроком (`-1`) и девятью ИИ, а также между всеми парами ИИ хранится шкала отношений `-100..+100` — всего 45 записей с каноническими ключами `lower_id:higher_id`.

Добавлены договоры `peace`, `war`, `trade`, `alliance`, `tribute` и `vassal`. Торговля длится 6 ходов и даёт обеим сторонам +2 золота/ход; союз длится 8 ходов с тем же доходом; дань длится 5 ходов, вассалитет — 10, выплата составляет до 3 золота/ход и не может опустить казну ниже нуля. После окончания войны при заключении мира действует перемирие на 4 хода. Усталость войны растёт на 5/ход.

Игрок может предлагать торговлю, союз и мир, требовать дань или вассалитет и объявлять войну. Шансы приёма рассчитываются по отношению, характеру, соотношению силы армий и усталости войны, затем применяются детерминированно от seed/ID/хода. Входящие предложения ИИ имеют срок жизни 3 хода; одновременно хранится не более четырёх, не более одного от каждой державы и с четырёхходовым кулдауном.

Пограничное напряжение при расстоянии до 4 гексов постепенно ухудшает отношения агрессивных держав; при достижении порога возможна война. Армии ИИ двигаются к противнику только при активном договоре `war`. Войны ИИ–ИИ могут завершиться автоматическим миром после накопления усталости. Причина войны (`player_declaration`, `battle_provocation`, `border_tension`, `resolved`) отображается в дипломатической панели.

Сохранение получает необязательные поля `diplomacy_relations` и `pending_diplomacy_offers`; `SAVE_VERSION` остаётся 1. Старые кампании получают 45 новых отношений из seed мира и пустую очередь предложений. Не добавляются новые ресурсы или ID королевств/юнитов/зданий. Подробные таблицы, формулы, пороги, UI и тест-план находятся в `DIPLOMACY.md`.

Статический QA: 162/162. `diplomacy_smoke_test.gd` включён (исходник, не запускался). Godot parser/import/runtime и Android validation требуют отдельного прогона в среде с Godot 4.7.2.


## v0.32.0 — Strategic kingdom AI

The campaign AI now uses a shared deterministic planner rather than relying only on a fixed building/recruitment sequence. At each kingdom turn it estimates city income, treasury reserves, unit upkeep, population and force strength; selects an economic focus and a sustainable army target; and chooses a recruitment role from doctrine plus the active enemy roster. Capital orders protect the market before recruiting, while secondary cities develop food and production according to the kingdom's current needs.

Settlement founding is permitted only when the realm has a minimum reserve and can sustain the new city without ignoring a nearby military threat. Candidate hexes are scored by terrain productivity, useful neighboring terrain, distance from existing cities and rivals, and proximity to neutral sites. During active wars the army selects a treaty opponent using distance, relative army strength and the proximity of the enemy force to its own cities. A war army will not leave an active campaign to pursue a peaceful neutral expedition.

Planner output is transient turn state. No new mandatory campaign fields, resources, stable unit IDs or building IDs are introduced; `SAVE_VERSION` remains 1. Balance and actual Android performance remain subject to longer device playtests.


## v0.33.0 — Territorial control and frontier fortifications

Territory is calculated deterministically from the current settlements, field armies and watchtowers. Cities project a broad influence field based on population, capital status and military specialization. Armies add a smaller temporary field around their current strategic position. If two rival kingdoms have comparable influence on a hex, the cell becomes disputed instead of being assigned to whichever kingdom is processed first. The strategic map renders player, AI and contested regions without persisting a second world-sized ownership grid.

Watchtowers are a new forest/hill province improvement. They cost 55 gold and 12 production, add one production each turn, and project influence up to eight hexes from their location. In a kingdom battle, player troops gain +1 armour when the battle takes place within three hexes of a friendly watchtower and the origin hex remains under friendly control. Neutral-site battles do not receive the fortification bonus. Threatened AI kingdoms can prioritize building a watchtower in a free forest/hill province.

A settler may establish a city in neutral or friendly territory but cannot plant a new settlement inside rival-owned or contested land. Territorial ownership is recalculated from the existing records each time it is needed. No new mandatory campaign fields, resource IDs or save migration are introduced; `SAVE_VERSION` remains 1. Long-campaign balance and Android rendering cost remain device-playtest items.
