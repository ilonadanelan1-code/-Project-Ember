# Android Start — Project Ember v0.6.0

1. Extract the ZIP archive.
2. Open Godot Android Editor and import the extracted `project.godot` file.
3. Wait for project import, then press Play.

## Strategy and recruitment

- Build Barracks to unlock swordsmen and spearmen.
- Build an Archery Range (requires Barracks) to unlock archers.
- Build a Stable (requires Barracks) to unlock cavalry.
- The army capacity is 24 units. New recruits are added to the strategic army when their production order completes.

## Tactical battle controls

- Tap a friendly unit to select it. Tap another friendly unit with the **ДОБОР** toggle enabled to add/remove it.
- Drag across the battlefield to select all friendly units inside the rectangle.
- Tap an enemy with units selected to focus their attacks on it.
- Tap empty ground to move selected troops to a formation. Toggle **МАРШ** for attack-move orders.
- **ДЕРЖАТЬ** defends the current positions; **СТОП** cancels movement; **ОТСТУП** orders selected troops to withdraw.
- Cycle **ЛИНИЯ / КОЛОННА / КЛИН** to change formation layout. Spearmen occupy the front rank, swordsmen support them, cavalry takes the wings and archers stay behind.
- On a touch screen, drag with a second finger to pan the view; use a pinch gesture when the device emits magnify events. The on-screen zoom buttons remain available.
- Use the on-screen **ЗАПИСЬ** toggle and **ГР. 1–4** buttons to save and recall groups on touch devices. On a keyboard, `Ctrl+1..4` saves the selected group and `1..4` recalls it.
- On a keyboard, use `A` for attack-move mode, `H` for hold, `S` for stop, `R` to restart the isolated battle, and arrow keys to pan.

## Test status

GitHub Actions validates GDScript import, starts the strategic and tactical scenes headlessly, and runs campaign and roster smoke tests on Godot 4.3. Physical Android runtime, touch behavior, UI scaling and new-unit combat balance still need hands-on testing. Keep the previous ZIP until this version has been imported and checked on the phone.