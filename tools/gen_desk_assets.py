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
    "keyboard": {"anchor": [960, 988], "origin": "center", "default": "kb_basic", "name": {"ko": "키보드", "en": "Keyboard"}},
    "mouse": {"anchor": [1430, 992], "origin": "center", "default": "mouse_basic", "name": {"ko": "마우스", "en": "Mouse"}},
    "mug": {"anchor": [470, 1034], "origin": "bottom", "default": "mug_white", "name": {"ko": "머그", "en": "Mug"}},
    "plant": {"anchor": [205, 900], "origin": "bottom", "default": "plant_fern", "name": {"ko": "화분", "en": "Plant"}},
    "mat": {"anchor": [960, 992], "origin": "center", "default": "mat_none", "name": {"ko": "데스크 매트", "en": "Desk mat"}},
}

# Items that exist only as Blender renders (tools/blender/desk_models.py): mats and collectible decor.
# Decor isn't a slot: you place up to MAX_DECOR of them anywhere on the desk in decorating mode.
# unlock: owned (shop) · rank · story (mission done) · achievement · tickets (small tickets done) · stat [key, n]
RENDER_ONLY = [
    ("kb_moss", "keyboard", {"ko": "모스 알루미늄 키보드", "en": "Moss aluminium keyboard"}, {}),
    ("mat_none", "mat", {"ko": "매트 없음", "en": "No mat"}, {}),
    ("mat_navy", "mat", {"ko": "네이비 펠트", "en": "Navy felt"}, {}),
    ("mat_cork", "mat", {"ko": "코르크", "en": "Cork"}, {"rank": 1}),
    ("mat_pixel", "mat", {"ko": "픽셀 패턴", "en": "Pixel pattern"}, {"achievement": "first_merge"}),
    ("mat_rgb", "mat", {"ko": "RGB 매트", "en": "RGB mat"}, {"owned": "keyboard_rgb"}),
    ("decor_pen_cup", "decor", {"ko": "펜꽂이", "en": "Pen cup"}, {}),
    ("decor_clock", "decor", {"ko": "자명종", "en": "Alarm clock"}, {}),
    ("decor_task_lamp", "decor", {"ko": "머시룸 조명", "en": "Mushroom lamp"}, {}),
    ("decor_film_camera", "decor", {"ko": "필름 카메라", "en": "Film camera"}, {"rank": 1}),
    ("decor_notebook", "decor", {"ko": "작업 노트", "en": "Field notebook"}, {}),
    ("decor_duck", "decor", {"ko": "디버깅 고무 오리", "en": "Debugging duck"}, {"tickets": 1}),
    ("decor_robot", "decor", {"ko": "장난감 로봇", "en": "Toy robot"}, {"stat": ["ai_used", 3]}),
    ("decor_lucky_cat", "decor", {"ko": "복고양이", "en": "Lucky cat"}, {"achievement": "moonlight"}),
    ("decor_rocket", "decor", {"ko": "출시 로켓", "en": "Launch rocket"}, {"achievement": "launch"}),
    ("decor_controller", "decor", {"ko": "게임패드", "en": "Gamepad"}, {"achievement": "game_dev"}),
    ("decor_trophy", "decor", {"ko": "완벽한 하루 트로피", "en": "Perfect-day trophy"}, {"achievement": "perfect_day"}),
    ("decor_cube", "decor", {"ko": "큐브 퍼즐", "en": "Puzzle cube"}, {"tickets": 5}),
    ("decor_bonsai", "decor", {"ko": "분재", "en": "Bonsai"}, {"achievement": "specialist"}),
    ("decor_snowglobe", "decor", {"ko": "도시 스노우볼", "en": "City snow globe"}, {"story": "c05_08"}),
]


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w * 2}" height="{h * 2}" viewBox="0 0 {w} {h}">\n'
            f"{body}\n</svg>\n")


def hexrgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return "#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))


# --- shared shading ------------------------------------------------------------------------

def lin(id_, stops, x2=0, y2=1):
    body = "".join(f'<stop offset="{o}" stop-color="{c}"{f" stop-opacity={chr(34)}{a}{chr(34)}" if a is not None else ""}/>' for o, c, a in stops)
    return f'<linearGradient id="{id_}" x1="0" y1="0" x2="{x2}" y2="{y2}">{body}</linearGradient>'


