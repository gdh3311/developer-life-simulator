"""Generate the desk item SVGs and catalog under content/desk/.

Each SVG is authored at 2x its on-desk size so it stays crisp when the camera leans in.
Add a variant by appending to ITEMS and re-running:  python tools/gen_desk_assets.py
Players can also drop their own items into user://desk_assets/ (see content/desk/README.md).
"""
import colorsys
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "content" / "desk"

# Where each slot sits on the desk (room coordinates, 1920x1080 base) and how items attach.
SLOTS = {
    "keyboard": {"anchor": [960, 958], "origin": "center", "default": "kb_basic", "name": {"ko": "키보드", "en": "Keyboard"}},
    "mouse": {"anchor": [1430, 970], "origin": "center", "default": "mouse_basic", "name": {"ko": "마우스", "en": "Mouse"}},
    "mug": {"anchor": [470, 1034], "origin": "bottom", "default": "mug_white", "name": {"ko": "머그", "en": "Mug"}},
    "plant": {"anchor": [205, 900], "origin": "bottom", "default": "plant_fern", "name": {"ko": "화분", "en": "Plant"}},
}


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w * 2}" height="{h * 2}" viewBox="0 0 {w} {h}">\n'
            f"{body}\n</svg>\n")


def hexrgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


# --- keyboards (700 x 86) -------------------------------------------------------------

def keyboard(body, edge, key, accent=None, rainbow=False, glow=None):
    w, h = 700, 86
    parts = []
    if glow:
        parts.append(f'<ellipse cx="350" cy="80" rx="360" ry="10" fill="{glow}" opacity="0.35"/>')
    parts.append(f'<path d="M50 6 L650 6 L696 80 L4 80 Z" fill="{body}"/>')
    parts.append(f'<path d="M50 6 L650 6 L652 9 L48 9 Z" fill="{edge}"/>')
    for row in range(4):
        t = (row + 0.5) / 5.0
        y = 12 + row * 14
        half = 300 + 40 * t - 14
        keys = 15
        kw = half * 2 / keys
        for k in range(keys):
            x = 350 - half + k * kw + 1.5
            col = key
            if rainbow:
                col = hexrgb(k / keys + row * 0.07, 0.7, 0.92)
            elif accent and ((row == 0 and k == 0) or (row == 3 and k in (0, keys - 1))):
                col = accent
            parts.append(f'<rect x="{x:.1f}" y="{y}" width="{kw - 3:.1f}" height="10.5" rx="1.6" fill="{col}"/>')
    sx = 350 - 120
    space = hexrgb(0.55, 0.7, 0.92) if rainbow else key
    parts.append(f'<rect x="{sx}" y="68" width="240" height="9" rx="2" fill="{space}"/>')
    return svg(w, h, "\n".join(parts))


# --- mice (150 x 92) ----------------------------------------------------------------------

def mouse(pad, body, line, stripe=None, rim=None):
    parts = [f'<rect x="4" y="4" width="142" height="84" rx="6" fill="{pad}"/>']
    if rim:
        parts.append(f'<rect x="4" y="4" width="142" height="84" rx="6" fill="none" stroke="{rim}" stroke-width="2" opacity="0.8"/>')
    parts.append(f'<path d="M57 50 Q57 26 75 26 Q93 26 93 50 L93 62 Q93 76 75 76 Q57 76 57 62 Z" fill="{body}"/>')
    parts.append(f'<line x1="75" y1="28" x2="75" y2="44" stroke="{line}" stroke-width="2"/>')
    if stripe:
        parts.append(f'<rect x="73" y="52" width="4" height="16" rx="2" fill="{stripe}"/>')
    return svg(150, 92, "\n".join(parts))


# --- mugs (96 x 80, bottom-center anchored) ------------------------------------------------

def mug(body, rim, mark):
    parts = [
        f'<path d="M78 26 a16 16 0 0 1 0 32" fill="none" stroke="{body}" stroke-width="7"/>',
        f'<rect x="18" y="8" width="60" height="72" rx="4" fill="{body}"/>',
        f'<rect x="18" y="8" width="60" height="8" rx="3" fill="{rim}"/>',
        mark,
    ]
    return svg(96, 80, "\n".join(parts))


