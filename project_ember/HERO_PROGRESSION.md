# Hero Progression — Project Ember v0.7.0

## The ruler

Every campaign starts with a persistent ruler-commanding hero. The enemy force also fields a commander. Commanders are battlefield units but are stored separately from recruitable troops and do not use the 24-slot army capacity.

Campaign saves retain hero name, title, level, experience, skill points, skill ranks, current health and wounds. Older saves without hero records receive default level-one commanders.

## Experience and levels

After each tactical battle the player's ruler receives:

`35 + 10 × enemy kills + floor(player damage / 40) + 60 for victory (20 for defeat)`

The next-level threshold is:

`100 + 75 × (current level - 1)`

Each level grants one skill point. Maximum ruler level is 30.

## Skill branches

Each skill can be upgraded to rank 5. One skill point buys one rank.

- **Leadership:** expands the command aura and improves allied damage and movement bonuses.
- **Tactics:** extends Battle Cry and increases its effect while reducing cooldown.
- **Might:** adds commander health, melee damage and armor.

## Battlefield rules

- Base commander health is 210; each hero level adds 16 health.
- The passive aura reaches 7.0 world units plus 0.85 per Leadership rank. It grants 4% damage and 3.5% movement speed before skill bonuses.
- Battle Cry heals nearby allies by 12% of maximum health and applies a temporary combat buff.
- Battle Cry cooldown starts at 28 seconds and is reduced by Tactics, to a minimum of 14 seconds.
- Enemy commanders automatically use Battle Cry when three or more allies are nearby and at least two are wounded.
- A defeated ruler is wounded, not permanently killed. The hero returns with 35% health on the next campaign turn and recovers over subsequent turns.

Leadership is the army-support path, Tactics is the active-ability path, and Might is the frontline combat path. Recruitable lords and the persistent hero roster are implemented in v0.34.0. Equipment, prerequisite-based branching trees and direct hero movement remain future work.

## v0.34.0 — Recruitable Lords & Hero Roster

The player's ruler and recruited lords are stored in an additive hero_roster array with stable IDs. active_hero_id selects the commander assigned to the existing player field army; the legacy player_hero dictionary remains as the active-commander compatibility field used by current battle code.

Three lords can be hired from the city panel for 100 gold each:

- **Рагнар Вест — Маршал рубежа:** starts with Leadership rank 1.
- **Мирена Астэр — Полевая тактик:** starts with Tactics rank 1.
- **Торвальд Крей — Чемпион авангарда:** starts with Might rank 1.

The roster holds the ruler plus up to three recruited lords. Hiring is paid from the currently selected city's gold. Switching commander keeps each hero's level, experience, skill ranks, health and wounds; only the selected hero receives battle experience and joins the next battle as commander. Inactive heroes recover between campaign turns.

Old campaign saves without hero_roster are migrated from their existing player_hero record to a one-entry roster. The save schema remains version 1. Independent player armies and one-hero-per-army assignment are intentionally Stage V; Stage IV does not split the existing army or alter its movement/combat records.