def rad(id_, stops, cx=0.4, cy=0.35, r=0.8):
    body = "".join(f'<stop offset="{o}" stop-color="{c}"{f" stop-opacity={chr(34)}{a}{chr(34)}" if a is not None else ""}/>' for o, c, a in stops)
    return f'<radialGradient id="{id_}" cx="{cx}" cy="{cy}" r="{r}">{body}</radialGradient>'


def shade(hex_color, k):
    """k > 0 lightens, k < 0 darkens."""
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    if k >= 0:
        r, g, b = (int(c + (255 - c) * k) for c in (r, g, b))
    else:
        r, g, b = (int(c * (1 + k)) for c in (r, g, b))
    return "#%02x%02x%02x" % (r, g, b)


# --- keyboards (700 x 90) ---------------------------------------------------------------

def keyboard(body, edge, key, accent=None, rainbow=False, glow=None):
    """Body with a lit top edge and a front lip; every key is a cap (side) plus a lighter top face."""
    w, h = 700, 90
    defs = [lin("body", [(0, shade(body, 0.12), None), (0.7, body, None), (1, shade(body, -0.35), None)]),
            lin("lip", [(0, shade(body, -0.25), None), (1, shade(body, -0.55), None)])]
    parts = [f'<ellipse cx="350" cy="86" rx="345" ry="5" fill="#000" opacity="0.45"/>']
    if glow:
        defs.append(rad("glow", [(0, glow, 0.55), (1, glow, 0)], cx=0.5, cy=0.5, r=0.5))
        parts.append('<ellipse cx="350" cy="84" rx="372" ry="14" fill="url(#glow)"/>')
    parts.append('<path d="M48 4 L652 4 L698 78 L2 78 Z" fill="url(#body)"/>')
    parts.append('<path d="M2 78 L698 78 L696 85 L4 85 Z" fill="url(#lip)"/>')
    parts.append(f'<path d="M48 4 L652 4 L653.5 6.5 L46.5 6.5 Z" fill="{edge}" opacity="0.9"/>')
    for row in range(4):
        t = (row + 0.5) / 5.0
        y = 11 + row * 14
        half = 300 + 40 * t - 16
        keys = 15
        kw = half * 2 / keys
        for k in range(keys):
            x = 350 - half + k * kw + 1.6
            col = key
            if rainbow:
                col = hexrgb(k / keys + row * 0.07, 0.75, 0.95)
            elif accent and ((row == 0 and k == 0) or (row == 3 and k in (0, keys - 1)) or (row == 2 and k == keys - 1)):
                col = accent
            parts.append(f'<rect x="{x:.1f}" y="{y}" width="{kw - 3.2:.1f}" height="11.5" rx="2" fill="{shade(col, -0.38)}"/>')
            parts.append(f'<rect x="{x + 1.2:.1f}" y="{y + 0.6}" width="{kw - 5.6:.1f}" height="8.2" rx="1.6" fill="{shade(col, 0.1)}"/>')
            if not rainbow:
                parts.append(f'<rect x="{x + 2.4:.1f}" y="{y + 1.6}" width="{(kw - 5.6) * 0.35:.1f}" height="1.4" rx="0.6" fill="{shade(col, 0.45)}" opacity="0.7"/>')
    space = hexrgb(0.55, 0.75, 0.95) if rainbow else key
    parts.append(f'<rect x="230" y="67" width="240" height="11" rx="2.5" fill="{shade(space, -0.38)}"/>')
    parts.append(f'<rect x="231.5" y="67.6" width="237" height="7.8" rx="2" fill="{shade(space, 0.1)}"/>')
    return svg(w, h, "<defs>" + "".join(defs) + "</defs>\n" + "\n".join(parts))


# --- mice (150 x 92) ----------------------------------------------------------------------

