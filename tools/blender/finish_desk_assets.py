"""Turns the Blender renders into game assets.

- Desk items, mats and decor: crop build/desk_renders/<id>.png to its pixels, scale to twice its on-desk
  size, write content/desk/<id>.png and record the size in content/desk/render_sizes.json. Then rebuild
  catalog.json with tools/gen_desk_assets.py (which lists names and unlock rules).
- Window: copy build/city_renders/window_{day,dusk,night}.png into content/room/.

Run after tools/blender/desk_models.py and tools/blender/city_window.py.
"""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DESK = ROOT / "content" / "desk"
RENDERS = ROOT / "build" / "desk_renders"
CITY = ROOT / "build" / "city_renders"

# On-desk size rule per slot: fix one side, keep the render's aspect.
RULES = {"keyboard": ("w", 700), "mouse": ("w", 128), "mug": ("h", 92), "plant": ("h", 215), "mat": ("w", 1240), "decor": ("h", 92)}
MAX_W = {"plant": 250, "mug": 130, "decor": 150}
# Decor items keep believable relative sizes (on-desk height in px).
DECOR_H = {"decor_pen_cup": 112, "decor_clock": 78, "decor_duck": 62, "decor_robot": 98, "decor_lucky_cat": 102,
           "decor_trophy": 104, "decor_controller": 44, "decor_cube": 54, "decor_bonsai": 92, "decor_snowglobe": 84,
           "decor_rocket": 112, "decor_task_lamp": 158, "decor_film_camera": 72, "decor_notebook": 49}
PREFIX = [("kb_", "keyboard"), ("mouse_", "mouse"), ("mug_", "mug"), ("plant_", "plant"), ("mat_", "mat"), ("decor_", "decor")]


def slot_of(item_id):
    for prefix, slot in PREFIX:
        if item_id.startswith(prefix):
            return slot
    return None


def main():
    only = set(sys.argv[1:])
    sizes_path = DESK / "render_sizes.json"
    sizes = json.loads(sizes_path.read_text(encoding="utf-8")) if only else {}
    for src in sorted(RENDERS.glob("*.png")):
        item_id = src.stem
        if only and item_id not in only:
            continue
        slot = slot_of(item_id)
        if slot is None:
            continue
        im = Image.open(src).convert("RGBA")
        im = im.crop(im.getbbox())
        side, value = RULES[slot]
        if item_id in DECOR_H:
            side, value = "h", DECOR_H[item_id]
        aspect = im.width / im.height
        w, h = (value, value / aspect) if side == "w" else (value * aspect, value)
        if w > MAX_W.get(slot, 10 ** 6):
            w = MAX_W[slot]
            h = w / aspect
        w, h = round(w), round(h)
        im.resize((w * 2, h * 2), Image.LANCZOS).save(DESK / f"{item_id}.png", optimize=True)
        sizes[item_id] = [w, h]
    # "No mat": a transparent placeholder so the picker can offer it like any other item.
    Image.new("RGBA", (4, 4), (0, 0, 0, 0)).save(DESK / "mat_none.png")
    sizes["mat_none"] = [2, 2]
    (DESK / "render_sizes.json").write_text(json.dumps(sizes, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(sizes)} rendered items")
    subprocess.run([sys.executable, str(ROOT / "tools" / "gen_desk_assets.py")], check=True)
    if only:
        return
    room = ROOT / "content" / "room"
    room.mkdir(exist_ok=True)
    for name in ("day", "dusk", "night"):
        src = CITY / f"window_{name}.png"
        if src.exists():
            Image.open(src).convert("RGB").save(room / f"window_{name}.png", optimize=True)
    print("window views copied")


if __name__ == "__main__":
    main()
