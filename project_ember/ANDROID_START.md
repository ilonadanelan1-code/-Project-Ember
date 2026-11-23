# Android Start — Project Ember v0.7.0

1. Extract the ZIP archive.
2. Open Godot Android Editor and import the extracted `project.godot` file.
3. Wait for project import, then press Play.

## Strategy, city and recruitment

- Build Barracks to unlock swordsmen and spearmen.
- Build an Archery Range (requires Barracks) to unlock archers.
- Build a Stable (requires Barracks) to unlock cavalry.
- Army capacity is 24 troops. New recruits join the strategic army when their production order completes.
- Open a city to view the ruler's level, experience, wounds and skill points.
- Spend skill points in Leadership, Tactics or Might. Each branch can be raised to rank 5.

## Commander and tactical battle

- The ruler appears on the battlefield as a commander. The enemy army also has a commander.
- A commander's passive aura strengthens nearby friendly troops.
- Tap **БОЕВОЙ КЛИЧ** during battle to heal nearby allies and give them a temporary damage and movement bonus. The button shows its remaining cooldown.
- Keyboard shortcut for Battle Cry: `Q`.
- Commander experience is earned from battle kills, damage and victory. Each level grants one skill point.
- If the ruler is defeated, the commander returns wounded and recovers over subsequent campaign turns; the campaign save retains health and progression.

## Tactical controls

- Tap a friendly unit to select it. Tap another friendly unit with **ДОБОР** enabled to add/remove it.
- Drag across the battlefield to select all friendly units inside the rectangle.
- Tap an enemy with units selected to focus their attacks on it.
- Tap empty ground to move selected troops to a formation. Toggle **МАРШ** for attack-move orders.
- **ДЕРЖАТЬ** defends the current positions; **СТОП** cancels movement; **ОТСТУП** orders selected troops to withdraw.
- Cycle **ЛИНИЯ / КОЛОННА / КЛИН** to change formation layout.
- Use **ЗАПИСЬ** and **ГР. 1–4** to save and recall groups on touch devices.
- On a keyboard, use `A` for attack-move, `H` for hold, `S` for stop, `Q` for Battle Cry, `R` to restart the isolated battle, and arrow keys to pan.

## Validation status

GitHub Actions validates GDScript import, strategic/tactical scene startup, campaign economy/recruitment/persistence, the four-role unit roster and hero progression/commander abilities on Godot 4.3.

The v0.6.0 source was previously confirmed to run on the target phone. This v0.7.0 update still needs a fresh Android Editor import and hands-on test of commander visuals, Battle Cry touch input, skill buttons, UI scaling and battle balance. Keep the previous ZIP until those checks are complete.
