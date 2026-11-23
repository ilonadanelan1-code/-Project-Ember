# Project Ember — Tasks

## v0.5.0 source implementation

- [x] Expand strategic map to 91 hexes.
- [x] Add multiple cities with independent economies and queues.
- [x] Add settler production, movement and city founding.
- [x] Add city selection and territory highlighting.
- [x] Preserve v0.4.0 legacy city data when loading older saves.
- [x] Restore tactical combat scripts and scenes into the source tree.
- [ ] Import and run v0.5.0 in Godot Android Editor.
- [ ] Verify settler production, movement and city founding.
- [ ] Verify both cities gain resources independently and survive app restart.
- [ ] Verify tactical battle and survivor transfer after founding a city.

## Next batch

- [ ] City list and quick switching.
- [ ] Neutral resource sites and camps.
- [ ] Roads and trade routes.
- [ ] AI settlement expansion.


## v0.5.3 audit status
- [x] Fixed GDScript parser error in the city production queue summary.
- [x] Fixed recruitment queue message referencing an undefined variable.
- [x] Added explicit GDScript types for Godot 4.3 inference failures.
- [x] Matched the tactical scene root type to its Node3D script.
- [x] Preserved unreadable saves before creating replacement data.
- [x] Added in-bounds settler spawn selection for cities founded near the map edge.
- [x] Made Godot log errors fail CI validation.
- [x] Added automated campaign logic smoke tests.
- [ ] Import and run in Godot Android Editor.
- [ ] Verify touch controls and UI scaling on a physical Android device.