def mouse(pad, body, line, stripe=None, rim=None):
    defs = [lin("pad", [(0, shade(pad, 0.1), None), (1, shade(pad, -0.2), None)]),
            rad("shell", [(0, shade(body, 0.45), None), (0.5, body, None), (1, shade(body, -0.45), None)], cx=0.38, cy=0.25, r=0.9)]
    parts = [
        '<rect x="4" y="6" width="142" height="84" rx="8" fill="#000" opacity="0.35"/>',
        '<rect x="4" y="4" width="142" height="84" rx="8" fill="url(#pad)"/>',
        f'<rect x="8" y="8" width="134" height="76" rx="6" fill="none" stroke="{shade(pad, 0.18)}" stroke-width="1" stroke-dasharray="3 3" opacity="0.6"/>',
    ]
    if rim:
        parts.append(f'<rect x="4" y="4" width="142" height="84" rx="8" fill="none" stroke="{rim}" stroke-width="2.2" opacity="0.85"/>')
    parts += [
        '<ellipse cx="77" cy="74" rx="20" ry="5" fill="#000" opacity="0.35"/>',
        '<path d="M56 48 Q56 22 75 22 Q94 22 94 48 L94 60 Q94 77 75 77 Q56 77 56 60 Z" fill="url(#shell)"/>',
        f'<path d="M75 23 L75 44" stroke="{line}" stroke-width="1.6"/>',
        f'<rect x="72.5" y="29" width="5" height="9" rx="2.5" fill="{shade(line, -0.2)}"/>',
        '<path d="M62 34 Q64 26 71 25" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" opacity="0.45"/>',
    ]
    if stripe:
        defs.append(rad("led", [(0, stripe, 0.9), (1, stripe, 0)], cx=0.5, cy=0.5, r=0.5))
        parts.append('<ellipse cx="75" cy="60" rx="10" ry="12" fill="url(#led)"/>')
        parts.append(f'<rect x="73.4" y="52" width="3.2" height="15" rx="1.6" fill="{stripe}"/>')
    return svg(150, 92, "<defs>" + "".join(defs) + "</defs>\n" + "\n".join(parts))


# --- mugs (96 x 80, bottom-center anchored) ------------------------------------------------

def mug(body, rim, mark, drink="#4a2c18"):
    defs = [lin("cyl", [(0, shade(body, -0.28), None), (0.3, shade(body, 0.14), None), (0.62, body, None), (1, shade(body, -0.4), None)], x2=1, y2=0),
            lin("inside", [(0, shade(rim, -0.45), None), (1, shade(rim, -0.1), None)]),
            rad("drink", [(0, shade(drink, 0.35), None), (1, drink, None)], cx=0.4, cy=0.4, r=0.7)]
    parts = [
        '<ellipse cx="48" cy="78" rx="34" ry="3" fill="#000" opacity="0.35"/>',
        f'<path d="M76 26 C94 24 95 58 76 58" fill="none" stroke="{shade(body, -0.25)}" stroke-width="7" stroke-linecap="round"/>',
        f'<path d="M77 29 C90 28 91 54 77 55" fill="none" stroke="{shade(body, 0.2)}" stroke-width="2" stroke-linecap="round" opacity="0.7"/>',
        '<path d="M18 12 L78 12 L76 74 C76 78 66 80 48 80 C30 80 20 78 20 74 Z" fill="url(#cyl)"/>',
        '<path d="M25 18 L26.5 72" stroke="#ffffff" stroke-width="3" stroke-linecap="round" opacity="0.4"/>',
        f'<ellipse cx="48" cy="12" rx="30" ry="6" fill="{rim}"/>',
        '<ellipse cx="48" cy="12.6" rx="26.5" ry="4.4" fill="url(#inside)"/>',
        '<ellipse cx="48" cy="14" rx="24" ry="3.2" fill="url(#drink)"/>',
        mark,
    ]
    return svg(96, 80, "<defs>" + "".join(defs) + "</defs>\n" + "\n".join(parts))


BRACES = '<path d="M41 32 q-6 0 -6 6 v4 q0 3 -3 3 q3 0 3 3 v4 q0 6 6 6 M55 32 q6 0 6 6 v4 q0 3 3 3 q-3 0 -3 3 v4 q0 6 -6 6" fill="none" stroke="#4f8cff" stroke-width="3" stroke-linecap="round"/>'
CHEVRON = '<path d="M42 36 L34 46 L42 56 M54 36 L62 46 L54 56" fill="none" stroke="#ffffff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'
GOLDLINE = '<path d="M20 56 L77 56" stroke="#c9a86a" stroke-width="3"/><path d="M20 61 L77 61" stroke="#c9a86a" stroke-width="1" opacity="0.6"/>'
MOON = '<path d="M50 32 A14 14 0 1 0 50 60 A18 18 0 0 1 50 32 Z" fill="#f4c95d"/><circle cx="60" cy="38" r="2" fill="#f4c95d"/><circle cx="58" cy="54" r="1.4" fill="#f4c95d"/>'


