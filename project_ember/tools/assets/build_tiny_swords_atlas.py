#!/usr/bin/env python3
"""Build Project Ember's optional Tiny Swords combat atlas from a local ZIP.

Requires Pillow: python3 -m pip install Pillow
The source pack is not redistributed by this script.
"""
from __future__ import annotations

import argparse
import json
import zipfile
from io import BytesIO
from pathlib import Path

from PIL import Image

CELL = 96
CONTENT = 80
BOTTOM_MARGIN = 6
ANIMATIONS = [
    ("warrior_idle", "Warrior/Warrior_Idle.png", 192, 8),
    ("warrior_run", "Warrior/Warrior_Run.png", 192, 6),
    ("warrior_attack_a", "Warrior/Warrior_Attack1.png", 192, 4),
    ("warrior_attack_b", "Warrior/Warrior_Attack2.png", 192, 4),
    ("warrior_guard", "Warrior/Warrior_Guard.png", 192, 6),
    ("archer_idle", "Archer/Archer_Idle.png", 192, 6),
    ("archer_run", "Archer/Archer_Run.png", 192, 4),
    ("archer_shoot", "Archer/Archer_Shoot.png", 192, 8),
    ("lancer_idle", "Lancer/Lancer_Idle.png", 320, 12),
    ("lancer_run", "Lancer/Lancer_Run.png", 320, 6),
    ("lancer_attack", "Lancer/Lancer_Right_Attack.png", 320, 3),
]
TEAMS = ("Blue", "Red")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("zip_path", type=Path, help="Tiny Swords (Free Pack).zip")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("assets/combat/tiny_swords"),
        help="Project-relative atlas output directory",
    )
    args = parser.parse_args()
    if not args.zip_path.is_file():
        parser.error(f"ZIP file not found: {args.zip_path}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    max_frames = max(entry[3] for entry in ANIMATIONS)
    atlas = Image.new(
        "RGBA",
        (max_frames * CELL, len(ANIMATIONS) * len(TEAMS) * CELL),
        (0, 0, 0, 0),
    )
    manifest = {
        "cell_size": CELL,
        "rows_per_team": len(ANIMATIONS),
        "team_order": list(TEAMS),
        "animations": {},
        "source": "Tiny Swords (Free Pack) by Pixel Frog",
    }

    with zipfile.ZipFile(args.zip_path) as archive:
        names = set(archive.namelist())
        for team_index, team in enumerate(TEAMS):
            for animation_index, (key, relative_path, source_cell, frame_count) in enumerate(ANIMATIONS):
                archive_path = f"Tiny Swords (Free Pack)/Units/{team} Units/{relative_path}"
                if archive_path not in names:
                    raise FileNotFoundError(f"Required sprite sheet is missing: {archive_path}")
                source = Image.open(BytesIO(archive.read(archive_path))).convert("RGBA")
                class_key = key.split("_", 1)[0]
                related = [entry for entry in ANIMATIONS if entry[0].startswith(class_key + "_")]
                bounds = None
                for _, rel, source_size, count in related:
                    rel_path = f"Tiny Swords (Free Pack)/Units/{team} Units/{rel}"
                    if rel_path not in names:
                        raise FileNotFoundError(f"Required sprite sheet is missing: {rel_path}")
                    sheet = Image.open(BytesIO(archive.read(rel_path))).convert("RGBA")
                    for frame_index in range(count):
                        frame = sheet.crop((frame_index * source_size, 0, (frame_index + 1) * source_size, source_size))
                        frame_bounds = frame.getchannel("A").getbbox()
                        if frame_bounds:
                            if bounds is None:
                                bounds = list(frame_bounds)
                            else:
                                bounds = [
                                    min(bounds[0], frame_bounds[0]),
                                    min(bounds[1], frame_bounds[1]),
                                    max(bounds[2], frame_bounds[2]),
                                    max(bounds[3], frame_bounds[3]),
                                ]
                if bounds is None:
                    raise RuntimeError(f"No visible pixels found for {team}/{key}")

                width = bounds[2] - bounds[0]
                height = bounds[3] - bounds[1]
                scale = min(CONTENT / width, CONTENT / height)
                output_width = max(1, round(width * scale))
                output_height = max(1, round(height * scale))
                row = team_index * len(ANIMATIONS) + animation_index
                for frame_index in range(frame_count):
                    frame = source.crop(
                        (
                            frame_index * source_cell + bounds[0],
                            bounds[1],
                            frame_index * source_cell + bounds[2],
                            bounds[3],
                        )
                    )
                    frame = frame.resize((output_width, output_height), Image.Resampling.NEAREST)
                    x = (CELL - output_width) // 2
                    y = CELL - BOTTOM_MARGIN - output_height
                    atlas.alpha_composite(frame, (frame_index * CELL + x, row * CELL + y))
                manifest["animations"][f"{team.lower()}_{key}"] = {
                    "row": row,
                    "frames": frame_count,
                    "fps": 12 if "attack" in key or "shoot" in key else 8,
                    "source_frame": source_cell,
                    "source_bbox": bounds,
                    "output_size": [output_width, output_height],
                }

    atlas.save(args.output_dir / "combat_units_atlas.png", optimize=True)
    (args.output_dir / "atlas_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Created {args.output_dir / 'combat_units_atlas.png'}: {atlas.width}x{atlas.height}")


if __name__ == "__main__":
    main()
