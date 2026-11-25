#!/usr/bin/env python3
"""Fast, dependency-free checks for a Project Ember source tree."""
from __future__ import annotations

import hashlib
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
failures: list[str] = []
checks = 0


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if condition:
        print(f"PASS: {message}")
    else:
        failures.append(message)
        print(f"FAIL: {message}")


check((ROOT / "project.godot").is_file(), "project.godot exists")
check((ROOT / "scenes/strategy_map.tscn").is_file(), "strategic map scene exists")
check((ROOT / "assets/hex_terrain/tileset_64.tres").is_file(), "combined 64px Hex Terrain TileSet exists")
check((ROOT / "assets/hex_terrain/LICENSE.txt").is_file(), "Hex Terrain Bundle license is included")
check(len(list((ROOT / "assets/hex_terrain").glob("*_64.webp"))) == 6, "six lossless WebP terrain atlases are included")
tileset_path = ROOT / "assets/hex_terrain/tileset_64.tres"
tileset_text = tileset_path.read_text(encoding="utf-8") if tileset_path.is_file() else ""
tile_names = re.findall(r'custom_data_0 = "([^"]+)"', tileset_text)
check(len(tile_names) == 448 and len(set(tile_names)) == 448, "TileSet contains 448 uniquely named authored hex tiles")
atlas_paths = re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)"', tileset_text)
check(len(atlas_paths) == 6 and all(path.startswith("res://assets/hex_terrain/") and (ROOT / path[6:]).is_file() for path in atlas_paths), "all six TileSet atlas source paths resolve")
check("tile_size = Vector2i(64, 64)" in tileset_text and "tile_shape = 3" in tileset_text and "tile_offset_axis = 0" in tileset_text, "TileSet uses 64px pointy-top horizontal-offset hex cells")
renderer_path = ROOT / "scripts/hex_terrain_tilemap_renderer.gd"
renderer_text = renderer_path.read_text(encoding="utf-8") if renderer_path.is_file() else ""
check("atlas.get_tiles_count()" in renderer_text and "atlas.get_tile_id(tile_index)" in renderer_text and not re.search(r"\batlas\.get_tiles\s*\(", renderer_text), "atlas enumeration uses the supported TileSetSource index API")
feature_block = renderer_text.split("const FEATURE_RULES :=", 1)[1].split("\n}", 1)[0] if "const FEATURE_RULES :=" in renderer_text else ""
feature_tiles = re.findall(r'"([a-z0-9_]+)"', re.sub(r'"(?:plain|forest|hills|water|marsh|tiles|chance)"', "", feature_block))
check(bool(feature_tiles) and all(any(name.endswith("/" + tile) for name in tile_names) for tile in feature_tiles), "all deterministic feature placements reference authored TileSet tiles")
check((ROOT / "VERSION.txt").is_file(), "version metadata exists")

# Pixel battlefield and mounted cavalry asset integrity checks.
cavalry_root = ROOT / "assets/combat/cavalry"
cavalry_manifest_path = cavalry_root / "animation_manifest.json"
try:
    cavalry_manifest = json.loads(cavalry_manifest_path.read_text(encoding="utf-8"))
except Exception as exc:
    cavalry_manifest = {}
    check(False, f"cavalry animation manifest parses ({exc})")
else:
    check(True, "cavalry animation manifest parses")
for faction in ("blue", "red"):
    atlas_path = cavalry_root / f"{faction}_animations.png"
    check(atlas_path.is_file(), f"{faction} cavalry runtime atlas exists")
    dims = None
    if atlas_path.is_file():
        raw_atlas = atlas_path.read_bytes()
        if len(raw_atlas) >= 24 and raw_atlas[:8] == b"\x89PNG\r\n\x1a\n" and raw_atlas[12:16] == b"IHDR":
            dims = struct.unpack(">II", raw_atlas[16:24])
    check(dims == (1408, 328), f"{faction} cavalry atlas uses normalized 88x82 cells")
    animation_data = cavalry_manifest.get("teams", {}).get(faction, {})
    expected_frames = {"idle": 11, "run": 8, "attack": 12, "charge": 16}
    check(all(animation_data.get(name, {}).get("frames") == count for name, count in expected_frames.items()), f"{faction} cavalry manifest records verified animation frame counts")

battlefield_text = (ROOT / "scripts/battlefield_visuals.gd").read_text(encoding="utf-8")
check('"visual_style": "pixel_isometric_terrain"' in battlefield_text and "TRANSPARENCY_ALPHA_SCISSOR" in battlefield_text and "TEXTURE_FILTER_NEAREST" in battlefield_text, "battlefield uses crisp pixel-isometric ground tiles")

