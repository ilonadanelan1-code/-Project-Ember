# Android Start — Project Ember v0.10.1 (Godot 4.3)

1. Extract the ZIP archive.
2. Open Godot Android Editor and import the extracted `project.godot` file.
3. Wait for filesystem scan and script import to finish, then press Play.
4. Keep the previous ZIP until the new source has been imported and checked on the phone.

## UI-1 mobile foundation

- The project is configured for **Sensor Landscape**: rotate the phone 180° and it should remain in landscape, using the opposite side.
- UI dimensions now use `UiMetrics.dp()`, calculated from screen DPI, viewport/window scaling and the selected UI scale (0.8–1.6).
- The strategy, battle and FPS HUD roots use a `SafeAreaContainer` which refreshes after window/viewport size changes.
- The shared `TouchGestureRouter` recognizes tap, double tap, long press, drag, pinch and two-finger pan and checks whether a touch began over a Control. During UI-1 the legacy world input is deliberately retained; the new router is the common foundation for the Battle HUD and Map HUD passes.
- Godot's `emulate_mouse_from_touch` remains enabled so existing Buttons and ScrollContainers keep receiving input. The router suppresses duplicate world mouse events when configured to consume them; the current legacy screens still process the existing mouse-emulated world input.
- Android Back closes the topmost dialog/panel. In battle it pauses the fight; on the map it closes the city/settings panel, or opens settings when no panel is open.
- When the app is backgrounded, the map saves the strategic state. A tactical battle pauses and does **not** overwrite the last strategic save.
- New Campaign requires holding the red **СТЕРЕТЬ ПРОГРЕСС** action for one second. A regular tap will not reset the campaign.
- Campaign persistence writes a temporary JSON file, validates it and rotates the previous valid file to `.bak`. The original JSON v1 keys remain unchanged.

## Compact HUD controls (v0.9.5)

- The strategic map opens with a short top status bar and a compact bottom dock: **АРМИЯ**, **ГОРОД**, **ХОД**, **ЕЩЁ**.
- Tap **ЕЩЁ** to reveal Attack, New Campaign, Found City and Settings. Tap **ЗАКРЫТЬ** or Android Back to collapse the drawer.
- Tactical combat opens with a compact dock: **ВСЕ**, **МАРШ**, **ПАУЗА**, **КОМАНДЫ**.
- Tap **КОМАНДЫ** for selection mode, Hold, Stop, Clear, Formation, Retreat, Speed, Zoom, Battle Cry, control groups and Settings. Scroll inside the drawer if every command does not fit at once.
- The secondary command panels are collapsed by default so they do not cover the strategic map or battlefield. Their buttons keep the existing touch-target sizing.

## Render performance hotfix (v0.10.1)

- Strategic terrain uses a single MultiMesh draw batch for all visible hexes, rather than separate drawing commands for each tile.
- Turn on the FPS overlay to inspect **CPU ms**, **Draw calls**, **Гексы на экране** and **Батчей рельефа**.
- On the strategic map, the terrain batch count should show **1** whenever hexes are visible.
- Compare draw calls and FPS at the default view and while zoomed far out. Please report both the FPS and the draw-call count; the CI test cannot measure actual Android GPU performance.

## Expanded world and kingdoms (v0.10.0)

- The world contains **24,031 hexes**. Terrain is generated as the map is viewed; the game does not load all tiles as scene nodes.
- Drag one finger across empty map space to pan. Use two fingers to pan/zoom. On desktop, middle-mouse drag pans, the wheel zooms, and arrow keys move the map.
- The **КОРОЛЕВСТВА** entry is inside the **ЕЩЁ** drawer. It lists all nine AI realms, their rulers, city/army counts and latest recorded action.
- Tap an enemy army marker to select that kingdom. When your army is adjacent, use **АТАКОВАТЬ** from the **ЕЩЁ** drawer.
- Every player turn also advances all nine AI kingdoms: income, population, construction, recruitment, settlement expansion and army movement are processed automatically.
- AI armies use faction-coloured numbered markers; your army remains marked **P**. Cities and nearby claimed cells use their kingdom's colour.
- Existing v0.9.x campaign saves are migrated additively. The player's current capital, city economy and army are retained; the old enemy becomes the first AI kingdom.

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

## Tactical controls (legacy layout retained in UI-1)

- Tap a friendly unit to select it. Tap another friendly unit with **ДОБОР** enabled to add/remove it.
- Drag across the battlefield to select all friendly units inside the rectangle.
- Tap an enemy with units selected to focus their attacks on it.
- Tap empty ground to move selected troops to a formation. Toggle **МАРШ** for attack-move orders.
- **ДЕРЖАТЬ** defends the current positions; **СТОП** cancels movement; **ОТСТУП** orders selected troops to withdraw.
- Cycle **ЛИНИЯ / КОЛОННА / КЛИН** to change formation layout.
- Use **ЗАПИСЬ** and **ГР. 1–4** to save and recall groups on touch devices.
- On a keyboard, use `A` for attack-move, `H` for hold, `S` for stop, `Q` for Battle Cry, `R` to restart the isolated battle, and arrow keys to pan.

## Optional Android immersive display

To hide Android system bars, open **Project → Export**, select the Android export preset, then inspect **Options → Screen → Immersive Mode** and enable it if available in that preset/version of Godot. This is an optional export setting, not a dependency: Android/device policy may still reveal system bars for navigation, accessibility or security. Keep the interactive HUD clear of the physical screen edges even when immersive mode is enabled.

## Validation and known limits

GitHub Actions validates GDScript import, strategic/tactical startup, existing campaign/unit/hero/biome/combat-effect tests and the new UI-1 dp, gesture, component, atomic-save and campaign-reset tests.

**Not verified on a physical Android device:** exact safe-area insets, actual 48 dp touch dimensions, reverse-landscape behavior on the target phone, vibration strength, app resume behavior after a real phone call, and visual readability at UI scale 1.6. The Battle HUD redesign, world gesture commands, left-handed layout mirroring and Map HUD/main menu are scheduled for UI-2 and UI-3. Keep the previous ZIP until the on-device checks pass.
