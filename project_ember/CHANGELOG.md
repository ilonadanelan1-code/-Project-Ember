# Changelog — Project Ember

## v0.7.0 — Hero Commanders and Progression

- Added a persistent ruler hero and enemy commander to every campaign.
- Added commander combat units with their own health, level-scaled health/damage/armor, distinct 3D crown and armor visuals, and independent persistence outside the 24-troop recruitment cap.
- Added a passive commander aura that improves nearby allied damage and movement.
- Added the active **Battle Cry** ability: nearby allies receive healing and a temporary combat buff. It has a tactics-scaled cooldown and a touch-screen button plus the Q keyboard shortcut.
- Added enemy commander AI that uses Battle Cry when its nearby force is wounded.
- Added post-battle hero experience from kills, damage and victory; each level grants one skill point.
- Added Leadership, Tactics and Might skill branches, with five ranks each.
- Added commander health persistence, defeated-hero wounds and recovery over campaign turns.
- Added hero profile and skill-upgrade UI to the city panel, plus commander level and ability status in the tactical interface.
- Kept older saves compatible by supplying default hero records when hero data is absent.
- Added automated hero progression, ability, aura, wound recovery and save/load smoke tests.

## v0.6.0 — Expanded roster and battlefield command update

- Added a centralized unit catalog so economy, recruitment, campaign saves and tactical combat share one source of truth for unit data.
- Added spearmen with extra armor, longer melee reach and a damage bonus against cavalry.
- Added cavalry with higher health and movement speed plus a reusable charge strike after a fast approach.
- Added an archery range and stable as city buildings; both require completed barracks.
- Expanded army capacity from 16 to 24 units.
- Added persistent recruitment and save validation for all four unit roles while keeping old melee/ranged saves compatible.
- Updated city recruitment UI to show all roles and their specific building unlocks.
- Added cavalry wing placement and spear / sword / archer rank behavior to line, column and wedge movement orders.
- Added drag-box selection, additive selection support, four touch-screen and keyboard control groups, battlefield panning and gesture zoom.
- Added selected-army composition readout and surviving-unit composition to battle results.
- Added automated roster, unlock, recruitment, stat and save-normalization smoke tests.
- Android device testing is still required for touch gestures, UI fit and in-game balance.

## v0.5.3 — Audit fixes and strict validation

- Repaired the city production-queue summary parser error.
- Fixed the undefined recruitment label in `queue_recruit()`.
- Added explicit types where Godot 4.3 could not infer values from the campaign autoload.
- Changed the tactical scene root to Node3D to match its 3D script.
- Preserved unreadable campaign saves before starting a replacement campaign; disables automatic overwriting if preservation fails.
- Ensured newly produced settlers spawn on an in-bounds, unoccupied map hex.
- Made CI fail when Godot logs script, parse or engine errors, even if the process exits with code zero.
- Added campaign smoke tests for queueing, recruitment, army capacity, multiple-city income and save/load.
- Physical Android import, touch input and device runtime validation remain pending.

## v0.5.2 — Reliability and UI audit

- Replaced unbounded city production `while` loop with a bounded queue pass (maximum 32 orders per city turn).
- Added a defensive army-size check when completing recruitment orders.
- Repaired mojibake in campaign messages and queue labels.
- Explicitly set button focus and mouse-filter behavior in both strategic and tactical interfaces.
- Added Godot 4.3 headless import and startup checks to the packaging workflow.
- Android touch/runtime behavior still requires validation on a physical device.

## v0.5.1 — Tactical timer fix

- Fixed battle timer minute calculation to avoid integer-division warnings in GDScript.
- Explicitly typed elapsed seconds, minutes and remaining seconds; clamped negative elapsed time to zero.
- Runtime test on Godot Android Editor is still pending.

## v0.5.0 — Settlements and expansion

- Expanded the strategic map to 91 hexes and adjusted hex size for mobile viewport.
- Added up to five cities, each with independent population, food, gold, production, buildings and production queue.
- Added settler production (45 gold, 10 production, one population), movement and city founding at least three hexes from existing cities.
- Added city selection and claimed territory highlighting.
- Preserved legacy single-city save data when loading older campaigns.
- Restored tactical combat scripts and scenes in the extracted source tree.
- Runtime test on Godot Android Editor is still pending.

## v0.4.0 — First city and economy loop

- Added city resources, population, buildings, construction queue, recruitment and campaign saving.
