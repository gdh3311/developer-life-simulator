"""The view out of the office window: a 3D city rendered for day, dusk and night.

Run:  blender -b --factory-startup --python tools/blender/city_window.py -- <out_dir> <models_dir>
Writes city.glb and optional day/dusk/night fallback renders (940x1120).
Append --model-only to rebuild the runtime scene without the fallback images.
"""
import math
import os
import random
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else "content/room")
MODELS = os.path.abspath(argv[1] if len(argv) > 1 else "content/models/room")
os.makedirs(OUT, exist_ok=True)
os.makedirs(MODELS, exist_ok=True)

VARIANTS = {
    #        sky top      sky horizon   sun colour   sun energy  sun elev  window glow  lit bias  haze
    "day":   ("#4f86d0", "#cfe3f5", "#fff6e8", 4.5, 50, 0.0, -0.55, "#cfdcea"),
    "dusk":  ("#2d2f6b", "#f39a62", "#ff9a5a", 2.2, 6, 1.6, -0.15, "#e0957a"),
    "night": ("#04060d", "#2a2440", "#7f9cff", 0.25, 35, 2.6, -0.22, "#1b2038"),
}


def srgb(hexstr):
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.render.resolution_x, s.render.resolution_y = 940, 1120
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGB"
    s.view_settings.view_transform = "AgX"
    s.view_settings.look = "AgX - Base Contrast"
    s.eevee.taa_render_samples = 48
    return s


