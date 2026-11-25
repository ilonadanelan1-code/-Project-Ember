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
            if not candidate.is_file():
                missing.add(f"{source.relative_to(ROOT)} -> {token}")
check(not missing, f"all literal res:// references resolve ({scanned} source/resource files scanned)")
for item in sorted(missing):
    failures.append("missing resource: " + item)
    print("  " + item)

smoke_tests = sorted((ROOT / "tests").glob("*_smoke_test.gd")) if (ROOT / "tests").exists() else []
check(len(smoke_tests) >= 19, f"at least 19 smoke tests are present ({len(smoke_tests)} found)")
check((ROOT / "scripts/hex_terrain_tilemap_renderer.gd").is_file(), "native Hex TileSet renderer exists")
check((ROOT / "tests/hex_tileset_renderer_smoke_test.tscn").is_file(), "Hex TileSet smoke-test scene exists")
check((ROOT / "tools/qa/visual_capture.gd").is_file(), "visual screenshot runner exists")
check((ROOT / "tools/qa/run_smoke_tests.sh").is_file(), "smoke test runner exists")
check((ROOT / "tools/qa/parse_all_scripts.gd").is_file(), "project-context GDScript parser exists")
check((ROOT / "tools/qa/parse_all_scripts.tscn").is_file(), "project-context parser scene exists")
check((ROOT / ".github/workflows/ember-qa.yml").is_file(), "GitHub Actions QA workflow exists")
check(not (ROOT / ".godot").exists(), "editor cache is not packaged in the source tree")

print(f"\nStatic QA: {checks - len(failures)}/{checks} checks passed")
if failures:
    print("Failures:")
    for failure in failures:
        print(" - " + failure)
    sys.exit(1)