BRACES = '<path d="M38 34 q-6 0 -6 6 v4 q0 3 -3 3 q3 0 3 3 v4 q0 6 6 6 M58 34 q6 0 6 6 v4 q0 3 3 3 q-3 0 -3 3 v4 q0 6 -6 6" fill="none" stroke="#4f8cff" stroke-width="3" stroke-linecap="round"/>'
CHEVRON = '<path d="M40 38 L32 48 L40 58 M56 38 L64 48 L56 58" fill="none" stroke="#ffffff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'
GOLDLINE = '<rect x="18" y="60" width="60" height="3" fill="#c9a86a"/>'
MOON = '<path d="M54 34 a14 14 0 1 0 0 28 a11 11 0 1 1 0 -28 Z" fill="#f4c95d"/><circle cx="62" cy="40" r="2" fill="#f4c95d"/>'


# --- plants (220 x 210, bottom-center anchored) --------------------------------------------

def pot(color, lip):
    return (f'<path d="M66 140 L154 140 L144 210 L76 210 Z" fill="{color}"/>'
            f'<rect x="62" y="132" width="96" height="12" rx="2" fill="{lip}"/>')


def fern():
    leaves = []
    import math
    for i in range(7):
        a = math.radians(-150 + i * 20)
        length = 90 + (i % 3) * 18
        tipx, tipy = 110 + math.cos(a) * length, 150 + math.sin(a) * length
        midx, midy = (110 + tipx) / 2, (150 + tipy) / 2
        nx, ny = -(tipy - 150), (tipx - 110)
        n = math.hypot(nx, ny) or 1
        nx, ny = nx / n * 14, ny / n * 14
        shade = ["#2f6b45", "#367a4f", "#3d8858"][i % 3]
        leaves.append(f'<path d="M110 150 L{midx + nx:.1f} {midy + ny:.1f} L{tipx:.1f} {tipy:.1f} L{midx - nx:.1f} {midy - ny:.1f} Z" fill="{shade}"/>')
    return svg(220, 210, "\n".join(leaves) + pot("#c2734f", "#d48562"))


def snake():
    leaves = []
    for i, (x, hgt, lean) in enumerate([(84, 120, -10), (100, 150, -4), (116, 160, 3), (132, 130, 9), (148, 100, 14)]):
        top = 140 - hgt
        leaves.append(f'<path d="M{x - 9} 140 Q{x - 12 + lean} {top + 40} {x + lean} {top} Q{x + 12 + lean} {top + 40} {x + 9} 140 Z" fill="#2e5e3a" stroke="#c8c255" stroke-width="2"/>')
        leaves.append(f'<path d="M{x + lean * 0.6:.1f} {top + 30} L{x} 130" stroke="#3f7a4c" stroke-width="2"/>')
    return svg(220, 210, "\n".join(leaves) + pot("#e9e4da", "#d9d2c5"))


def cactus():
    body = [
        '<rect x="96" y="40" width="30" height="104" rx="15" fill="#4c8b4a"/>',
        '<path d="M96 96 h-16 q-8 0 -8 -8 v-24 q0 -6 6 -6 q6 0 6 6 v18 h12" fill="#4c8b4a"/>',
        '<path d="M126 80 h14 q8 0 8 -8 v-18 q0 -6 -6 -6 q-6 0 -6 6 v14 h-10" fill="#4c8b4a"/>',
        '<line x1="111" y1="48" x2="111" y2="138" stroke="#3b7339" stroke-width="2"/>',
        '<circle cx="111" cy="38" r="6" fill="#f472b6"/>',
    ]
    return svg(220, 210, "\n".join(body) + pot("#b8643f", "#cc7a55"))


