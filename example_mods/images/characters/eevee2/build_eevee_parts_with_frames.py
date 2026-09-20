from PIL import Image
from pathlib import Path
import json

BASE = Path(__file__).parent

PARTS = [
    ("leg_back1", BASE / "leg back1.png"),
    ("leg_back2", BASE / "leg back2.png"),
    ("leg_front", BASE / "leg front.png"),
    ("tail", BASE / "tail.png"),
    ("body", BASE / "body.png"),
    ("ear1", BASE / "ear1.png"),
    ("ear2", BASE / "ear2.png"),
    ("fluff", BASE / "fluff.png"),
    ("head_sing", BASE / "head sing.png"),
    ("head_normal", BASE / "head-normal.png"),
]

SOURCE_ANIMATION = BASE / "Animation(1).json"
PADDING = 4

# Put every part into ONE PNG. Parts are not composited together.
parts = []
for name, path in PARTS:
    image = Image.open(path).convert("RGBA")
    bbox = image.getbbox()
    if bbox:
        image = image.crop(bbox)
    parts.append((name, image))

atlas_w = sum(img.width for _, img in parts) + PADDING * (len(parts) + 1)
atlas_h = max(img.height for _, img in parts) + PADDING * 2

atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
sprites = []
x = PADDING

for name, image in parts:
    y = PADDING
    atlas.alpha_composite(image, (x, y))
    sprites.append({
        "name": name,
        "x": x,
        "y": y,
        "w": image.width,
        "h": image.height,
        "rotated": False
    })
    x += image.width + PADDING

atlas.save(BASE / "spritemap1.png")

with open(BASE / "spritemap1.json", "w", encoding="utf-8") as f:
    json.dump(
        {"ATLAS": {"SPRITES": [{"SPRITE": s} for s in sprites]}},
        f, indent=2
    )

# Preserve the uploaded animation frames exactly.
with open(SOURCE_ANIMATION, "r", encoding="utf-8") as f:
    animation = json.load(f)

animation["PARTS"] = [name for name, _ in PARTS]

with open(BASE / "Animation.json", "w", encoding="utf-8") as f:
    json.dump(animation, f, indent=2)

print("Created:")
print("  spritemap1.png  - all 10 parts in one PNG")
print("  spritemap1.json - atlas entries for those 10 parts")
print("  Animation.json   - original 106 animation frames preserved")
