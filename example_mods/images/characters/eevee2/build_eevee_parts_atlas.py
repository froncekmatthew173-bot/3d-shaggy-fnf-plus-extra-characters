#!/usr/bin/env python3
"""Build an atlas containing ONLY the supplied PNG parts.

Inputs (same folder as this script):
  leg back1.png, leg back2.png, leg front.png, tail.png, body.png,
  ear1.png, ear2.png, fluff.png, head sing.png, head-normal.png

Outputs:
  spritemap1.png  - contains only the original part images, never composites
  spritemap1.json - atlas coordinates for those exact parts
  Animation.json  - one frame entry per part, pointing at the atlas sprite

No animation poses are generated and no parts are composited together.
"""
from pathlib import Path
import argparse
import json
from PIL import Image

PART_FILES = [
    ("leg_back1", "leg back1.png"),
    ("leg_back2", "leg back2.png"),
    ("leg_front", "leg front.png"),
    ("tail", "tail.png"),
    ("body", "body.png"),
    ("ear1", "ear1.png"),
    ("ear2", "ear2.png"),
    ("fluff", "fluff.png"),
    ("head_sing", "head sing.png"),
    ("head_normal", "head-normal.png"),
]


def load_parts(root: Path):
    parts = []
    for name, filename in PART_FILES:
        path = root / filename
        if not path.exists():
            raise FileNotFoundError(f"Missing part: {path}")
        img = Image.open(path).convert("RGBA")
        parts.append((name, filename, img))
    return parts


def pack_parts(parts, padding=4, columns=5):
    columns = max(1, min(columns, len(parts)))
    rows = (len(parts) + columns - 1) // columns
    cell_w = max(img.width for _, _, img in parts) + padding
    cell_h = max(img.height for _, _, img in parts) + padding

    atlas = Image.new("RGBA", (columns * cell_w + padding, rows * cell_h + padding), (0, 0, 0, 0))
    sprites = []

    for i, (name, filename, img) in enumerate(parts):
        col = i % columns
        row = i // columns
        x = padding + col * cell_w
        y = padding + row * cell_h
        atlas.alpha_composite(img, (x, y))
        sprites.append({
            "SPRITE": {
                "name": name,
                "x": x,
                "y": y,
                "w": img.width,
                "h": img.height,
                "rotated": False,
            }
        })
    return atlas, sprites


def make_animation_json(parts):
    frames = []
    for i, (name, _, _) in enumerate(parts):
        frames.append({
            "N": name,
            "I": i,
            "DU": 1,
            "E": []
        })
    return {
        "AN": {
            "N": "Eevee Parts",
            "SN": "Eevee Parts",
            "TL": [{
                "LN": "Layer_2",
                "FR": frames
            }]
        }
    }


def save_json(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--input", type=Path, default=Path("."))
    ap.add_argument("-o", "--output", type=Path, default=None)
    ap.add_argument("--columns", type=int, default=5)
    args = ap.parse_args()

    root = args.input.resolve()
    out = (args.output or root).resolve()
    out.mkdir(parents=True, exist_ok=True)

    parts = load_parts(root)
    atlas, sprites = pack_parts(parts, columns=args.columns)

    atlas.save(out / "spritemap1.png")
    save_json(out / "spritemap1.json", {"ATLAS": {"SPRITES": sprites}})
    save_json(out / "Animation.json", make_animation_json(parts))

    print(f"Created {out / 'spritemap1.png'}")
    print(f"Created {out / 'spritemap1.json'}")
    print(f"Created {out / 'Animation.json'}")
    print(f"Parts: {len(parts)}")
    for name, filename, img in parts:
        print(f"  {name}: {img.width}x{img.height} ({filename})")


if __name__ == "__main__":
    main()