def succulent():
    import math
    petals = []
    for ring, (count, r, col) in enumerate([(10, 46, "#7fb59a"), (8, 32, "#94c8ad"), (6, 18, "#acd9c1")]):
        for i in range(count):
            a = 2 * math.pi * (i + ring * 0.5) / count
            x, y = 110 + math.cos(a) * r, 118 + math.sin(a) * r * 0.45
            petals.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{14 - ring * 3}" ry="{8 - ring * 1.5}" fill="{col}" transform="rotate({math.degrees(a):.0f} {x:.1f} {y:.1f})"/>')
    return svg(220, 210, "\n".join(petals) + pot("#f2f2f0", "#e2e2de"))


ITEMS = [
    # keyboards
    ("kb_basic", "keyboard", {"ko": "기본 키보드", "en": "Standard keyboard"}, keyboard("#1b1e25", "#343a46", "#2a2e38"), {}, [700, 86]),
    ("kb_white", "keyboard", {"ko": "화이트 키보드", "en": "White keyboard"}, keyboard("#d6d9df", "#eef0f3", "#f5f6f8", accent="#9fb4d8"), {}, [700, 86]),
    ("kb_rgb", "keyboard", {"ko": "기계식 RGB 키보드", "en": "Mechanical RGB keyboard"}, keyboard("#121318", "#2a2d36", "#2a2e38", rainbow=True, glow="#7c5cff"), {"owned": "keyboard_rgb"}, [700, 86]),
    ("kb_retro", "keyboard", {"ko": "레트로 키보드", "en": "Retro keyboard"}, keyboard("#c9bd9c", "#ddd3b7", "#ebe3cb", accent="#b5523b"), {"rank": 2}, [700, 86]),
    # mice
    ("mouse_basic", "mouse", {"ko": "기본 마우스", "en": "Standard mouse"}, mouse("#15171d", "#1f2229", "#2e323c"), {}, [150, 92]),
    ("mouse_white", "mouse", {"ko": "화이트 마우스", "en": "White mouse"}, mouse("#2b3140", "#eceef2", "#c4c8d0"), {}, [150, 92]),
    ("mouse_gaming", "mouse", {"ko": "게이밍 마우스", "en": "Gaming mouse"}, mouse("#0f1013", "#1a1c22", "#2e323c", stripe="#39ff8f", rim="#39ff8f"), {"owned": "keyboard_rgb"}, [150, 92]),
    # mugs
    ("mug_white", "mug", {"ko": "{ } 머그", "en": "{ } mug"}, mug("#e8e2d6", "#cfc8bb", BRACES), {}, [96, 80]),
    ("mug_black", "mug", {"ko": "무광 블랙 머그", "en": "Matte black mug"}, mug("#1d1f24", "#2a2d34", GOLDLINE), {}, [96, 80]),
    ("mug_nexora", "mug", {"ko": "NEXORA 굿즈 머그", "en": "NEXORA swag mug"}, mug("#3b5bdb", "#2f4bc0", CHEVRON), {"rank": 1}, [96, 80]),
    ("mug_moonlight", "mug", {"ko": "달빛상점 선물 머그", "en": "Moonlight gift mug"}, mug("#f3ead7", "#e2d6bc", MOON), {"story": "c02_08"}, [96, 80]),
    # plants
    ("plant_fern", "plant", {"ko": "고사리", "en": "Fern"}, fern(), {}, [220, 210]),
    ("plant_snake", "plant", {"ko": "산세베리아", "en": "Snake plant"}, snake(), {}, [220, 210]),
    ("plant_cactus", "plant", {"ko": "선인장", "en": "Cactus"}, cactus(), {}, [220, 210]),
    ("plant_succulent", "plant", {"ko": "다육이", "en": "Succulent"}, succulent(), {"story": "c03_06"}, [220, 210]),
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    catalog = {"version": 1, "slots": SLOTS, "items": []}
    for item_id, slot, name, text, unlock, size in ITEMS:
        (OUT / f"{item_id}.svg").write_text(text, encoding="utf-8", newline="\n")
        catalog["items"].append({"id": item_id, "slot": slot, "name": name, "file": f"res://content/desk/{item_id}.svg", "size": size, "unlock": unlock})
    (OUT / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(ITEMS)} desk items written to {OUT}")


if __name__ == "__main__":
    main()