# --- plants (220 x 210, bottom-center anchored) --------------------------------------------

def pot(color, lip, soil="#3b2a20"):
    defs = (lin("pot", [(0, shade(color, -0.3), None), (0.35, shade(color, 0.15), None), (0.7, color, None), (1, shade(color, -0.4), None)], x2=1, y2=0)
            + lin("lip", [(0, shade(lip, 0.15), None), (1, shade(lip, -0.2), None)]))
    body = (f'<ellipse cx="110" cy="208" rx="46" ry="3" fill="#000" opacity="0.35"/>'
            f'<path d="M66 142 L154 142 L144 206 C144 209 130 210 110 210 C90 210 76 209 76 206 Z" fill="url(#pot)"/>'
            f'<path d="M80 148 L86 202" stroke="#ffffff" stroke-width="3" stroke-linecap="round" opacity="0.25"/>'
            f'<rect x="60" y="132" width="100" height="14" rx="3" fill="url(#lip)"/>'
            f'<ellipse cx="110" cy="134" rx="46" ry="4" fill="{soil}"/>')
    return defs, body


def plant_svg(defs, leaves, pot_color, lip, soil="#3b2a20"):
    pdefs, pbody = pot(pot_color, lip, soil)
    return svg(220, 210, "<defs>" + defs + pdefs + "</defs>\n" + pbody + "\n" + leaves)


def fern():
    import math
    defs = lin("leaf", [(0, "#5fae6e", None), (1, "#1f5a35", None)], x2=0, y2=1)
    leaves = []
    for i in range(9):
        a = math.radians(-160 + i * 17.5)
        length = 92 + (i % 3) * 16
        bx, by = 110, 134
        tipx, tipy = bx + math.cos(a) * length, by + math.sin(a) * length
        cx, cy = bx + math.cos(a) * length * 0.5, by + math.sin(a) * length * 0.5 - 10
        nx, ny = -math.sin(a) * 15, math.cos(a) * 15
        leaves.append(f'<path d="M{bx} {by} Q{cx + nx:.1f} {cy + ny:.1f} {tipx:.1f} {tipy:.1f} Q{cx - nx:.1f} {cy - ny:.1f} {bx} {by} Z" fill="url(#leaf)"/>')
        leaves.append(f'<path d="M{bx} {by} Q{cx:.1f} {cy:.1f} {tipx:.1f} {tipy:.1f}" fill="none" stroke="#a8d8a0" stroke-width="1.2" opacity="0.6"/>')
    return plant_svg(defs, "".join(leaves), "#c2734f", "#d48562")


def snake():
    defs = lin("leaf", [(0, "#3f7a4c", None), (0.5, "#2e5e3a", None), (1, "#1c3d25", None)], x2=1, y2=0)
    leaves = []
    for x, hgt, lean in [(82, 116, -12), (98, 150, -5), (114, 166, 2), (130, 136, 8), (146, 104, 15)]:
        top = 136 - hgt
        leaves.append(f'<path d="M{x - 10} 136 Q{x - 13 + lean} {top + 44} {x + lean} {top} Q{x + 13 + lean} {top + 44} {x + 10} 136 Z" fill="url(#leaf)" stroke="#d8cf5a" stroke-width="2.4"/>')
        for band in range(3):
            yy = top + 30 + band * 26
            leaves.append(f'<path d="M{x - 6 + lean * 0.5:.1f} {yy} q6 -4 12 0" fill="none" stroke="#9fc28a" stroke-width="1.4" opacity="0.5"/>')
    return plant_svg(defs, "".join(leaves), "#ecebe6", "#dcdad2")