def facade_material(name, wall_hex, glass_hex, rng):
    """Walls with a grid of windows; Brick texture's two colours pick lit/unlit windows at random."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    n = nt.nodes
    L = nt.links
    p = n["Principled BSDF"]
    geo = n.new("ShaderNodeNewGeometry")
    sep = n.new("ShaderNodeSeparateXYZ")
    add = n.new("ShaderNodeMath")
    add.operation = "ADD"
    comb = n.new("ShaderNodeCombineXYZ")
    L.new(geo.outputs["Position"], sep.inputs[0])
    L.new(sep.outputs["X"], add.inputs[0])
    L.new(sep.outputs["Y"], add.inputs[1])
    L.new(add.outputs[0], comb.inputs["X"])
    L.new(sep.outputs["Z"], comb.inputs["Y"])
    brick = n.new("ShaderNodeTexBrick")
    brick.offset = 0.0
    brick.squash = 1.0
    brick.inputs["Scale"].default_value = 0.22 * rng.uniform(0.85, 1.25)
    brick.inputs["Mortar Size"].default_value = 0.35
    brick.inputs["Brick Width"].default_value = 1.0
    brick.inputs["Row Height"].default_value = 0.9
    brick.inputs["Color1"].default_value = (0, 0, 0, 1)   # unlit
    brick.inputs["Color2"].default_value = (1, 1, 1, 1)   # lit
    brick.inputs["Mortar"].default_value = (0, 0, 0, 1)
    L.new(comb.outputs[0], brick.inputs["Vector"])
    brick["lit_node"] = True
    # Window mask (1 = glass) and lit mask.
    inv = n.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    L.new(brick.outputs["Fac"], inv.inputs[1])
    mix = n.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = srgb(wall_hex)
    mix.inputs["B"].default_value = srgb(glass_hex)
    L.new(inv.outputs[0], mix.inputs["Factor"])
    L.new(mix.outputs["Result"], p.inputs["Base Color"])
    lit = n.new("ShaderNodeMath")
    lit.operation = "MULTIPLY"
    L.new(inv.outputs[0], lit.inputs[0])
    L.new(brick.outputs["Color"], lit.inputs[1])
    glow = n.new("ShaderNodeMath")
    glow.operation = "MULTIPLY"
    glow.name = "glow"
    L.new(lit.outputs[0], glow.inputs[0])
    glow.inputs[1].default_value = 1.0
    p.inputs["Emission Color"].default_value = srgb("#ffd59a" if rng.random() < 0.75 else "#cfe6ff")
    L.new(glow.outputs[0], p.inputs["Emission Strength"])
    rough = n.new("ShaderNodeMix")
    rough.data_type = "FLOAT"
    rough.inputs["A"].default_value = 0.8
    rough.inputs["B"].default_value = 0.15
    L.new(inv.outputs[0], rough.inputs["Factor"])
    L.new(rough.outputs["Result"], p.inputs["Roughness"])
    p.inputs["Metallic"].default_value = 0.1
    return m


def add_haze(m, near=60.0, far=900.0, amount=0.85):
    """Atmospheric perspective: blend the surface toward the haze colour with distance from the camera."""
    nt = m.node_tree
    n = nt.nodes
    out = n["Material Output"]
    surf = out.inputs["Surface"].links[0].from_socket
    cam = n.new("ShaderNodeCameraData")
    rng = n.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = near
    rng.inputs["From Max"].default_value = far
    rng.inputs["To Max"].default_value = amount
    nt.links.new(cam.outputs["View Distance"], rng.inputs["Value"])
    em = n.new("ShaderNodeEmission")
    em.name = "haze"
    mix = n.new("ShaderNodeMixShader")
    nt.links.new(rng.outputs["Result"], mix.inputs["Fac"])
    nt.links.new(surf, mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])


def box(name, w, d, h, x, y, z, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + h / 2))
    o = bpy.context.object
    o.name = name
    o.scale = (w, d, h)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    return o


def emissive(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = srgb("#111111")
    p.inputs["Emission Color"].default_value = srgb(color)
    p.inputs["Emission Strength"].default_value = strength
    return m


def build_city(rng):
    walls = [("#59606e", "#162338"), ("#8a8f99", "#1b2c45"), ("#454c59", "#121e30"), ("#a3a6ad", "#22385a"),
             ("#6e6258", "#172539"), ("#c1c3c8", "#25405f")]
    mats = [facade_material("facade%d" % i, w, g, rng) for i, (w, g) in enumerate(walls) for _ in range(2)]
    for m in mats:
        add_haze(m)
    tops = []
    terraces = []
    objs = []
    # Rows of blocks receding from the window; taller toward the middle distance.
    for row in range(9):
        y = 70 + row * 55 + rng.uniform(-8, 8)
        x = -260 + rng.uniform(0, 20)
        while x < 260:
            w = rng.uniform(14, 34)
            d = rng.uniform(14, 30)
            h = rng.uniform(18, 60) + (55 if 2 <= row <= 6 and rng.random() < 0.35 else 0) + (70 if row in (3, 4) and rng.random() < 0.12 else 0)
            m = rng.choice(mats)
            objs.append(box("b", w, d, h, x + w / 2, y, 0, m))
            if h > 70 and rng.random() < 0.6:  # setback tower
                objs.append(box("t", w * 0.6, d * 0.6, h * 0.3, x + w / 2, y, h, m))
                h *= 1.3
            tops.append((x + w / 2, y, h))
            if row in (0, 1, 3, 4) and len(tops) % 3 == 0:
                terraces.append((x + w / 2, y, h, w, d))
            x += w + rng.uniform(4, 12)
    ground = box("ground", 900, 900, 0.5, 0, 300, -0.5, emissive("ground", "#0b0d12", 0.0))
    # Streets: thin emissive strips between rows (warm streetlights at night).
    street = emissive("street", "#ffb35c", 1.0)
    for row in range(1, 9):
        objs.append(box("street", 520, 1.2, 0.3, 0, 70 + row * 55 - 27, 0, street))
    # Aircraft warning lights on the tallest roofs.
    warn = emissive("warn", "#ff3b3b", 30.0)
    for x, y, h in sorted(tops, key=lambda t: -t[2])[:6]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.9, location=(x, y, h + 1.5))
        bpy.context.object.data.materials.append(warn)
    # Distant hills.
    hill = emissive("hill", "#000000", 0.0)
    add_haze(hill, 300.0, 1100.0, 0.7)
    for i in range(7):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=(-360 + i * 120 + rng.uniform(-30, 30), 760, -20))
        o = bpy.context.object
        o.scale = (rng.uniform(90, 150), 40, rng.uniform(60, 110))
        o.data.materials.append(hill)
    roof = emissive("roof", "#71808f", 0)
    aluminum = emissive("equipment", "#b1b4af", 0)
    for x, y, h, w, d in terraces:
        box("setback roof", w * .87, d * .88, .42, x, y, h, roof)
        box("plant room", w * .25, d * .30, 2.6, x + w * .18, y + d * .16, h + .42, aluminum)
        box("hvac plinth", w * .21, d * .30, 1.05, x - w * .18, y - d * .09, h + .42, roof)
        for offset in (-.075, .075):
            box("vent", w * .055, d * .23, .35, x - w * .18 + w * offset, y - d * .09, h + 1.47, aluminum)
    for x, y, h in sorted(tops, key=lambda t: -t[2])[:4]:
        box("antenna mast", .53, .53, 12.0, x + 2, y, h, aluminum)
        box("antenna array", 3.6, .28, .28, x + 2, y, h + 9, aluminum)
    trees = emissive("trees", "#294f54", 0)
    for x in range(-130, 135, 11):
        y = 45 + rng.uniform(-2.0, 2.0)
        height = rng.uniform(3.8, 6.0)
        box("trunk", .55, .55, height, x, y, 0, roof)
        for dx, spread in ((-.72, 1.7), (.44, 1.95)):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=spread, location=(x + dx, y, height))
            canopy = bpy.context.object
            canopy.scale.z = 1.32
            canopy.data.materials.append(trees)
    return mats, street, hill


def apply_variant(s, name, mats, street, hill):
    top, horizon, sun_col, sun_energy, sun_el, glow, bias, haze = VARIANTS[name]
    world = bpy.data.worlds.get("sky") or bpy.data.worlds.new("sky")
    world.use_nodes = True
    nt = world.node_tree
    for node in list(nt.nodes):
        nt.nodes.remove(node)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    bg = nt.nodes.new("ShaderNodeBackground")
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(tc.outputs["Window"], sep.inputs[0])
    nt.links.new(sep.outputs["Y"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[0].color = srgb(horizon)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = srgb(top)
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0 if name != "night" else 0.6
    nt.links.new(bg.outputs[0], out.inputs["Surface"])
    s.world = world
    for m in list(mats) + [hill, street]:
        hz = m.node_tree.nodes.get("haze")
        if hz is not None:
            hz.inputs["Color"].default_value = srgb(haze)
            hz.inputs["Strength"].default_value = {"day": 1.0, "dusk": 0.9, "night": 0.35}[name]
    for m in mats:
        nodes = m.node_tree.nodes
        nodes["glow"].inputs[1].default_value = glow
        for node in nodes:
            if node.bl_idname == "ShaderNodeTexBrick":
                node.inputs["Bias"].default_value = bias
    street.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = {"day": 0.0, "dusk": 1.5, "night": 6.0}[name]
    hp = hill.node_tree.nodes["Principled BSDF"]
    hp.inputs["Base Color"].default_value = srgb({"day": "#7d95ad", "dusk": "#5a4a6e", "night": "#0a0d18"}[name])
    sun = bpy.data.objects.get("sun")
    if sun is None:
        bpy.ops.object.light_add(type="SUN")
        sun = bpy.context.object
        sun.name = "sun"
    sun.data.energy = sun_energy
    sun.data.color = srgb(sun_col)[:3]
    sun.data.angle = math.radians(2.0)
    sun.rotation_euler = (math.radians(90 - sun_el), 0, math.radians(-150 if name == "dusk" else -120))


def main():
    rng = random.Random(17)
    s = reset()
    mats, street, hill = build_city(rng)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(MODELS, "city.glb"), export_format="GLB", use_selection=True)
    if "--model-only" in argv:
        return
    bpy.ops.object.camera_add(location=(0, -40, 62), rotation=(math.radians(84), 0, 0))
    cam = bpy.context.object
    cam.rotation_euler = (math.radians(86), 0, 0)
    cam.data.lens = 28
    cam.data.clip_end = 3000
    s.camera = cam
    for name in VARIANTS:
        apply_variant(s, name, mats, street, hill)
        s.render.filepath = os.path.join(OUT, "window_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDERED", name)
    print("ALL_DONE")


main()
