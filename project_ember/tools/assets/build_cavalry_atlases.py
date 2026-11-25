#!/usr/bin/env python3
"""Normalize user-supplied mounted horse sheets into one stable 88x82 atlas."""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CAVALRY = ROOT / "assets" / "combat" / "cavalry"
CELL_W, CELL_H = 88, 82
COLUMNS, ROWS = 16, 4

# Source sheet dimensions are measured against the visible alpha-cell grid.
SOURCES = {
    "idle": {"file": "{team}_riding.png", "x": 80, "y": 64, "row": 0, "count": 11, "fps": 8, "loop": True, "pad_x": 4, "pad_y": 18},
    "run": {"file": "{team}_riding.png", "x": 80, "y": 64, "row": 3, "count": 8, "fps": 12, "loop": True, "pad_x": 4, "pad_y": 18},
    "attack": {"file": "{team}_rearing.png", "x": 88, "y": 66, "row": 0, "count": 12, "fps": 14, "loop": False, "pad_x": 0, "pad_y": 16},
    "charge": {"file": "{team}_jump.png", "x": 80, "y": 82, "row": 0, "count": 16, "fps": 16, "loop": False, "pad_x": 4, "pad_y": 0},
}


def crop_frame(sheet: Image.Image, x: int, y: int, width: int, height: int,
               pad_x: int, pad_y: int) -> Image.Image:
    frame = sheet.crop((x, y, x + width, y + height))
    if frame.size != (width, height):
        raise ValueError(f"Frame outside source bounds: {(x, y, width, height)} / {sheet.size}")
    target = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    target.alpha_composite(frame, (pad_x, pad_y))
    return target


def build(team: str) -> dict:
    atlas = Image.new("RGBA", (COLUMNS * CELL_W, ROWS * CELL_H), (0, 0, 0, 0))
    details = {}
    for row_index, (animation, data) in enumerate(SOURCES.items()):
        path = CAVALRY / data["file"].format(team=team)
        source = Image.open(path).convert("RGBA")
        frames = []
        for frame_index in range(data["count"]):
            frame = crop_frame(
                source,
                frame_index * data["x"],
                data["row"] * data["y"],
                data["x"], data["y"], data["pad_x"], data["pad_y"],
            )
            atlas.alpha_composite(frame, (frame_index * CELL_W, row_index * CELL_H))
            frames.append({
                "column": frame_index,
                "source_x": frame_index * data["x"],
                "source_y": data["row"] * data["y"],
                "source_cell": [data["x"], data["y"]],
            })
        details[animation] = {
            "row": row_index,
            "frames": data["count"],
            "fps": data["fps"],
            "loop": data["loop"],
            "source_sheet": path.name,
            "source_row": data["row"],
            "source_cell": [data["x"], data["y"]],
            "padding": [data["pad_x"], data["pad_y"]],
            "frame_map": frames,
        }
    output = CAVALRY / f"{team}_animations.png"
    atlas.save(output, optimize=True)
    return details


def main() -> None:
    both = {team: build(team) for team in ("blue", "red")}
    manifest = {
        "source_archive": "user-supplied Full_Pack.zip",
        "source_notice": "Original archive contained no README/license file. See SOURCE_NOTICE.txt.",
        "runtime_atlas": {"cell_size": [CELL_W, CELL_H], "columns": COLUMNS, "rows": ROWS,
                          "teams": ["blue", "red"], "filter": "nearest"},
        "teams": both,
    }
    (CAVALRY / "animation_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Built blue_animations.png and red_animations.png: {COLUMNS*CELL_W}x{ROWS*CELL_H}")
    for team in both:
        print(team + ": " + ", ".join(f"{name}={item['frames']}" for name, item in both[team].items()))


if __name__ == "__main__":
    main()
