# Project Ember — Design Document

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

Real-time 3D battles using simple meshes for now. Players can directly command groups with selection, movement, attack, attack-move, hold, stop, retreat and formations. Melee, ranged, spear and cavalry roles have distinct behavior. Commanders provide a passive leadership aura and a tactical Battle Cry ability. Battle results return troop survivors and commander health to the campaign.

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