# Tactical terrain, flanking and role-aware combat AI additions.
battlefield_rules_path = ROOT / "scripts/battlefield_rules.gd"
battlefield_rules_text = battlefield_rules_path.read_text(encoding="utf-8") if battlefield_rules_path.is_file() else ""
zone_visuals_path = ROOT / "scripts/battlefield_zone_visuals.gd"
zone_visuals_text = zone_visuals_path.read_text(encoding="utf-8") if zone_visuals_path.is_file() else ""
flanking_path = ROOT / "scripts/battle_flanking.gd"
flanking_text = flanking_path.read_text(encoding="utf-8") if flanking_path.is_file() else ""
status_path = ROOT / "scripts/combat_status_catalog.gd"
status_text = status_path.read_text(encoding="utf-8") if status_path.is_file() else ""
ai_tactics_path = ROOT / "scripts/battle_ai_tactics.gd"
ai_tactics_text = ai_tactics_path.read_text(encoding="utf-8") if ai_tactics_path.is_file() else ""
battle_unit_text = (ROOT / "scripts/battle_unit.gd").read_text(encoding="utf-8")
combat_test_text = (ROOT / "scripts/combat_test.gd").read_text(encoding="utf-8")
check(all(token in battlefield_rules_text for token in ["FOREST_RANGED_TAKEN_MULTIPLIER := 0.82", "HIGHLANDS_RANGED_DEALT_MULTIPLIER := 1.10", "MARSH_INFANTRY_MOVE_MULTIPLIER := 0.82", "MARSH_CAVALRY_MOVE_MULTIPLIER := 0.65"]), "terrain rules contain forest, high-ground and marsh modifiers")
check("BattlefieldZoneVisualsScript.add_to" in battlefield_text and "terrain_zone_count" in battlefield_text and "BattlefieldZone" in zone_visuals_text, "terrain zones have visible non-colliding markers")
check(all(token in flanking_text for token in ["SIDE_DAMAGE_MULTIPLIER := 1.10", "REAR_DAMAGE_MULTIPLIER := 1.20", "EXPOSED_DURATION := 1.8"]), "flanking rules contain side, rear and exposed values")
check("incoming_damage_multiplier" in status_text and "exposed" in status_text, "combat status catalog defines exposed vulnerability")
check("get_target_score" in ai_tactics_text and "1.45" in ai_tactics_text and "1.35" in ai_tactics_text, "role-aware AI target preferences are defined")
check(all(token in battle_unit_text for token in ["get_terrain_effects()", "apply_exposed", "effective_armor += 1.0", "charge_allowed"]), "battle units apply terrain, flanking, exposed and hold mechanics")
check("player_flank_attacks" in combat_test_text and "enemy_flank_attacks" in combat_test_text, "battle report and campaign results include flank statistics")
check(all((ROOT / "tests" / name).is_file() for name in ["battlefield_rules_smoke_test.gd", "battle_flanking_smoke_test.gd", "battle_ai_tactics_smoke_test.gd"]), "terrain, flank and AI smoke-test sources are present")
campaign_state_text = (ROOT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
check(all(token in campaign_state_text for token in [
    'const ROLE_MELEE := "melee"',
    'const ROLE_RANGED := "ranged"',
    'const ROLE_SPEAR := "spear"',
    'const ROLE_CAVALRY := "cavalry"',
]), "all existing campaign unit role IDs remain unchanged")
check("const ARMY_CAPACITY := 24" in campaign_state_text, "existing 24-unit army capacity remains unchanged")
check("const SAVE_VERSION := 1" in campaign_state_text, "campaign save schema remains version 1")
load_campaign_block = campaign_state_text.split("func load_campaign() -> bool:", 1)[1].split("\nfunc _read_city_queue", 1)[0] if "func load_campaign() -> bool:" in campaign_state_text and "\nfunc _read_city_queue" in campaign_state_text else ""
check(load_campaign_block.count("var loaded_buildings") == 1 and "var city_buildings_data" in load_campaign_block, "city loading uses unique local variable names and avoids the duplicate loaded_buildings parser error")
make_city_record_block = campaign_state_text.split("func _make_city_record(", 1)[1].split("\nfunc _save_active_city", 1)[0] if "func _make_city_record(" in campaign_state_text and "\nfunc _save_active_city" in campaign_state_text else ""
check("city_display_name: String" in make_city_record_block and '"name": city_display_name' in make_city_record_block and not re.search(r"(?<![A-Za-z0-9_])name\s*:\s*String", make_city_record_block), "city record parameter no longer shadows Node.name")
world_owner_block = campaign_state_text.split("func get_world_owner_at(", 1)[1].split("\nfunc _sync_primary_kingdom", 1)[0] if "func get_world_owner_at(" in campaign_state_text and "\nfunc _sync_primary_kingdom" in campaign_state_text else ""
check("player_city_hex: Vector2i" in world_owner_block and "kingdom_city_hex: Vector2i" in world_owner_block and "var city_cell" not in world_owner_block, "world ownership lookup avoids city_cell shadowing")
check("WorldGeneratorScript.hex_distance(cell, c)" in campaign_state_text and "WorldGeneratorScript.hex_distance(cell, other)" in campaign_state_text, "city distance checks reuse the typed hex-distance helper instead of integer-division expressions")
city_queue_reader = campaign_state_text.split("func _read_city_queue(", 1)[1].split("\nfunc _read_unit_records", 1)[0] if "func _read_city_queue(" in campaign_state_text and "\nfunc _read_unit_records" in campaign_state_text else ""
check("var province_cell_value: Variant" in city_queue_reader and "var province_cell_array: Array" in city_queue_reader and "var valid_province: bool" in city_queue_reader, "province queue validation uses explicit Variant, Array and bool types")

# Army veterancy, role-specific upgrades and legacy-save compatibility.
unit_catalog_text = (ROOT / "scripts/unit_catalog.gd").read_text(encoding="utf-8")
army_upgrade_path = ROOT / "scripts/army_upgrade_catalog.gd"
army_upgrade_text = army_upgrade_path.read_text(encoding="utf-8") if army_upgrade_path.is_file() else ""
kingdom_ai_text = (ROOT / "scripts/kingdom_ai.gd").read_text(encoding="utf-8")
strategy_map_text_for_upgrades = (ROOT / "scripts/strategy_map.gd").read_text(encoding="utf-8")
progression_test_path = ROOT / "tests/unit_progression_smoke_test.gd"
check(all(token in unit_catalog_text for token in ['"xp_required": 0', '"xp_required": 40', '"xp_required": 100', '"xp_required": 180']), "unit veterancy defines recruit, trained, veteran and elite thresholds")
check("get_battle_experience" in unit_catalog_text and "clampi(" in unit_catalog_text, "unit battle experience uses a capped deterministic formula")
check(all(role_id in army_upgrade_text for role_id in ['"melee"', '"ranged"', '"spear"', '"cavalry"']) and "const MAX_RANK := 2" in army_upgrade_text, "army upgrade catalog covers all four stable roles with two ranks")
check(all(token in battle_unit_text for token in ["var experience: int", "var army_upgrade_rank: int", "get_veterancy_data(experience)", "ArmyUpgradeCatalogScript.get_bonuses"]), "battle units apply per-unit veterancy and campaign upgrade bonuses")
check(all(token in campaign_state_text for token in ["army_upgrades", "battle_xp_gained", "_read_army_upgrades", "get_army_veterancy_summary", '"army_upgrades": army_upgrades']), "campaign records and root save persist individual XP and army upgrades")
check('var experience := clampi(int(unit_value.get("experience", 0))' in kingdom_ai_text, "AI kingdom normalization preserves veterancy experience")
check(all(token in strategy_map_text_for_upgrades for token in ["ВОЕННАЯ ПОДГОТОВКА", "_city_upgrade_buttons", "purchase_army_upgrade", "get_army_veterancy_summary"]), "city UI exposes army training, upgrade purchase and veteran ranks")
check(progression_test_path.is_file(), "unit progression smoke test is included")

# City levels, specialization, province development, building upgrades and upkeep.
city_development_path = ROOT / "scripts/city_development_catalog.gd"
city_development_text = city_development_path.read_text(encoding="utf-8") if city_development_path.is_file() else ""
city_development_test_path = ROOT / "tests/city_development_smoke_test.gd"
check(city_development_path.is_file(), "city development data catalog exists")
check(all(token in city_development_text for token in ["population_min", "population_max", "province_slots", "get_city_level", "get_province_slots"]), "three city levels define population thresholds and province capacity")
check(all(token in city_development_text for token in ['"agriculture"', '"commerce"', '"industry"', '"military"']), "four city specializations are data-driven")
check(all(token in city_development_text for token in ['"farm_plot"', '"trade_post"', '"woodland_camp"', '"stone_quarry"', '"watchtower"']), "five terrain-bound province improvements are catalogued")
check(all(token in city_development_text for token in ['"farm"', '"market"', '"workshop"', '"barracks"', '"archery_range"', '"stable"']) and "2: {" in city_development_text and "3: {" in city_development_text, "all six existing buildings have level-two and level-three upgrades")
check("get_city_income" in city_development_text and "food_multiplier" in city_development_text and "gold_multiplier" in city_development_text and "production_multiplier" in city_development_text, "city specialization and province improvements modify only the three existing incomes")
check("static func get_army_upkeep" in unit_catalog_text and "ceili(total)" in unit_catalog_text, "army upkeep is calculated in the unit catalog and rounded up to whole gold")
check(all(token in unit_catalog_text for token in ['"upkeep": 0.8', '"upkeep": 0.9', '"upkeep": 1.4']), "all existing unit roles have upkeep values in the central unit catalog")
check(all(token in campaign_state_text for token in ["city_specialization", "city_building_levels", "city_province_improvements", "_charge_army_upkeep", "army_upkeep_last_paid", '"specialization": specialization', '"cities": cities']), "player city development and upkeep results are persisted in existing save schema")
check(all(token in campaign_state_text for token in ["queue_city_building_upgrade", "queue_province_improvement", "get_city_level", "get_city_income"]), "campaign state exposes city upgrade, province and income APIs")
check(all(token in kingdom_ai_text for token in ["CityDevelopment.get_city_income", "FactionCatalog.get_upkeep_multiplier", "FactionCatalog.apply_income_modifiers", "world_seed, world_generation_version", "building_upgrade", "province_improvement"]), "AI kingdoms use city specializations, faction-aware upkeep, improvements and upgrades")
ai_order_block = kingdom_ai_text.split("static func _queue_next_order", 1)[1].split("static func _get_ai_building_upgrade_id", 1)[0] if "static func _queue_next_order" in kingdom_ai_text else ""
check("strategic_plan" in ai_order_block and "desired_army_size" in ai_order_block and "recruit_unlock" in ai_order_block and ai_order_block.find('city_index == 0 and not buildings.has("market")') < ai_order_block.find('elif should_recruit and buildings.has(recruit_unlock)'), "AI city orders use strategic priorities and protect the capital market before recruitment")
check(all(token in strategy_map_text_for_upgrades for token in ["РАЗВИТИЕ ГОРОДА И СПЕЦИАЛИЗАЦИЯ", "_city_specialization_buttons", "_city_province_buttons", "_city_building_upgrade_buttons", "_city_upkeep_label"]), "mobile city panel exposes specialization, provinces, building upgrades and upkeep")
check(city_development_test_path.is_file(), "city development smoke test is included")
check("CityDevelopmentCatalogScript.normalize_building_levels" in campaign_state_text and "CityDevelopmentCatalogScript.normalize_province_improvements" in campaign_state_text, "old city records receive safe level-one and empty-province defaults")

# The owner-supplied Mythryl 2D Pixel Terrain pack is integrated only as part of
# this playable project; its source licence and attribution are kept in place.
mythryl_root = ROOT / "assets/combat/mythryl_pixel_terrain"
mythryl_atlas = mythryl_root / "ground_atlas_64.png"
mythryl_manifest_path = mythryl_root / "ground_atlas_manifest.json"
check((mythryl_root / "LICENSE.txt").is_file(), "Mythryl Pixel Terrain licence is included")
check((mythryl_root / "README.txt").is_file(), "Mythryl Pixel Terrain asset notes are included")
check(mythryl_atlas.is_file(), "Mythryl 64px isometric ground atlas exists")
mythryl_dims = None
if mythryl_atlas.is_file():
    raw_mythryl = mythryl_atlas.read_bytes()
    if len(raw_mythryl) >= 24 and raw_mythryl[:8] == b"\x89PNG\r\n\x1a\n" and raw_mythryl[12:16] == b"IHDR":
        mythryl_dims = struct.unpack(">II", raw_mythryl[16:24])
check(mythryl_dims == (512, 512), "Mythryl ground atlas is 512x512 and pixel aligned")
try:
    mythryl_manifest = json.loads(mythryl_manifest_path.read_text(encoding="utf-8"))
except Exception as exc:
    mythryl_manifest = {}
    check(False, f"Mythryl ground atlas manifest parses ({exc})")
else:
    check(True, "Mythryl ground atlas manifest parses")
mythryl_slots = mythryl_manifest.get("slots", {})
mythryl_coasts = mythryl_manifest.get("coast_masks", {})
check(len(mythryl_slots) == 74 and len(mythryl_coasts) == 46, "Mythryl atlas packs four grass, four dirt, sixteen blends, four water and forty-six coast shapes")
mythryl_assets = [
    "64px/godot/ground-grass.tres",
    "64px/godot/water-grass.tres",
    "64px/godot/cliffs.tres",
    "64px/nature/trees/common-tree-1/common-tree-1_0.png",
    "64px/nature/trees/pine-1/pine-1_0.png",
    "64px/nature/bushes/bush-common/bush-common_0.png",
    "64px/nature/rocks/rock-medium-1/rock-medium-1_0.png",
    "64px/nature/flowers/flower-patch-mixed/flower-patch-mixed_0.png",
    "64px/cliffs/crags/grass/crags-grass_full_1.png",
]
check(all((mythryl_root / item).is_file() for item in mythryl_assets), "Mythryl ground, cliff, tree, bush, rock and flower resources are present")
check("PixelIsometricGroundTiles" in battlefield_text and "SurfaceTool.new()" in battlefield_text, "battlefield ground is assembled as a single isometric mesh batch")
sprite_filter_values = re.findall(r"sprite\.texture_filter\s*=\s*([A-Za-z0-9_.]+)", battlefield_text)
check(
    len(sprite_filter_values) == 2 and all(value == "BaseMaterial3D.TEXTURE_FILTER_NEAREST" for value in sprite_filter_values),
    "billboard Sprite3D props use the BaseMaterial3D nearest-filter enum",
)

# Supplied strategy icon packs are bundled only as part of the finished game project.
icons_root = ROOT / "assets/icons"
gridwright_root = icons_root / "gridwright"
pixel_fantasy_root = icons_root / "pixel_fantasy"
gridwright_pngs = list((gridwright_root / "PNG").rglob("*.png"))
pixel_fantasy_pngs = list((pixel_fantasy_root / "PNG").rglob("*.png"))
check((gridwright_root / "LICENSE.txt").is_file(), "Gridwright Strategy UI licence is included")
check((pixel_fantasy_root / "LICENSE.txt").is_file(), "Pixel Fantasy Map Icons licence is included")
check(len(gridwright_pngs) >= 280, f"Gridwright PNG variants are present ({len(gridwright_pngs)} found)")
check(len(pixel_fantasy_pngs) >= 100, f"Pixel Fantasy map and settlement PNG variants are present ({len(pixel_fantasy_pngs)} found)")
icon_catalog_path = ROOT / "scripts/game_icon_catalog.gd"
icon_catalog_text = icon_catalog_path.read_text(encoding="utf-8") if icon_catalog_path.is_file() else ""
check(icon_catalog_path.is_file(), "central GameIconCatalog script exists")
check(all(token in icon_catalog_text for token in ["_RESOURCE_GOLD", "_RESOURCE_FOOD", "_UNIT_INFANTRY", "_UNIT_ARCHER", "_UNIT_CAVALRY", "_MAP_CASTLE_BLUE", "_MAP_CASTLE_RED", "_MAP_CROSSED_SWORDS"]), "icon catalog covers current resource, unit and strategic marker roles")
strategy_map_text = (ROOT / "scripts/strategy_map.gd").read_text(encoding="utf-8")
check("GameIconCatalogScript.settlement_icon(sprite_id, true)" in strategy_map_text and "GameIconCatalogScript.map_marker_icon(\"crossed_swords\")" in strategy_map_text, "strategic city and army markers use the supplied map icon pack")
check("_add_icon_value(hud_resources" in strategy_map_text and "_add_icon_value(city_resources" in strategy_map_text, "HUD and city panel use iconized live resource values")
check("button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST" in strategy_map_text, "pixel UI button icons explicitly use nearest-neighbour filtering")
check((ROOT / "tests/icon_integration_smoke_test.gd").is_file(), "icon integration smoke test exists")
unit_visual_text = (ROOT / "scripts/battle_unit.gd").read_text(encoding="utf-8")
check("CombatSpriteLibraryScript.get_frames(team, role)" in unit_visual_text and "AnimatedSprite3D.new()" in unit_visual_text, "combat units use billboarded sprite animations when local art is present")

project_text = (ROOT / "project.godot").read_text(encoding="utf-8") if (ROOT / "project.godot").exists() else ""
check('"4.7"' in project_text and '"GL Compatibility"' in project_text, "project is tagged for Godot 4.7 and GL Compatibility")

manifest_path = ROOT / "assets/map/world_surface_manifest.json"
try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except Exception as exc:
    manifest = {}
    failures.append(f"world surface manifest cannot be parsed: {exc}")
    print(f"FAIL: world surface manifest cannot be parsed: {exc}")
else:
    check(True, "world surface manifest parses")

for key, expected_size in (("world_surface_atlas.png", (4096, 4096)), ("world_detail_atlas.png", (3072, 2048))):
    image_path = ROOT / "assets/map" / key
    check(image_path.is_file(), f"{key} exists")
    if not image_path.is_file():
        continue
    raw = image_path.read_bytes()
    dims = None
    if len(raw) >= 24 and raw[:8] == b"\x89PNG\r\n\x1a\n" and raw[12:16] == b"IHDR":
        dims = struct.unpack(">II", raw[16:24])
    check(dims == expected_size, f"{key} dimensions are {expected_size[0]}x{expected_size[1]}")
    resource_meta = manifest.get("resources", {}).get(key, {})
    expected_hash = resource_meta.get("sha256")
    actual_hash = hashlib.sha256(raw).hexdigest()
    check(bool(expected_hash) and actual_hash == expected_hash, f"{key} SHA-256 matches manifest")

surface = manifest.get("surface_atlas", {})
detail = manifest.get("detail_atlas", {})
check(surface.get("independent_scenes") == 24, "surface atlas manifest records 24 independent scene crops")
check(detail.get("sprites") == 24, "detail atlas manifest records 24 detail sprites")

# Validate literal local resource paths referenced by project source and scenes.
resource_ext = {".gd", ".tscn", ".tres", ".res", ".import", ".theme", ".gdshader", ".svg", ".json", ".png", ".webp", ".wav", ".ogg", ".ttf", ".otf"}
# Tiny Swords is a locally generated licensed asset and is deliberately not
# committed to the public source repository. Runtime code checks it optionally.
optional_local_resources = {"assets/combat/tiny_swords/combat_units_atlas.png"}
path_pattern = re.compile(r"res://[A-Za-z0-9_./-]+")
missing: set[str] = set()
scanned = 0
for folder in ("scripts", "scenes", "tests", "ui", "assets"):
    base = ROOT / folder
    if not base.exists():
        continue
    for source in base.rglob("*"):
        if not source.is_file() or source.suffix.lower() not in {".gd", ".tscn", ".tres", ".import", ".gdshader", ".theme", ".json"}:
            continue
        scanned += 1
        try:
            content = source.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for token in path_pattern.findall(content):
            rel = token[6:]
            candidate = ROOT / rel
            if candidate.suffix.lower() not in resource_ext:
                continue
            if rel.startswith(".godot/"):
                continue  # generated by the editor import pass
            if not candidate.is_file() and rel not in optional_local_resources:
                missing.add(f"{source.relative_to(ROOT)} -> {token}")
check(not missing, f"all literal res:// references resolve ({scanned} source/resource files scanned)")
for item in sorted(missing):
    failures.append("missing resource: " + item)
    print("  " + item)

smoke_tests = sorted((ROOT / "tests").glob("*_smoke_test.gd")) if (ROOT / "tests").exists() else []
check(len(smoke_tests) >= 24, f"at least 24 smoke tests are present ({len(smoke_tests)} found)")
check((ROOT / "scripts/hex_terrain_tilemap_renderer.gd").is_file(), "native Hex TileSet renderer exists")
check((ROOT / "tests/hex_tileset_renderer_smoke_test.tscn").is_file(), "Hex TileSet smoke-test scene exists")
check((ROOT / "tools/qa/visual_capture.gd").is_file(), "visual screenshot runner exists")
check((ROOT / "tools/qa/run_smoke_tests.sh").is_file(), "smoke test runner exists")
check((ROOT / "tools/qa/parse_all_scripts.gd").is_file(), "project-context GDScript parser exists")
check((ROOT / "tools/qa/parse_all_scripts.tscn").is_file(), "project-context parser scene exists")
check((ROOT / ".github/workflows/ember-qa.yml").is_file(), "GitHub Actions QA workflow exists")
check(not (ROOT / ".godot").exists(), "editor cache is not packaged in the source tree")

# Strategic world exploration: neutral sites and lightweight campaign events.
world_location_path = ROOT / "scripts/world_location_catalog.gd"
world_location_text = world_location_path.read_text(encoding="utf-8") if world_location_path.is_file() else ""
world_event_path = ROOT / "scripts/world_event_catalog.gd"
world_event_text = world_event_path.read_text(encoding="utf-8") if world_event_path.is_file() else ""
world_ai_text = (ROOT / "scripts/kingdom_ai.gd").read_text(encoding="utf-8")
check(world_location_path.is_file(), "deterministic neutral location catalog exists")
check(all(token in world_location_text for token in ["ancient_ruins", "monster_lair", "abandoned_mine", "forgotten_shrine", "mercenary_camp"]), "five neutral location types are catalogued")
check("MAX_LOCATIONS := 72" in world_location_text and "MIN_LOCATION_DISTANCE := 5" in world_location_text, "neutral location count and spacing are bounded")
check("_cell_hash" in world_location_text and "generate_locations" in world_location_text and "normalize_locations" in world_location_text, "location generation is deterministic and save-normalized")
check('"preferred": is_local_candidate' in world_location_text and "local_candidates.sort_custom" in world_location_text, "starting exploration targets have a deterministic fallback to preserve minimum local density")
check('LOCATION_TYPES["forgotten_shrine"]["terrain"].has(terrain)' in world_location_text and 'LOCATION_TYPES["ancient_ruins"]["terrain"].has(terrain)' in world_location_text, "location type selection respects its terrain catalog")
check(all(token in world_location_text for token in ["ROLE_MELEE", "ROLE_RANGED", "ROLE_SPEAR", "ROLE_CAVALRY", "guard_tier", "guardian_health", "base_reward"]), "neutral guard rosters, guardian health and rewards are data-driven")
check(world_event_path.is_file(), "lightweight campaign event catalog exists")
check("EVENT_INTERVAL := 5" in world_event_text and all(token in world_event_text for token in ["merchant_caravan", "refugees", "scout_report", "abandoned_wagon", "veteran_instructor", "workshop_wagon"]), "six campaign events use a five-turn cadence")
check("get_event_by_id" in world_event_text and "normalize_event" in world_event_text and "get_choice" in world_event_text, "events have lookup, choice validation and legacy normalization APIs")
check(all(token in campaign_state_text for token in ["neutral_locations", "pending_world_event", "world_events_resolved", "begin_location_battle", "_grant_neutral_location_reward", "guardian_health", "resolve_world_event", "city_population >= 20"]), "campaign state integrates persistent location battles, rewards, event effects and population-cap validation")
check(all(token in campaign_state_text for token in ['"neutral_locations": neutral_locations', '"pending_world_event": pending_world_event', '"world_events_resolved": world_events_resolved', 'SAVE_VERSION := 1']), "world exploration data persists without changing save schema version")
check(all(token in world_ai_text for token in ["neutral_location_cells", "_try_found_ai_city", "_move_army"]), "AI expansion and army movement avoid neutral location tiles")
check(all(token in world_ai_text for token in ["neutral_target_id", "_choose_neutral_expedition_target", "_resolve_ai_neutral_battle", "_grant_ai_location_reward", "_apply_ai_mine_income"]), "AI kingdoms reserve neutral-site expeditions, resolve strategic battles and collect persistent rewards")
check(all(token in world_ai_text for token in ["_estimate_force_strength", "_estimate_location_strength", "_damage_weakest_unit", "neutral_locations: Array[Dictionary] = []"]), "AI neutral expeditions use bounded force estimates and deterministic damage resolution")
check(all(token in world_location_text for token in ['"cleared_by"', '"cleared_turn"', 'saved.get("cleared_by"']), "neutral site ownership and capture turn persist with legacy-player defaults")
check(all(token in strategy_map_text for token in ["_draw_neutral_locations", "get_neutral_location_index_at", "begin_location_battle", "is_cell_explored", "cleared_by", "уже захвачено"]), "strategic map identifies AI-captured sites and opens only uncleared neutral battles")
check(all(token in strategy_map_text for token in ["_create_world_event_panel", "_refresh_world_event_panel", "_resolve_world_event_choice", "touch_target(52.0)"]), "mobile map includes two large event choice buttons")
check((ROOT / "tests/world_location_smoke_test.gd").is_file(), "neutral location smoke test is included")
check((ROOT / "tests/world_event_smoke_test.gd").is_file(), "campaign event smoke test is included")
check('"reveal_distance": 12' in world_event_text and "_find_scout_reveal_origin" in campaign_state_text, "scouting events reveal a distant region beyond the army's normal vision")
check(all(token in campaign_state_text for token in ["_apply_neutral_location_special_reward", "_apply_neutral_mine_income", "abandoned_mine", "forgotten_shrine", "mercenary_camp"]), "neutral location types provide distinct victory rewards and persistent mine income")

# Cleared points remain visible as map history even when the winning army occupies their hex.
location_test_text = (ROOT / "tests/world_location_smoke_test.gd").read_text(encoding="utf-8")
event_test_text = (ROOT / "tests/world_event_smoke_test.gd").read_text(encoding="utf-8")
check('not bool(location.get("cleared", false))' in campaign_state_text and 'state.get_neutral_location_by_id(target_id)' in location_test_text, "cleared neutral sites remain in map history under the victorious army")
check(all(token in location_test_text for token in ["neutral_target_id", "peaceful AI assigns and moves", "AI expedition defeats neutral guards", "AI ownership and turn survive"]), "neutral-site smoke tests cover AI targeting, battle capture, rewards and saved ownership")
check('location["cleared_by"] = -1' in campaign_state_text and 'int(location.get("cleared_by", -1)) != -1' in campaign_state_text, "player passive mine income is isolated from AI-owned mines")
check('"keep_food"' in event_test_text and '"sell_goods"' in event_test_text, "abandoned wagon validates both food and gold reward branches")

# Faction creation: people, culture, two traits, campaign start UI and AI kingdoms.
faction_catalog_path = ROOT / "scripts/faction_catalog.gd"
faction_catalog_text = faction_catalog_path.read_text(encoding="utf-8") if faction_catalog_path.is_file() else ""
faction_test_path = ROOT / "tests/faction_setup_smoke_test.gd"
faction_test_text = faction_test_path.read_text(encoding="utf-8") if faction_test_path.is_file() else ""
check(faction_catalog_path.is_file(), "data-driven faction catalog exists")
check(all(token in faction_catalog_text for token in ['"riverfolk"', '"stoneborn"', '"steppe_clans"', '"woodland_kin"']), "four distinct starter peoples are catalogued")
check(all(token in faction_catalog_text for token in ['"agrarian"', '"mercantile"', '"artisan"', '"warrior"']), "four distinct starter cultures are catalogued")
check(all(token in faction_catalog_text for token in ['"disciplined"', '"veteran_cadre"', '"frontier_guides"', '"provincial_charters"', '"guild_charters"', '"public_granaries"']), "six selectable faction traits are catalogued")
check("MAX_TRAITS := 2" in faction_catalog_text and "traits.size() != MAX_TRAITS" in faction_catalog_text, "faction data requires exactly two distinct selected traits")
check(all(token in faction_catalog_text for token in ["get_effects", "apply_income_modifiers", "get_recruit_multiplier", "get_upkeep_multiplier", "apply_starting_bonus"]), "faction effects are resolved through shared data helpers")
check("clampf(multiplier, 0.75, 1.0)" in faction_catalog_text, "stacked recruitment bonuses are capped at 25 percent")
check(all(token in faction_catalog_text for token in ["farm_food_bonus", "market_gold_bonus", "workshop_production_bonus", "army_upkeep_multiplier", "province_slot_bonus", "army_vision_bonus"]), "faction bonuses modify only existing economy, army and province systems")
check("get_legacy_selection" in faction_catalog_text and "normalize_selection" in faction_catalog_text, "old saves can receive a neutral legacy faction identity")
check(all(token in campaign_state_text for token in ["player_faction", "faction_setup_pending", "prepare_new_campaign", "apply_player_faction", '"player_faction": player_faction']), "campaign state owns faction selection and persists it as an optional save field")
check("const SAVE_VERSION := 1" in campaign_state_text and 'data.get("player_faction", {})' in campaign_state_text, "faction data loads with a legacy fallback without changing save schema version")
check(all(token in campaign_state_text for token in ["FactionCatalogScript.apply_starting_bonus", "FactionCatalogScript.apply_income_modifiers", "FactionCatalogScript.get_recruit_multiplier", "FactionCatalogScript.get_upkeep_multiplier", "province_slot_bonus"]), "selected faction affects starting reserves, income, recruitment, upkeep and province capacity")
check("FactionCatalogScript.get_effects(player_faction)" in campaign_state_text and "army_vision" in campaign_state_text, "faction scouting traits modify fog-of-war vision")
check(all(token in world_ai_text for token in ["FactionCatalog.make_ai_selection", '"faction": kingdom_faction', "FactionCatalog.apply_income_modifiers", "FactionCatalog.get_recruit_multiplier", "FactionCatalog.get_upkeep_multiplier"]), "nine AI kingdoms use faction identities and matching economy/army modifiers")
check(all(token in world_ai_text for token in ["FactionCatalog.apply_starting_bonus", "starting_resources", "starting_army"]), "AI kingdoms receive one-time faction starting reserves and veteran traits")
check(all(token in strategy_map_text for token in ["FactionFoundingPanel", "_create_faction_setup_panel", "_confirm_faction_setup", "_faction_people_option", "_faction_culture_option", "_faction_trait_a_option", "_faction_trait_b_option"]), "mobile faction founding panel exposes people, culture and two trait choices")
check(all(token in strategy_map_text for token in ["touch_target(50.0)", "touch_target(56.0)", "_get_faction_option_id", "_refresh_faction_setup_default_name"]), "faction setup controls use mobile-sized targets and show a derived kingdom name")
check(all(token in strategy_map_text for token in ["ScrollContainer.new()", "SCROLL_MODE_DISABLED", "_faction_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL"]), "faction setup content scrolls on short landscape screens while confirmation stays fixed")
check("CampaignState.faction_setup_pending or CampaignState.battle_in_progress" in strategy_map_text and "CampaignState.prepare_new_campaign(false)" in strategy_map_text, "new campaign blocks map actions until the faction is confirmed")
check(all(token in strategy_map_text for token in ["var _bottom_panel: PanelContainer", "_bottom_panel = PanelContainer.new()", "root.add_child(_bottom_panel)", "is_instance_valid(_bottom_panel)", "_bottom_panel.visible = false", "_bottom_panel.visible = true"]), "faction setup hides a persistent map-command panel until the founding choice is confirmed")
check("player_faction" in strategy_map_text and "get_player_faction_summary" in strategy_map_text, "selected kingdom identity is shown in city and kingdom information panels")
check(faction_test_path.is_file(), "faction creation smoke-test source is included")
check("not state.apply_player_faction(river_selection)" in faction_test_text and "AI kingdoms apply the Veteran Cadre starting experience trait" in faction_test_text, "faction smoke test guards against duplicate bonuses and checks AI starting XP")


# Diplomacy: relationship matrix, personalities, treaties, peace offers and AI war logic.
diplomacy_catalog_path = ROOT / "scripts/diplomacy_catalog.gd"
diplomacy_catalog_text = diplomacy_catalog_path.read_text(encoding="utf-8") if diplomacy_catalog_path.is_file() else ""
diplomacy_test_path = ROOT / "tests/diplomacy_smoke_test.gd"
diplomacy_test_text = diplomacy_test_path.read_text(encoding="utf-8") if diplomacy_test_path.is_file() else ""
check(diplomacy_catalog_path.is_file(), "data-driven diplomacy catalog exists")
check(all(token in diplomacy_catalog_text for token in ['"aggressor"', '"merchant"', '"isolationist"', '"honorable"', '"expansionist"']), "five deterministic AI diplomatic personalities are defined")
check(all(token in diplomacy_catalog_text for token in ["RELATION_MIN := -100", "RELATION_MAX := 100", "TRADE_DURATION := 6", "ALLIANCE_DURATION := 8", "TRIBUTE_DURATION := 5", "VASSAL_DURATION := 10", "TRUCE_DURATION := 4"]), "diplomacy relationship range and treaty durations are data-driven")
check("create_initial_relations" in diplomacy_catalog_text and "pair_key" in diplomacy_catalog_text and '"-1:%d"' not in diplomacy_catalog_text, "diplomacy stores canonical player and AI pair records")
check(all(token in diplomacy_catalog_text for token in ["normalize_relations", "RELATION_MIN", "RELATION_MAX", '"war_reason"']), "legacy relationship records are normalized with bounded values and explicit war causes")
check(all(token in diplomacy_catalog_text for token in ["acceptance_chance", "deterministic_acceptance", "process_turn"]), "AI negotiation uses explainable weighted and deterministic decision logic")
check(all(token in diplomacy_catalog_text for token in ["BORDER_TENSION_DISTANCE", "_nearest_sources_to_cities", "_nearest_city_distance", "border_tension"]), "border proximity creates bounded deterministic diplomatic tension")
check(all(token in diplomacy_catalog_text for token in ["war_exhaustion", "OFFER_LIFETIME", "offer_peace", "MAX_PENDING_OFFERS", "ai_peace"]), "war exhaustion can produce expiring AI peace proposals")
check(all(token in diplomacy_catalog_text for token in ["TRADE_DURATION", "ALLIANCE_DURATION", "tribute", "vassal"]), "AI-AI and player diplomacy supports trade, alliances, tribute and vassalage")
check("set_record(relations, first_id, second_id, record)" in diplomacy_catalog_text and "Persist the just-ticked record" in diplomacy_catalog_text, "AI treaty creation preserves same-turn relation changes")
check("player_sources: Array[Vector2i] = []" in diplomacy_catalog_text, "diplomacy proximity checks accept typed strategic map sources")
check(all(token in campaign_state_text for token in ["diplomacy_relations", "pending_diplomacy_offers", "perform_diplomacy_action", "respond_to_diplomacy_offer", "_apply_diplomacy_economy"]), "campaign state integrates diplomatic actions, offers and contract income")
check(all(token in campaign_state_text for token in ['"diplomacy_relations": diplomacy_relations', '"pending_diplomacy_offers": pending_diplomacy_offers', 'SAVE_VERSION := 1', "normalize_relations"]), "optional diplomacy save fields preserve legacy save schema version")
check(all(token in campaign_state_text for token in ["player_declaration", "battle_provocation", 'peace_record["war_reason"] = "resolved"', "offer_still_valid"]), "war causes, peace resolution and stale-offer validation are persisted")
check(all(token in campaign_state_text for token in ["_capital_gold_change", "_get_player_diplomacy_sources", "TRUCE_DURATION"]), "trade and tribute payments use capped existing gold and player border sources")
check('if not bool(kingdoms[kingdom_id].get("alive", true))' in campaign_state_text and 'if not bool(kingdoms[second_id].get("alive", true))' in campaign_state_text, "dead AI kingdoms do not receive treaty income or pay diplomacy upkeep")
check(all(token in world_ai_text for token in ["diplomacy_relations: Dictionary = {}", "StrategicAI.select_war_target", "_move_army"]), "AI armies use the strategic planner for movement decisions")
check(all(token in strategy_map_text for token in ["_create_kingdoms_panel", "_open_diplomacy_panel", "_refresh_diplomacy_panel", "_respond_to_diplomacy_offer"]), "mobile kingdom interface exposes relationship details and incoming proposals")
check(all(token in strategy_map_text for token in ["Характер:", "Отношение:", "Усталость от войны", "Повод:", "ПРЕДЛОЖИТЬ ТОРГОВЛЮ", "ПОТРЕБОВАТЬ ВАССАЛИТЕТ"]), "diplomacy UI explains personality, relation, war cause and treaty actions")
check("Условия изменились. Предложение больше недействительно." in campaign_state_text and "stale trade offers are rejected" in diplomacy_test_text, "diplomacy acceptance checks current treaty state")
check(diplomacy_test_path.is_file(), "diplomacy smoke-test source is included")
check(all(token in diplomacy_test_text for token in ["merchant begins with a modest positive player relationship", "AI-AI treaty creation preserves the relation score", "aggressive AI applies deterministic border tension", "stale trade offers are rejected"]), "diplomacy tests cover treaty persistence, border tension and stale offers")

# Strategic kingdom planner: economy, force composition, war targets and expansion scoring.
strategic_ai_path = ROOT / "scripts/strategic_ai_planner.gd"
strategic_ai_text = strategic_ai_path.read_text(encoding="utf-8") if strategic_ai_path.is_file() else ""
strategic_ai_test_path = ROOT / "tests/strategic_ai_smoke_test.gd"
strategic_ai_test_text = strategic_ai_test_path.read_text(encoding="utf-8") if strategic_ai_test_path.is_file() else ""
check(strategic_ai_path.is_file(), "strategic AI planner module exists")
check(all(token in strategic_ai_text for token in ["evaluate_kingdom", "select_recruitment_role", "select_war_target", "score_expansion_cell"]), "strategic AI planner exposes economy, recruitment, war and expansion decisions")
check(all(token in strategic_ai_text for token in ['str(player_record.get("treaty", "peace")) == "war"', 'str(relation.get("treaty", "peace")) != "war"']), "strategic war targets require an active player or AI war treaty")
check(all(token in strategic_ai_text for token in ["net_gold_per_turn", "desired_army_size", "economy_focus", "expansion_allowed"]), "strategic planner evaluates treasury, upkeep and expansion reserves")
check(all(token in kingdom_ai_text for token in ["StrategicAI.evaluate_kingdom", "StrategicAI.select_war_target", "StrategicAI.score_expansion_cell", "strategic_plan.get(\"expansion_allowed\""]), "AI turn loop consumes strategic plans for city orders, movement and settlement placement")
check(strategic_ai_test_path.is_file() and all(token in strategic_ai_test_text for token in ["low treasury", "active war", "expansion scoring", "save schema version one"]), "strategic AI smoke test covers economy, war, expansion and save compatibility")
check("const SAVE_VERSION := 1" in campaign_state_text and "const ARMY_CAPACITY := 24" in campaign_state_text, "strategic AI preserves campaign schema and army capacity")

# Territorial control: deterministic city/army influence, disputed borders and frontier watchtowers.
territory_path = ROOT / "scripts/territory_catalog.gd"
territory_text = territory_path.read_text(encoding="utf-8") if territory_path.is_file() else ""
territory_test_path = ROOT / "tests/territory_control_smoke_test.gd"
territory_test_text = territory_test_path.read_text(encoding="utf-8") if territory_test_path.is_file() else ""
check(territory_path.is_file(), "deterministic territorial control catalog exists")
check(all(token in territory_text for token in ["build_owner_lookup", "get_owner_at", "OWNER_DISPUTED", "CONTEST_MARGIN"]), "territory catalog resolves owners and contested borders deterministically")
check(all(token in territory_text for token in ["_append_city_sources", "_append_army_source", "watchtower", "get_defensive_armor_bonus"]), "city, field army and frontier fortifications project territorial influence")
check(all(token in campaign_state_text for token in ["TerritoryCatalogScript.get_owner_at", "get_world_owner_at", "OWNER_DISPUTED", "battle_territory_armor_bonus"]), "campaign city founding and tactical battles consume territorial ownership")
check(all(token in strategy_map_text for token in ["TerritoryCatalogScript.build_owner_lookup", "OWNER_DISPUTED", "watchtower"]), "strategic map renders dynamic ownership, contested borders and watchtowers")
check(all(token in kingdom_ai_text for token in ["prefer_fortification", "has_watchtower", '"watchtower"']), "AI kingdoms build frontier watchtowers when their territory is threatened")
check(all(token in battle_unit_text for token in ["territory_armor_bonus", "armor += territory_armor_bonus"]), "tactical units apply the territorial fortification armour bonus")
check(territory_test_path.is_file() and all(token in territory_test_text for token in ["OWNER_DISPUTED", "watchtower", "field army", "SAVE_VERSION"]), "territory smoke tests cover ownership, disputed land, armies, forts and save compatibility")
check("const SAVE_VERSION := 1" in campaign_state_text, "territorial control keeps legacy campaign saves at version one")

print(f"\nStatic QA: {checks - len(failures)}/{checks} checks passed")
if failures:
    print("Failures:")
    for failure in failures:
        print(" - " + failure)
    sys.exit(1)
