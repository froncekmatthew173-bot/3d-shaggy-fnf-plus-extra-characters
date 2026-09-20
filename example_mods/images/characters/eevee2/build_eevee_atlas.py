#!/usr/bin/env python3
"""
Build an Adobe-Texture-Atlas-style spritemap1.png + spritemap1.json
and Animation.json from the small Eevee layer PNGs.

Put this script in the same folder as:
    leg back1.png
    leg back2.png
    leg front.png
    tail.png
    body.png
    ear1.png
    ear2.png
    fluff.png
    head sing.png
    head-normal.png

The supplied PNGs are aligned 37x56 transparent layers, so the script
composites them at (0, 0) instead of trying to crop/reposition them.

Outputs:
    spritemap1.png
    spritemap1.json
    Animation.json

The JSON format matches the structure in the supplied files:
    spritemap1.json -> {"ATLAS":{"SPRITES":[...]}}
    Animation.json  -> {"AN":{"N":...,"SN":...,"TL":{"L":[...]}}}

Only the layers you actually have can be used to make frames. This script
does NOT invent the missing artwork needed to recreate the original 106
unique poses. It can, however, repeat generated variants to fill an
animation sequence if you ask for more frames.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import math
from PIL import Image


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

PART_FILES = {
    "leg_back1": "leg back1.png",
    "leg_back2": "leg back2.png",
    "leg_front": "leg front.png",
    "tail": "tail.png",
    "body": "body.png",
    "ear1": "ear1.png",
    "ear2": "ear2.png",
    "fluff": "fluff.png",
    "head_sing": "head sing.png",
    "head_normal": "head-normal.png",
}

CANVAS_W = 37
CANVAS_H = 56

# Animation definitions. Change these if you want different names/frame counts.
# "frames" is how many atlas frames the animation uses.
ANIMATIONS = {
    "idle": 12,
    "singLEFT": 6,
    "singDOWN": 6,
    "singUP": 6,
    "singRIGHT": 6,
    "singLEFT-loop": 6,
    "singDOWN-loop": 6,
    "singUP-loop": 6,
    "singRIGHT-loop": 6,
    "singLEFTmiss": 4,
    "singDOWNmiss": 4,
    "singUPmiss": 4,
    "singRIGHTmiss": 4,
    "hey": 4,
    "hurt": 3,
    "hit": 3,
    "scared": 6,
    "dodge": 4,
    "attack": 6,
    "pre-attack": 4,
}

# Layer order matters. Later layers are drawn on top.
LAYER_ORDER = [
    "leg_back1",
    "leg_back2",
    "leg_front",
    "tail",
    "body",
    "fluff",
    "ear1",
    "ear2",
    "head_normal",
]

# A small set of real variants that can be made from the supplied layers.
# The script cycles through these when an animation needs more frames.
VARIANTS = [
    {
        "head": "head_normal",
        "back_leg": "leg_back1",
        "front_leg": "leg_front",
    },
    {
        "head": "head_sing",
        "back_leg": "leg_back1",
        "front_leg": "leg_front",
    },
    {
        "head": "head_normal",
        "back_leg": "leg_back2",
        "front_leg": "leg_front",
    },
    {
        "head": "head_sing",
        "back_leg": "leg_back2",
        "front_leg": "leg_front",
    },
]


def load_parts(root: Path) -> dict[str, Image.Image]:
    parts = {}

    for key, filename in PART_FILES.items():
        path = root / filename
        if not path.exists():
            raise FileNotFoundError(f"Missing layer: {path}")

        image = Image.open(path).convert("RGBA")

        if image.size != (CANVAS_W, CANVAS_H):
            raise ValueError(
                f"{filename} is {image.size}, expected "
                f"{CANVAS_W}x{CANVAS_H}."
            )

        parts[key] = image

    return parts


def composite_frame(parts: dict[str, Image.Image], variant: dict) -> Image.Image:
    """
    Composite the aligned layers into one 37x56 frame.
    """

    frame = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))

    # Draw the normal layers first, skipping the variant-controlled pieces.
    for name in LAYER_ORDER:
        if name in ("leg_back1", "leg_back2", "head_normal"):
            continue

        if name == "leg_front":
            frame.alpha_composite(parts[variant["front_leg"]], (0, 0))
        else:
            frame.alpha_composite(parts[name], (0, 0))

    # Back leg goes underneath the body/fluff in the final image.
    # Rebuild in a deliberate order so the legs are behind the body.
    frame = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))

    for name in ("leg_back1", "leg_back2"):
        if name == variant["back_leg"]:
            frame.alpha_composite(parts[name], (0, 0))

    for name in ("tail", "body", "leg_front", "fluff", "ear1", "ear2"):
        frame.alpha_composite(parts[name], (0, 0))

    frame.alpha_composite(parts[variant["head"]], (0, 0))

    return frame


def read_animation_template(path: Path) -> dict | None:
    if not path.exists():
        return None

    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def get_template_frames(animation_data: dict | None) -> list[dict]:
    if not animation_data:
        entries = []
        for animation_name, requested_count in ANIMATIONS.items():
            for _ in range(requested_count):
                entries.append({
                    "N": animation_name,
                    "DU": 1,
                    "E": [],
                })
        return entries

    try:
        return animation_data["AN"]["TL"]["L"][0]["FR"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError(
            "Animation.json does not have the expected "
            "AN -> TL -> L[0] -> FR structure."
        ) from exc


def make_frames(
    parts: dict[str, Image.Image],
    frame_count: int,
) -> list[Image.Image]:
    """
    Make exactly frame_count atlas frames.

    The supplied artwork only contains a few layer variants, so the available
    variants are cycled. Replace/extend VARIANTS when you have more pose PNGs.
    """

    frames = []
    for index in range(frame_count):
        variant = VARIANTS[index % len(VARIANTS)]
        frames.append(composite_frame(parts, variant))
    return frames


def pack_sprites(frames: list[Image.Image], columns: int = 8, padding: int = 4):
    """
    Simple deterministic row-major atlas packing.

    Returns:
        atlas image
        list of sprite records
    """

    columns = max(1, min(columns, len(frames)))
    rows = math.ceil(len(frames) / columns)

    cell_w = CANVAS_W + padding
    cell_h = CANVAS_H + padding

    atlas_w = columns * cell_w + padding
    atlas_h = rows * cell_h + padding

    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    sprites = []

    for index, frame in enumerate(frames):
        col = index % columns
        row = index // columns

        x = padding + col * cell_w
        y = padding + row * cell_h

        atlas.alpha_composite(frame, (x, y))

        sprites.append({
            "SPRITE": {
                "name": f"{index:04d}",
                "x": x,
                "y": y,
                "w": CANVAS_W,
                "h": CANVAS_H,
                "rotated": False,
            }
        })

    return atlas, sprites


def build_spritemap_json(sprites: list[dict]) -> dict:
    return {
        "ATLAS": {
            "SPRITES": sprites
        }
    }


def build_animation_json(
    template: dict | None,
    entries: list[dict],
) -> dict:
    """
    Preserve the supplied Animation.json structure and animation names.

    The only changed field is I, which is reassigned to the new atlas frame
    number so that it always matches spritemap1.json.
    """

    if template:
        result = json.loads(json.dumps(template))
        frames = result["AN"]["TL"]["L"][0]["FR"]

        for i, frame in enumerate(frames):
            frame["I"] = i

        return result

    generated = []
    for i, entry in enumerate(entries):
        generated.append({
            "N": entry["N"],
            "I": i,
            "DU": entry.get("DU", 1),
            "E": entry.get("E", []),
        })

    return {
        "AN": {
            "N": "Eevee Animations",
            "SN": "Eevee Animations",
            "TL": {
                "L": [
                    {
                        "LN": "Layer_2",
                        "FR": generated,
                    }
                ]
            }
        }
    }


def save_json(path: Path, data: dict):
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def main():
    parser = argparse.ArgumentParser(
        description="Build spritemap1.png/spritemap1.json and Animation.json."
    )
    parser.add_argument(
        "-i", "--input",
        type=Path,
        default=Path("."),
        help="Folder containing the PNG layers.",
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=None,
        help="Output folder. Defaults to the input folder.",
    )
    parser.add_argument(
        "--columns",
        type=int,
        default=8,
        help="Number of atlas columns.",
    )

    args = parser.parse_args()

    root = args.input.resolve()
    output = (args.output or root).resolve()
    output.mkdir(parents=True, exist_ok=True)

    parts = load_parts(root)

    template_path = root / "Animation.json"
    template = read_animation_template(template_path)
    animation_entries = get_template_frames(template)

    # If Animation.json is supplied, make exactly as many atlas frames as it
    # contains. The uploaded template contains 106 frames.
    frame_count = len(animation_entries)
    frames = make_frames(parts, frame_count)

    atlas, sprites = pack_sprites(frames, columns=args.columns)

    atlas_path = output / "spritemap1.png"
    spritemap_path = output / "spritemap1.json"
    animation_path = output / "Animation.json"

    atlas.save(atlas_path)
    save_json(spritemap_path, build_spritemap_json(sprites))
    save_json(
        animation_path,
        build_animation_json(template, animation_entries)
    )

    print("Done!")
    print(f"  Atlas:       {atlas_path}")
    print(f"  Spritemap:   {spritemap_path}")
    print(f"  Animations:  {animation_path}")
    print(f"  Atlas frames: {len(frames)}")
    print(f"  Atlas size:   {atlas.size[0]}x{atlas.size[1]}")
    print()
    print("NOTE:")
    print("The supplied Animation.json is used as the animation template.")
    print("The uploaded artwork has only a few layer variants, so those")
    print("variants are cycled to fill the template's frame count.")
    print("Add more pose/layer PNGs to VARIANTS for unique animation frames.")


if __name__ == "__main__":
    main()