def cactus():
    defs = lin("cac", [(0, "#2f6b33", None), (0.45, "#5fa35c", None), (1, "#2a5e2e", None)], x2=1, y2=0)
    body = [
        '<path d="M96 62 h-14 q-10 0 -10 -10 v-22 q0 -7 7 -7 q7 0 7 7 v16 h10" fill="url(#cac)"/>',
        '<path d="M126 86 h14 q10 0 10 -10 v-20 q0 -7 -7 -7 q-7 0 -7 7 v14 h-10" fill="url(#cac)"/>',
        '<rect x="94" y="34" width="34" height="104" rx="17" fill="url(#cac)"/>',
        '<path d="M103 42 L103 134 M111 36 L111 136 M119 42 L119 134" stroke="#28572b" stroke-width="1.6" opacity="0.8"/>',
    ]
    for y in range(48, 132, 14):
        for x in (99, 107, 115, 123):
            body.append(f'<path d="M{x} {y} l-2.5 -2.5 M{x} {y} l2.5 -2.5" stroke="#f1f0d8" stroke-width="0.9" opacity="0.85"/>')
    body += ['<circle cx="111" cy="32" r="7" fill="#f472b6"/>', '<circle cx="111" cy="32" r="3" fill="#ffd1e6"/>']
    return plant_svg(defs, "".join(body), "#b8643f", "#cc7a55")


def succulent():
    import math
    defs = (lin("p0", [(0, "#b9e3cc", None), (1, "#5d9c7e", None)])
            + lin("p1", [(0, "#cdeedb", None), (1, "#78b597", None)])
            + lin("p2", [(0, "#e2f6ea", None), (1, "#93c9ad", None)]))
    petals = []
    for ring, (count, r, rx, ry) in enumerate([(10, 46, 16, 9), (8, 31, 13, 7.5), (6, 17, 10, 6)]):
        for i in range(count):
            a = 2 * math.pi * (i + ring * 0.5) / count
            x, y = 110 + math.cos(a) * r, 120 + math.sin(a) * r * 0.42
            petals.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx}" ry="{ry}" fill="url(#p{ring})" stroke="#4f8a6c" stroke-width="0.8" transform="rotate({math.degrees(a):.0f} {x:.1f} {y:.1f})"/>')
            tx, ty = 110 + math.cos(a) * (r + rx * 0.8), 120 + math.sin(a) * (r + rx * 0.8) * 0.42
            petals.append(f'<circle cx="{tx:.1f}" cy="{ty:.1f}" r="1.6" fill="#d77a8f" opacity="0.8"/>')
    return plant_svg(defs, "".join(petals), "#f4f4f2", "#e4e4e0", soil="#4a3a2e")


ITEMS = [
    # keyboards
    ("kb_basic", "keyboard", {"ko": "기본 키보드", "en": "Standard keyboard"}, keyboard("#1b1e25", "#343a46", "#2a2e38"), {}, [700, 90]),
    ("kb_white", "keyboard", {"ko": "화이트 키보드", "en": "White keyboard"}, keyboard("#d6d9df", "#eef0f3", "#f5f6f8", accent="#9fb4d8"), {}, [700, 90]),
    ("kb_rgb", "keyboard", {"ko": "기계식 RGB 키보드", "en": "Mechanical RGB keyboard"}, keyboard("#121318", "#2a2d36", "#2a2e38", rainbow=True, glow="#7c5cff"), {"owned": "keyboard_rgb"}, [700, 90]),
    ("kb_retro", "keyboard", {"ko": "레트로 키보드", "en": "Retro keyboard"}, keyboard("#c9bd9c", "#ddd3b7", "#ebe3cb", accent="#b5523b"), {"rank": 2}, [700, 90]),
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
    # Items rendered from the Blender models (tools/blender/) win over the flat SVG fallbacks.
    rendered = {}
    sizes_file = OUT / "render_sizes.json"
    if sizes_file.exists():
        rendered = json.loads(sizes_file.read_text(encoding="utf-8"))
    for item_id, slot, name, text, unlock, size in ITEMS:
        (OUT / f"{item_id}.svg").write_text(text, encoding="utf-8", newline="\n")
        file = f"res://content/desk/{item_id}.svg"
        if item_id in rendered and (OUT / f"{item_id}.png").exists():
            file, size = f"res://content/desk/{item_id}.png", rendered[item_id]
        catalog["items"].append({"id": item_id, "slot": slot, "name": name, "file": file, "size": size, "unlock": unlock})
    for item_id, slot, name, unlock in RENDER_ONLY:
        if item_id in rendered and (OUT / f"{item_id}.png").exists():
            catalog["items"].append({"id": item_id, "slot": slot, "name": name, "file": f"res://content/desk/{item_id}.png",
                                     "size": rendered[item_id], "unlock": unlock})
    (OUT / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(ITEMS)} desk items written to {OUT}")


if __name__ == "__main__":
    main()
