#!/usr/bin/env python3
"""Validate Project Ember's compact, licensed runtime visual atlas."""
from __future__ import annotations

import base64
import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "scripts"
checks = 0
failures: list[str] = []


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if condition:
        print(f"PASS: {message}")
    else:
        failures.append(message)
        print(f"FAIL: {message}")


data_path = SCRIPTS / "visual_asset_data.gd"
data_text = data_path.read_text(encoding="utf-8") if data_path.is_file() else ""
meta_match = re.search(r'const META_JSON := """(.*?)"""', data_text, re.DOTALL)
try:
    metadata = json.loads(meta_match.group(1)) if meta_match else {}
    check(bool(metadata), "visual atlas metadata is valid JSON")
except json.JSONDecodeError as exc:
    metadata = {}
    check(False, f"visual atlas metadata is valid JSON ({exc})")

chunks: list[str] = []
for index in range(8):
    chunk_path = SCRIPTS / f"visual_asset_chunk_{index:02d}.gd"
    chunk_text = chunk_path.read_text(encoding="utf-8") if chunk_path.is_file() else ""
    match = re.search(r'const DATA := """(.*?)"""', chunk_text, re.DOTALL)
    check(match is not None, f"visual atlas data segment {index:02d} exists")
    if match:
        chunks.append(match.group(1))
        check(f"VisualAssetChunk{index:02d}Script.DATA" in data_text, f"visual atlas data segment {index:02d} is linked into the runtime")
    else:
        chunks.append("")

encoded = "".join(chunks)
check(len(encoded) == 35000, "combined visual atlas Base64 payload has the expected length")
try:
    webp = base64.b64decode(encoded, validate=True)
    check(webp.startswith(b"RIFF") and webp[8:12] == b"WEBP", "combined atlas decodes as a WebP image")
    check(len(webp) > 20000, "lossless runtime atlas payload is complete")
except Exception as exc:
    webp = b""
    check(False, f"visual atlas Base64 is valid ({exc})")

expected_size = metadata.get("image_size", [])
check(expected_size == [1024, 960], "runtime atlas uses the expected 1024x960 canvas")
atlas_regions = metadata.get("atlas_regions", {})
expected_regions = {
    "monsters": ([0, 0], [256, 960]),
    "castle": ([256, 0], [384, 320]),
    "factions": ([640, 0], [320, 288]),
    "red_knight": ([256, 320], [710, 162]),
}
for atlas_id, (offset, size) in expected_regions.items():
    region = atlas_regions.get(atlas_id, {})
    check(region.get("offset") == offset and region.get("size") == size, f"{atlas_id} atlas region is present and correctly placed")
    if len(offset) == 2 and len(size) == 2:
        check(offset[0] >= 0 and offset[1] >= 0 and offset[0] + size[0] <= 1024 and offset[1] + size[1] <= 960, f"{atlas_id} atlas region stays inside the texture")

monster_meta = metadata.get("monsters", {})
monsters = monster_meta.get("monsters", {})
expected_monsters = {
    "bat", "eyeball", "ghost", "goblin", "golem", "imp", "mushroom", "pumpkin",
    "skeleton", "slime_blue", "slime_green", "slime_red", "snake", "spider", "wyrm",
    "boar", "dark_knight", "demon", "fire_elemental", "ice_elemental", "lich", "mimic",
    "mummy", "orc", "scorpion", "storm_elemental", "vampire", "water_elemental", "wolf",
    "zombie",
}
check(set(monsters) == expected_monsters, "all 30 monster sprites are indexed")
check(all(0 <= int(value.get("row", -1)) < 30 for value in monsters.values()), "all monster sprite rows fit the 30-row atlas")

castle = metadata.get("castle", {})
castle_frames = castle.get("frames", {})
expected_props = {
    "castle_tower", "castle_gate", "cottage", "market_stall", "windmill", "stone_well",
    "signpost", "campfire", "gravestone", "statue", "torch", "banner_blue", "banner_red",
    "knight", "king", "archer", "guard", "wizard", "merchant", "blacksmith", "horse",
    "dragon", "oak_tree", "pine_tree", "rock", "wood_fence", "barrel", "crate",
}
check(expected_props.issubset(set(castle_frames)), "all required Pixel Castle buildings, props and unit portraits are indexed")
check(all(int(frame.get("x", -1)) >= 0 and int(frame.get("y", -1)) >= 0 and int(frame.get("w", 0)) > 0 and int(frame.get("h", 0)) > 0 and int(frame.get("x", 0)) + int(frame.get("w", 0)) <= 384 and int(frame.get("y", 0)) + int(frame.get("h", 0)) <= 320 for frame in castle_frames.values()), "Pixel Castle frame rectangles stay inside their atlas")

factions = metadata.get("factions", {})
faction_order = factions.get("order", [])
check(len(faction_order) == 15 and len(faction_order) == len(set(faction_order)), "all 15 unique faction banners are indexed")
red_knight = metadata.get("red_knight", {})
animations = red_knight.get("animations", {})
check(red_knight.get("cell") == [71, 54] and all(animations.get(key, {}).get("frames") == count for key, count in {"idle": 8, "run": 8, "attack": 10}.items()), "red knight animation metadata matches the 71x54 frame sheet")

for path, tokens, label in [
    (SCRIPTS / "visual_asset_catalog.gd", ["Marshalls.base64_to_raw", "load_webp_from_buffer", "get_monster_frames", "get_faction_banner"], "runtime atlas loader"),
    (SCRIPTS / "game_icon_catalog.gd", ["medieval_prop_icon", "faction_banner_icon", "VisualAssetCatalogScript"], "game icon integration"),
    (SCRIPTS / "strategy_map.gd", ["medieval_prop_icon", "faction_banner_icon", "get_map_icon"], "strategic map visual integration"),
    (SCRIPTS / "battle_unit.gd", ["visual_override_id", "get_monster_frames", "get_red_knight_frames"], "battle unit visual overrides"),
    (SCRIPTS / "combat_test.gd", ["get_guard_visual_ids", "get_guardian_visual_id"], "neutral encounter sprite assignment"),
    (SCRIPTS / "world_location_catalog.gd", ["get_map_icon", "get_guard_visual_ids", "get_guardian_visual_id"], "neutral site visual catalog"),
]:
    content = path.read_text(encoding="utf-8") if path.is_file() else ""
    check(path.is_file() and all(token in content for token in tokens), f"{label} is wired into the game")

check((ROOT / "tests/visual_asset_catalog_smoke_test.gd").is_file(), "visual asset runtime smoke test is included")
campaign_state = (SCRIPTS / "campaign_state.gd").read_text(encoding="utf-8")
check("const SAVE_VERSION := 1" in campaign_state, "visual integration leaves campaign save version 1 unchanged")
credits_path = ROOT / "assets/visuals/ASSET_CREDITS.md"
credits = credits_path.read_text(encoding="utf-8") if credits_path.is_file() else ""
check(credits_path.is_file() and all(name in credits for name in ["reodesuxz", "Antahonist", "Scrython"]), "visual asset creators and licence notes are credited")
check("coa-shields.zip" in credits and "9 Heraldry constructor.zip" in credits, "unlicensed heraldry archives are documented as excluded")

print(f"\nVisual atlas validation: {checks - len(failures)}/{checks} checks passed")
if failures:
    print("Failures:")
    for failure in failures:
        print(" - " + failure)
    sys.exit(1)
