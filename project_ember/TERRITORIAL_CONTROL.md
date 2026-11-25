# Project Ember — Territorial Control & Frontier Fortifications

## Ownership model

Territory is calculated on demand from current campaign records. The game does not save a separate owner value for every world hex.

Owner IDs remain compatible with the strategic map:
- `-2`: player kingdom
- `0..8`: AI kingdoms
- `-1`: unclaimed land
- `-3`: disputed land

Each city is an influence source. Base influence power is 46 plus 1.8 per population, with +12 for the capital and +5 for a city specialized in military affairs. Influence loses 9.25 points per hex and is bounded to a radius of three to eight hexes.

A field army projects a smaller temporary source around its current location. Its power is 24 plus two per troop, capped at 60; influence loses ten points per hex and is bounded to a radius of two to five hexes. The field moves with the army and disappears if the army is destroyed.

When two rival kingdoms have positive influence scores within six points of one another, the hex becomes disputed. This prevents arbitrary ownership at overlapping frontiers. The strategic map marks those cells with an amber tint and a distinct boundary.

## Frontier watchtowers

Watchtowers are built as province improvements on forest or hill hexes adjacent to a city. They reuse current province slots and save records.

| Property | Value |
|---|---:|
| Gold cost | 55 |
| Production cost | 12 |
| Income | +1 production / turn |
| Influence power | 92 |
| Influence falloff | 10.5 per hex |
| Maximum influence radius | 8 hexes |
| Tactical bonus | +1 armour within 3 hexes in friendly territory |

The tactical bonus applies to the player's army only in kingdom battles. Neutral-site battles do not use it. It is transient battle state and is not added to the save file.

Threatened AI kingdoms may prioritize a watchtower when an unused province slot and an adjacent forest/hill hex are available. It is stored in the same `province_improvements` array as farms, trade posts, woodland camps and quarries.

## Settlement rules

A settler may found a city in unclaimed or player-controlled territory. It cannot found in a hex controlled by an AI kingdom or in a disputed hex. Existing spacing rules, terrain restrictions, neutral-site exclusions and the five-city cap remain in force.

## Compatibility and performance

- `SAVE_VERSION` remains 1.
- No new resource, city ID, unit role or building ID is added.
- Territory ownership is derived from city, army and improvement records at runtime.
- The map builds a compact owner lookup for visible cells and their immediate neighbors; it does not allocate or persist an owner grid for the full 24,031-hex world.
- Target-device Android rendering cost and long-term border balance still require device playtesting.
