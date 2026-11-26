"""Builds the desk item 3D models in Blender, exports each as .glb and renders it to a transparent PNG.

Run:  blender -b --factory-startup --python tools/blender/desk_models.py -- <models_dir> <renders_dir> [ids...]
Then: python tools/blender/finish_desk_assets.py   (crops renders into content/desk and updates the catalog)

Everything is built from code so the assets are reproducible and editable: change a dimension or a
material here and re-run. Units are metres; items sit on the XY plane with +Y away from the viewer.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
MODELS = os.path.abspath(argv[0] if argv else "content/models/desk")
RENDERS = os.path.abspath(argv[1] if len(argv) > 1 else "build/desk_renders")
ONLY = set(argv[2:])
os.makedirs(MODELS, exist_ok=True)
os.makedirs(RENDERS, exist_ok=True)


# --- scene helpers ----------------------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.render.film_transparent = True
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    s.view_settings.view_transform = "AgX"
    s.view_settings.look = "AgX - Medium High Contrast"
    s.eevee.taa_render_samples = 64
    world = bpy.data.worlds.new("studio")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.12, 0.13, 0.16, 1)
    bg.inputs["Strength"].default_value = 0.6
    s.world = world
    return s


def mat(name, color, rough=0.5, metal=0.0, emit=None, emit_strength=0.0, coat=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*srgb(color), 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if coat:
        p.inputs["Coat Weight"].default_value = coat
    if emit is not None:
        p.inputs["Emission Color"].default_value = (*srgb(emit), 1)
        p.inputs["Emission Strength"].default_value = emit_strength
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
    return m


def srgb(hexstr):
    """'#rrggbb' -> linear RGB tuple."""
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def assign(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def bevel(obj, width, segments=3):
    b = obj.modifiers.new("bevel", "BEVEL")
    b.width = width
    b.segments = segments
    b.limit_method = "ANGLE"
    return obj


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def cube(name, size, loc, material=None, bev=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bev:
        bevel(o, bev)
    if material:
        assign(o, material)
    return o


def cylinder(name, r, depth, loc, material=None, verts=48, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    smooth(o)
    if material:
        assign(o, material)
    return o


def keycap(name, w, d, h, loc, material):
    """A keycap: bevelled box whose top is narrower than its base (sculpted look)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (w, d, h)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for v in o.data.vertices:
        if v.co.z > 0:
            v.co.x *= 0.78
            v.co.y *= 0.74
    bevel(o, min(w, d) * 0.12, 2)
    assign(o, material)
    return o


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    return o


def lights(s, warm=True, scale=1.0):
    """Window on the player's left: a large soft key from the upper left, a dim fill and a rim."""
    def area(name, loc, energy, size, color):
        bpy.ops.object.light_add(type="AREA", location=loc)
        L = bpy.context.object
        L.name = name
        L.data.energy = energy * scale
        L.data.size = size
        L.data.color = color
        direction = Vector((0, 0, 0)) - L.location
        L.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        return L
    area("key", (-0.9, -0.6, 1.0), 120, 1.2, (1.0, 0.96, 0.9) if warm else (0.95, 0.97, 1.0))
    area("fill", (0.9, -0.8, 0.35), 25, 1.0, (0.75, 0.82, 1.0))
    area("rim", (0.2, 0.9, 0.7), 45, 0.8, (1.0, 1.0, 1.0))


def camera(s, elevation_deg, res, lens=70):
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cam.data.lens = lens
    s.camera = cam
    s.render.resolution_x, s.render.resolution_y = res
    s.render.resolution_percentage = 100
    el = math.radians(elevation_deg)
    cam.rotation_euler = (math.pi / 2 - el, 0, 0)
    coords = []
    dg = bpy.context.evaluated_depsgraph_get()
    for o in s.objects:
        if o.type == "MESH":
            ev = o.evaluated_get(dg)
            coords += [c for v in ev.data.vertices for c in (ev.matrix_world @ v.co)]
    loc, _scale = cam.camera_fit_coords(dg, coords)
    forward = cam.matrix_world.to_quaternion() @ Vector((0, 0, -1))
    cam.location = Vector(loc) - forward * 0.04  # a little breathing room; the crop trims it
    return cam


def finish(s, item_id, elevation, res, lens=70, light=1.0):
    """Export the item as .glb (models only, no lights/camera) and render it."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in s.objects:
        if o.type == "MESH":
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(MODELS, item_id + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
    lights(s, scale=light)
    camera(s, elevation, res, lens)
    s.render.filepath = os.path.join(RENDERS, item_id + ".png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", item_id)


# --- keyboards ----------------------------------------------------------------------------------------

KEY_ROWS = [  # key widths in units (1u = 19 mm)
    [1] * 13 + [2],
    [1.5] + [1] * 12 + [1.5],
    [1.75] + [1] * 11 + [2.25],
    [2.25] + [1] * 10 + [2.75],
    [1.25, 1.25, 1.25, 6.25, 1.25, 1.25, 1.25, 1.25],
]


def lettering(text, size, location, material):
    font = bpy.data.curves.new("legend", "FONT")
    font.body = text
    font.align_x = "CENTER"
    font.align_y = "CENTER"
    font.size = size
    obj = bpy.data.objects.new("legend " + text, font)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    font.materials.append(material)
    return obj


def keyboard(item_id, case_col, key_col, mod_col, rgb=False, retro=False, legend=None):
    s = reset()
    u = 0.019
    width = 15 * u + 0.02
    depth = 5 * u + 0.03
    case = cube("case", (width, depth, 0.022 if not retro else 0.03), (0, 0, 0.011 if not retro else 0.015),
                mat("case", case_col, 0.38 if legend else 0.55 if not retro else 0.7, 0.42 if legend else 0.0), bev=0.004)
    # Front-to-back tilt like real keyboards.
    parts = [case]
    key_mat = mat("keys", key_col, 0.38 if not retro else 0.6, coat=0.2 if not retro else 0.0)
    mod_mat = mat("mods", mod_col, 0.45 if not retro else 0.65)
    hue_mats = {}
    legends = ["ESC 1 2 3 4 5 6 7 8 9 0 - + DEL", "TAB Q W E R T Y U I O P [ ] RET",
               "CAP A S D F G H J K L ; ' ENTER", "SHIFT Z X C V B N M , . / SHIFT",
               "CTRL WIN ALT SPACE ALT FN MENU CTRL"]
    ink = mat("legend ink", legend, 0.78) if legend else None
    top = 0.022 if not retro else 0.03
    y0 = depth / 2 - 0.015 - u / 2
    for r, row in enumerate(KEY_ROWS):
        x = -15 * u / 2
        for i, wu in enumerate(row):
            w = wu * u
            cx = x + w / 2
            is_mod = wu > 1.2 or (r == 0 and i == 0)
            material = mod_mat if is_mod else key_mat
            if rgb:
                hue = ((cx + width / 2) / width + r * 0.07) % 1.0
                k = round(hue * 12) % 12
                if k not in hue_mats:
                    import colorsys
                    rr, gg, bb = colorsys.hsv_to_rgb(k / 12, 0.85, 1.0)
                    hx = "#%02x%02x%02x" % (int(rr * 255), int(gg * 255), int(bb * 255))
                    hue_mats[k] = mat("rgb%d" % k, "#20232b", 0.48, emit=hx, emit_strength=0.32)
                material = hue_mats[k]
            h = 0.011 if not retro else 0.016
            cap = keycap("k%d_%d" % (r, i), w - 0.0022, u - 0.0022, h, (cx, y0 - r * u, top + h / 2 + 0.001), material)
            parts.append(cap)
            if ink is not None:
                label = legends[r].split()[i]
                if label != "SPACE":
                    parts.append(lettering(label, 0.0045 if len(label) == 1 else 0.0032,
                                           (cx, y0 - r * u, top + h + 0.00115), ink))
            x += w
    if rgb:
        under = cube("glow", (width - 0.012, depth - 0.012, 0.002), (0, 0, top + 0.0005), mat("under", "#111111", 0.5, emit="#7c3aed", emit_strength=0.62))
        parts.append(under)
    if retro:
        badge = cube("badge", (0.05, 0.008, 0.002), (width / 2 - 0.05, -depth / 2 + 0.008, 0.031), mat("badge", "#7a5c3a", 0.4, 0.6))
        parts.append(badge)
    kb = join(parts, item_id)
    kb.rotation_euler = (math.radians(4), 0, 0)
    finish(s, item_id, 22, (2400, 700))


# --- mice -----------------------------------------------------------------------------------------------

def mouse(item_id, shell_col, button_col, accent=None):
    s = reset()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1, location=(0, 0, 0))
    body = bpy.context.object
    body.name = "shell"
    body.scale = (0.031, 0.06, 0.017)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for v in body.data.vertices:
        if v.co.z < 0:
            v.co.z *= 0.12                      # flat base
        if v.co.y > 0:
            v.co.x *= 1.0 - 0.18 * (v.co.y / 0.06)  # narrower nose, palm-shaped from above
        v.co.z += 0.004 * max(0.0, -v.co.y / 0.06)  # hump toward the palm
    body.location.z = 0.003
    smooth(body)
    shell = mat("shell", shell_col, 0.32)
    shell.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.35  # dark plastic, not a grey sheen
    assign(body, shell)
    parts = [body]
    # Buttons: a shallow groove in front, scroll wheel sunk into it.
    groove = cube("groove", (0.0009, 0.03, 0.003), (0, 0.036, 0.0142), mat("seam", "#08090b", 0.9))
    wheel = cylinder("wheel", 0.0045, 0.005, (0, 0.03, 0.0126), mat("wheel", button_col, 0.7), verts=32)
    wheel.rotation_euler = (0, math.radians(90), 0)
    parts += [groove, wheel]
    if accent:
        bpy.ops.mesh.primitive_torus_add(major_radius=1, minor_radius=0.05, major_segments=64, minor_segments=8, location=(0, 0, 0.0035))
        ring = bpy.context.object
        ring.scale = (0.0292, 0.0575, 1.0)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        for v in ring.data.vertices:
            v.co.z *= 0.03
        assign(ring, mat("accent", "#111111", 0.4, emit=accent, emit_strength=4.0))
        logo = cylinder("logo", 0.006, 0.0008, (0, -0.022, 0.0194), mat("logo", "#111111", 0.4, emit=accent, emit_strength=2.5), verts=24)
        parts += [ring, logo]
    m = join(parts, item_id)
    m.rotation_euler = (0, 0, math.radians(-8))
    finish(s, item_id, 26, (1400, 1000))


# --- mugs -------------------------------------------------------------------------------------------------

def mug(item_id, body_col, inner_col="#f4efe6", text=None, text_col="#4f8cff", moon=False, rough=0.25):
    s = reset()
    outer = cylinder("outer", 0.041, 0.095, (0, 0, 0.0475), verts=64)
    inner = cylinder("inner", 0.0365, 0.095, (0, 0, 0.055), verts=64)
    boolean = outer.modifiers.new("hollow", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.object = inner
    bpy.context.view_layer.objects.active = outer
    bpy.ops.object.modifier_apply(modifier="hollow")
    bpy.data.objects.remove(inner)
    bevel(outer, 0.0012, 2)
    body = mat("body", body_col, rough, coat=0.6)
    assign(outer, body)
    outer.data.materials.append(mat("inside", inner_col, 0.3))
    for poly in outer.data.polygons:  # inside faces get the glaze colour of the inside
        c = poly.center
        if math.hypot(c.x, c.y) < 0.038 and c.z > 0.008:
            poly.material_index = 1
    coffee = cylinder("coffee", 0.0362, 0.002, (0, 0, 0.078), mat("coffee", "#2a160c", 0.12, coat=1.0), verts=48)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.023, minor_radius=0.0055, location=(0.05, 0, 0.05), rotation=(math.radians(90), 0, 0))
    handle = bpy.context.object
    for v in handle.data.vertices:  # keep the outer half only
        if v.co.x < -0.006:
            v.co.x = -0.006
    smooth(handle)
    assign(handle, body)
    parts = [outer, coffee, handle]
    if text:
        bpy.ops.object.text_add(location=(0, -0.0418, 0.045), rotation=(math.radians(90), 0, 0))
        t = bpy.context.object
        t.data.body = text
        t.data.size = 0.022 if len(text) <= 3 else 0.012
        t.data.extrude = 0.0004
        t.data.align_x = "CENTER"
        t.data.align_y = "CENTER"
        t.data.materials.append(mat("print", text_col, 0.35))
        parts.append(t)
    if moon:
        bpy.ops.mesh.primitive_circle_add(vertices=48, radius=0.014, fill_type="NGON", location=(0, -0.0418, 0.05), rotation=(math.radians(90), 0, 0))
        disc = bpy.context.object
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.012, depth=0.01, location=(0.006, -0.0418, 0.054), rotation=(math.radians(90), 0, 0))
        cut = bpy.context.object  # a solid cutter: the boolean bites a crescent out of the disc
        boolean = disc.modifiers.new("crescent", "BOOLEAN")
        boolean.operation = "DIFFERENCE"
        boolean.object = cut
        solid = disc.modifiers.new("thick", "SOLIDIFY")
        solid.thickness = 0.0006
        bpy.context.view_layer.objects.active = disc
        bpy.ops.object.modifier_apply(modifier="thick")
        bpy.ops.object.modifier_apply(modifier="crescent")
        bpy.data.objects.remove(cut)
        assign(disc, mat("moon", "#f4c95d", 0.3, emit="#f4c95d", emit_strength=0.4))
        parts.append(disc)
    m = join(parts, item_id)
    m.rotation_euler = (0, 0, math.radians(-28))
    finish(s, item_id, 14, (1000, 1000), lens=85)


# --- plants -------------------------------------------------------------------------------------------------

def pot(col="#c2734f", r=0.055, h=0.075, rim=True):
    p = cylinder("pot", r, h, (0, 0, h / 2), mat("pot", col, 0.75), verts=64, r2=r * 1.18)
    parts = [p]
    if rim:
        parts.append(cylinder("rim", r * 1.24, 0.014, (0, 0, h - 0.005), mat("potrim", col, 0.7), verts=64))
    parts.append(cylinder("soil", r * 1.12, 0.004, (0, 0, h - 0.006), mat("soil", "#3b2a1e", 0.95), verts=48))
    return parts, h


def leaf(name, length, width, loc, yaw, pitch, material, bend=0.35, roll=0.0, thickness=0.0015):
    """A tapered, curved leaf blade built from a subdivided strip."""
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=2, y_subdivisions=14, size=1, location=(0, 0, 0))
    o = bpy.context.object
    o.name = name
    for v in o.data.vertices:
        t = v.co.y + 0.5            # 0 at base, 1 at tip
        taper = math.sin(math.pi * min(1.0, t * 1.05)) ** 0.7
        v.co.x *= width * max(0.05, taper)
        v.co.y = t * length
        v.co.z = -bend * (t * length) ** 2 / max(length, 1e-4)
    o.rotation_euler = (math.radians(pitch), math.radians(roll), math.radians(yaw))
    o.location = loc
    solid = o.modifiers.new("thick", "SOLIDIFY")
    solid.thickness = thickness
    smooth(o)
    assign(o, material)
    return o


def plant_fern():
    s = reset()
    parts, h = pot()
    greens = [mat("g1", "#2f6b45", 0.55, coat=0.2), mat("g2", "#3d8456", 0.5, coat=0.2), mat("g3", "#25583a", 0.6)]
    for i in range(22):
        yaw = i * 137.5
        pitch = -22 - (i % 4) * 9           # fronds rise at 40-68 degrees, then arch over
        parts.append(leaf("f%d" % i, 0.15 + (i % 5) * 0.022, 0.03, (0, 0, h), yaw, 90 + pitch, greens[i % 3], bend=0.42))
    m = join(parts, "plant_fern")
    finish(s, "plant_fern", 12, (1100, 1100), lens=80)


def plant_snake():
    s = reset()
    parts, h = pot("#e8e2d6", 0.05, 0.08)
    edge = [mat("s1", "#2e5a36", 0.45, coat=0.3), mat("s2", "#3f7a3f", 0.45, coat=0.3)]
    for i in range(9):
        yaw = i * 40 + (i % 2) * 12
        tilt = 82 - (i % 3) * 6
        parts.append(leaf("s%d" % i, 0.17 + (i % 4) * 0.035, 0.03, (math.cos(math.radians(yaw)) * 0.012, math.sin(math.radians(yaw)) * 0.012, h),
                          yaw, tilt, edge[i % 2], bend=0.05, thickness=0.003))
    join(parts, "plant_snake")
    finish(s, "plant_snake", 12, (1100, 1100), lens=80)


def plant_cactus():
    s = reset()
    parts, h = pot("#b8613f", 0.045, 0.07)
    green = mat("cactus", "#3f7d4a", 0.6, coat=0.15)

    def column(r, height, loc, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r, depth=height, location=loc, rotation=rot)
        c = bpy.context.object
        for v in c.data.vertices:  # ribs
            ang = math.atan2(v.co.y, v.co.x)
            k = 1.0 + 0.09 * math.cos(ang * 12)
            v.co.x *= k
            v.co.y *= k
        sub = c.modifiers.new("sub", "SUBSURF")
        sub.levels = 2
        sub.render_levels = 2
        smooth(c)
        assign(c, green)
        return c
    parts.append(column(0.026, 0.16, (0, 0, h + 0.07)))
    parts.append(column(0.015, 0.06, (0.034, 0, h + 0.085)))
    parts.append(column(0.014, 0.05, (-0.03, 0.004, h + 0.06)))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.01, location=(0, 0, h + 0.155))
    flower = bpy.context.object
    flower.scale = (1, 1, 0.5)
    assign(flower, mat("flower", "#ff6b8a", 0.4))
    parts.append(flower)
    join(parts, "plant_cactus")
    finish(s, "plant_cactus", 12, (1000, 1100), lens=80)


def plant_succulent():
    s = reset()
    parts, h = pot("#f1ede4", 0.04, 0.038, rim=False)
    shades = [mat("u1", "#7fae8a", 0.45, coat=0.3), mat("u2", "#94bfa0", 0.4, coat=0.3), mat("u3", "#6e9c86", 0.5)]
    for ring, (count, radius, size, lift) in enumerate([(10, 0.046, 0.024, 0.008), (8, 0.03, 0.02, 0.018), (6, 0.015, 0.016, 0.026), (3, 0.004, 0.012, 0.032)]):
        for i in range(count):
            a = math.radians(i * 360 / count + ring * 20)
            bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=(math.cos(a) * radius, math.sin(a) * radius, h + lift))
            p = bpy.context.object
            p.scale = (size * 1.6, size * 0.75, size * 0.45)
            p.rotation_euler = (0, math.radians(-25 - ring * 10), a)
            smooth(p)
            assign(p, shades[(i + ring) % 3])
            parts.append(p)
    join(parts, "plant_succulent")
    finish(s, "plant_succulent", 16, (1100, 900), lens=80)


# --- decor: collectible desk toys ---------------------------------------------------------------------------

def sphere(name, r, loc, material, scale=(1, 1, 1), seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(8, seg // 2), radius=r, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    smooth(o)
    assign(o, material)
    return o


def decor_finish(s, item_id, parts, yaw=-20, elevation=14, light=1.0):
    m = join(parts, item_id)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)  # keep the parts' own rotations
    m.rotation_euler = (0, 0, math.radians(yaw))
    finish(s, item_id, elevation, (1000, 1000), lens=85, light=light)


def decor_pen_cup():
    s = reset()
    metal = mat("mesh", "#2b2f38", 0.35, 0.8)
    parts = [cylinder("cup", 0.034, 0.09, (0, 0, 0.045), metal, verts=48)]
    parts.append(cylinder("lip", 0.0355, 0.004, (0, 0, 0.089), mat("lip", "#3a3f4a", 0.3, 0.9), verts=48))
    pens = [("#ef4444", -0.012, -0.006, -12, 6), ("#3b82f6", 0.01, 0.004, 9, -4), ("#f59e0b", 0.0, 0.012, 3, 10),
            ("#10b981", -0.004, -0.014, -5, -8), ("#e5e7eb", 0.015, -0.01, 14, 2)]
    for i, (col, dx, dy, tx, ty) in enumerate(pens):
        p = cylinder("pen%d" % i, 0.0042, 0.15, (dx, dy, 0.1), mat("pen%d" % i, col, 0.35, coat=0.3), verts=16)
        p.rotation_euler = (math.radians(ty), math.radians(tx), 0)
        parts.append(p)
    decor_finish(s, "decor_pen_cup", parts)


def decor_clock():
    s = reset()
    red = mat("red", "#e8574e", 0.3, coat=0.6)
    gold = mat("gold", "#e6b422", 0.25, 1.0)
    body = cylinder("body", 0.04, 0.026, (0, 0, 0.052), red, verts=48)
    body.rotation_euler = (math.radians(90), 0, 0)
    face = cylinder("face", 0.034, 0.002, (0, -0.0132, 0.052), mat("face", "#f8f5ee", 0.4), verts=48)
    face.rotation_euler = (math.radians(90), 0, 0)
    hands = [cube("h1", (0.0025, 0.001, 0.024), (0.0, -0.0148, 0.062), mat("hand", "#111111", 0.5)),
             cube("h2", (0.018, 0.001, 0.0025), (0.008, -0.0148, 0.052), mat("hand2", "#111111", 0.5))]
    bells = [sphere("b1", 0.015, (-0.026, 0, 0.088), gold, (1, 1, 0.7)), sphere("b2", 0.015, (0.026, 0, 0.088), gold, (1, 1, 0.7))]
    legs = [cylinder("l1", 0.004, 0.016, (-0.024, 0, 0.008), mat("leg", "#2b2b2b", 0.4, 0.6), verts=12),
            cylinder("l2", 0.004, 0.016, (0.024, 0, 0.008), mat("leg2", "#2b2b2b", 0.4, 0.6), verts=12)]
    decor_finish(s, "decor_clock", [body, face] + hands + bells + legs, yaw=-12)


def decor_duck():
    s = reset()
    yellow = mat("duck", "#ffb300", 0.32, coat=0.4)
    orange = mat("beak", "#ff8c1a", 0.3, coat=0.4)
    black = mat("eye", "#111111", 0.2, coat=1.0)
    parts = [sphere("body", 0.045, (0, 0, 0.035), yellow, (1.25, 1.0, 0.78)),
             sphere("tail", 0.018, (0.05, 0, 0.055), yellow, (1.0, 0.8, 1.2)),
             sphere("head", 0.029, (-0.032, -0.002, 0.086), yellow),
             sphere("beak", 0.014, (-0.062, -0.002, 0.081), orange, (1.6, 1.0, 0.42)),
             sphere("e1", 0.0045, (-0.05, -0.02, 0.095), black), sphere("e2", 0.0045, (-0.05, 0.016, 0.095), black)]
    decor_finish(s, "decor_duck", parts, yaw=-35, light=0.55)


def decor_robot():
    s = reset()
    silver = mat("silver", "#c9d2dc", 0.3, 0.7)
    dark = mat("dark", "#2a2e36", 0.5, 0.3)
    cyan = mat("eyes", "#111111", 0.3, emit="#22d3ee", emit_strength=6.0)
    parts = [cube("torso", (0.05, 0.035, 0.05), (0, 0, 0.05), silver, bev=0.004),
             cube("head", (0.044, 0.034, 0.032), (0, 0, 0.096), silver, bev=0.006),
             sphere("e1", 0.0055, (-0.011, -0.0168, 0.098), cyan), sphere("e2", 0.0055, (0.011, -0.0168, 0.098), cyan),
             cube("mouth", (0.016, 0.001, 0.003), (0, -0.0172, 0.087), dark),
             cylinder("ant", 0.0015, 0.02, (0, 0, 0.122), dark, verts=8),
             sphere("ball", 0.005, (0, 0, 0.134), mat("red", "#111111", 0.3, emit="#ff3b3b", emit_strength=5.0)),
             cylinder("chest", 0.007, 0.002, (0, -0.0178, 0.055), mat("chest", "#111111", 0.3, emit="#3ddc84", emit_strength=4.0), verts=24),
             cube("leg1", (0.016, 0.02, 0.026), (-0.013, 0, 0.013), dark, bev=0.002),
             cube("leg2", (0.016, 0.02, 0.026), (0.013, 0, 0.013), dark, bev=0.002)]
    parts[-3].rotation_euler = (math.radians(90), 0, 0)
    for side in (-1, 1):
        a = cylinder("arm", 0.0065, 0.042, (side * 0.032, 0, 0.052), silver, verts=16)
        a.rotation_euler = (0, math.radians(side * 12), 0)
        parts.append(a)
    decor_finish(s, "decor_robot", parts, yaw=-18)


def decor_lucky_cat():
    s = reset()
    white = mat("white", "#f5f1ea", 0.3, coat=0.7)
    red = mat("collar", "#d62828", 0.35, coat=0.4)
    gold = mat("gold", "#e6b422", 0.2, 1.0)
    black = mat("ink", "#141414", 0.3)
    parts = [sphere("body", 0.04, (0, 0, 0.045), white, (1.0, 0.85, 1.1)),
             sphere("head", 0.033, (0, -0.004, 0.106), white, (1.15, 1.0, 0.95))]
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.011, radius2=0.0, depth=0.022, location=(side * 0.022, -0.002, 0.137), rotation=(0, math.radians(side * 18), 0))
        ear = bpy.context.object
        smooth(ear)
        assign(ear, white)
        parts.append(ear)
        parts.append(sphere("eye", 0.0042, (side * 0.012, -0.0325, 0.11), black, (1.0, 0.5, 0.45)))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.031, minor_radius=0.0042, location=(0, 0, 0.079))
    collar = bpy.context.object
    smooth(collar)
    assign(collar, red)
    parts += [collar, sphere("bell", 0.007, (0, -0.031, 0.073), gold),
              sphere("paw", 0.012, (0.036, -0.012, 0.112), white, (0.85, 0.85, 1.3)),
              sphere("arm", 0.013, (0.034, -0.01, 0.085), white, (0.8, 0.8, 1.4))]
    coin = cylinder("coin", 0.018, 0.003, (0, -0.035, 0.042), gold, verts=32)
    coin.rotation_euler = (math.radians(90), 0, 0)
    parts.append(coin)
    decor_finish(s, "decor_lucky_cat", parts, yaw=-10)


def decor_trophy():
    s = reset()
    gold = mat("gold", "#e6b422", 0.18, 1.0)
    parts = [cube("base", (0.05, 0.05, 0.026), (0, 0, 0.013), mat("wood", "#1c1a18", 0.4), bev=0.003),
             cube("plate", (0.03, 0.001, 0.011), (0, -0.0256, 0.013), gold),
             cylinder("stem", 0.006, 0.032, (0, 0, 0.042), gold, verts=24),
             cylinder("knob", 0.011, 0.008, (0, 0, 0.058), gold, verts=24),
             cylinder("cup", 0.012, 0.05, (0, 0, 0.085), gold, verts=48, r2=0.032)]
    bpy.ops.mesh.primitive_torus_add(major_radius=0.032, minor_radius=0.0025, location=(0, 0, 0.11))
    rim = bpy.context.object
    smooth(rim)
    assign(rim, gold)
    parts.append(rim)
    for side in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.013, minor_radius=0.0028, location=(side * 0.034, 0, 0.09), rotation=(math.radians(90), 0, 0))
        h = bpy.context.object
        smooth(h)
        assign(h, gold)
        parts.append(h)
    decor_finish(s, "decor_trophy", parts, yaw=-8)


def decor_controller():
    s = reset()
    body_m = mat("pad", "#2a2d34", 0.45, coat=0.3)
    parts = [cube("body", (0.1, 0.045, 0.022), (0, 0.004, 0.02), body_m, bev=0.01),
             sphere("g1", 0.019, (-0.04, -0.018, 0.016), body_m, (0.95, 1.25, 0.6)),
             sphere("g2", 0.019, (0.04, -0.018, 0.016), body_m, (0.95, 1.25, 0.6)),
             cube("d1", (0.018, 0.006, 0.004), (-0.03, 0.004, 0.033), mat("dpad", "#111214", 0.5)),
             cube("d2", (0.006, 0.018, 0.004), (-0.03, 0.004, 0.033), mat("dpad2", "#111214", 0.5))]
    for (dx, dy, col) in [(0.03, 0.012, "#3ddc84"), (0.03, -0.004, "#ef4444"), (0.022, 0.004, "#3b82f6"), (0.038, 0.004, "#f59e0b")]:
        parts.append(sphere("btn", 0.0042, (dx, dy, 0.033), mat("b" + col, col, 0.3, coat=0.8)))
    for dx in (-0.012, 0.012):
        parts.append(cylinder("stick", 0.0065, 0.009, (dx, -0.012, 0.034), mat("stick", "#16171a", 0.6), verts=24))
    decor_finish(s, "decor_controller", parts, yaw=-14, elevation=26)


def decor_cube():
    s = reset()
    import random as _r
    rng = _r.Random(5)
    black = mat("plastic", "#0d0d0f", 0.4)
    colors = ["#ffffff", "#ef4444", "#3b82f6", "#f59e0b", "#10b981", "#f97316"]
    tile_mats = [mat("t" + c, c, 0.3, coat=0.5) for c in colors]
    parts = []
    u = 0.019
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            for k in (-1, 0, 1):
                parts.append(cube("c", (u * 0.97, u * 0.97, u * 0.97), (i * u, j * u, 0.0285 + k * u), black, bev=0.002))
                if k == 1:
                    parts.append(cube("top", (u * 0.82, u * 0.82, 0.0012), (i * u, j * u, 0.0285 + 1.5 * u), tile_mats[0 if rng.random() < 0.6 else rng.randrange(6)], bev=0.0005))
                if j == -1:
                    parts.append(cube("front", (u * 0.82, 0.0012, u * 0.82), (i * u, -1.5 * u, 0.0285 + k * u), tile_mats[rng.randrange(6)], bev=0.0005))
                if i == 1:
                    parts.append(cube("side", (0.0012, u * 0.82, u * 0.82), (1.5 * u, j * u, 0.0285 + k * u), tile_mats[rng.randrange(6)], bev=0.0005))
    decor_finish(s, "decor_cube", parts, yaw=-32, elevation=22)


def decor_bonsai():
    s = reset()
    parts = [cube("pot", (0.11, 0.06, 0.026), (0, 0, 0.013), mat("glaze", "#2d4a6b", 0.22, coat=0.8), bev=0.004),
             cube("soil", (0.1, 0.05, 0.004), (0, 0, 0.026), mat("moss", "#4a6b3a", 0.9))]
    curve = bpy.data.curves.new("trunk", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.006
    curve.bevel_resolution = 4
    spline = curve.splines.new("NURBS")
    pts = [(0, 0, 0.026), (0.012, 0, 0.045), (0.016, 0, 0.065), (-0.004, 0, 0.082), (-0.02, 0, 0.095), (-0.012, 0, 0.11)]
    spline.points.add(len(pts) - 1)
    for p, co in zip(spline.points, pts):
        p.co = (*co, 1)
        p.radius = 1.4 - 0.18 * pts.index(co)
    spline.use_endpoint_u = True
    spline.order_u = 4
    trunk = bpy.data.objects.new("trunk", curve)
    bpy.context.collection.objects.link(trunk)
    trunk.data.materials.append(mat("bark", "#5b3a29", 0.85))
    parts.append(trunk)
    leaf_m = [mat("lf1", "#3f7a3f", 0.6), mat("lf2", "#4f8f45", 0.55), mat("lf3", "#2f6234", 0.65)]
    import random as _r
    rng = _r.Random(9)
    for cx, cz, rr in [(0.03, 0.075, 0.024), (-0.03, 0.1, 0.026), (-0.004, 0.122, 0.02), (0.018, 0.098, 0.016)]:
        for n in range(14):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=rng.uniform(0.006, 0.011),
                                                  location=(cx + rng.uniform(-rr, rr), rng.uniform(-rr * 0.6, rr * 0.6), cz + rng.uniform(-rr * 0.35, rr * 0.4)))
            leafball = bpy.context.object
            assign(leafball, leaf_m[n % 3])
            parts.append(leafball)
    decor_finish(s, "decor_bonsai", parts, yaw=-6)


def decor_snowglobe():
    s = reset()
    wood = mat("wood", "#6b4423", 0.5, coat=0.4)
    parts = [cylinder("base", 0.036, 0.026, (0, 0, 0.013), wood, verts=48, r2=0.032),
             cylinder("ground", 0.03, 0.004, (0, 0, 0.028), mat("snow", "#f4f7fb", 0.6), verts=48)]
    win = mat("tinywin", "#5b6170", 0.5, emit="#ffd59a", emit_strength=0.6)
    for x, y, h in [(-0.012, 0.004, 0.026), (0.0, -0.006, 0.036), (0.012, 0.006, 0.022), (0.006, 0.012, 0.03), (-0.006, 0.014, 0.018)]:
        parts.append(cube("bld", (0.008, 0.008, h), (x, y, 0.03 + h / 2), win))
    import random as _r
    rng = _r.Random(4)
    snow = mat("flake", "#ffffff", 0.4, emit="#ffffff", emit_strength=0.3)
    for _ in range(40):
        a, r, z = rng.uniform(0, math.tau), rng.uniform(0, 0.03), rng.uniform(0.035, 0.09)
        parts.append(sphere("f", 0.0013, (math.cos(a) * r, math.sin(a) * r, z), snow, seg=8))
    glass = mat("glass", "#dbeafe", 0.03, alpha=0.16)
    glass.surface_render_method = "BLENDED"
    glass.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 1.0
    parts.append(sphere("globe", 0.039, (0, 0, 0.062), glass, seg=48))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.033, minor_radius=0.003, location=(0, 0, 0.027))
    rim = bpy.context.object
    smooth(rim)
    assign(rim, mat("rim", "#e6b422", 0.2, 1.0))
    parts.append(rim)
    decor_finish(s, "decor_snowglobe", parts, yaw=0)


def decor_rocket():
    s = reset()
    white = mat("hull", "#f1f3f6", 0.3, coat=0.6)
    red = mat("nose", "#e63946", 0.3, coat=0.6)
    parts = [cylinder("stand", 0.03, 0.006, (0, 0, 0.003), mat("stand", "#2b2f38", 0.4, 0.7), verts=48),
             cylinder("body", 0.016, 0.075, (0, 0, 0.058), white, verts=32),
             cylinder("nose", 0.016, 0.032, (0, 0, 0.1115), red, verts=32, r2=0.0005),
             cylinder("flame", 0.009, 0.02, (0, 0, 0.012), mat("flame", "#111111", 0.5, emit="#ff8a3d", emit_strength=5.0), verts=24, r2=0.002)]
    window = cylinder("window", 0.0065, 0.002, (0, -0.0158, 0.07), mat("glass", "#60a5fa", 0.1, coat=1.0), verts=24)
    window.rotation_euler = (math.radians(90), 0, 0)
    parts[-1].rotation_euler = (math.radians(180), 0, 0)
    parts.append(window)
    for k in range(3):
        a = math.radians(90 + k * 120)
        fin = cube("fin", (0.003, 0.016, 0.022), (math.cos(a) * 0.018, math.sin(a) * 0.018, 0.031), red, bev=0.001)
        fin.rotation_euler = (0, 0, a - math.radians(90))
        parts.append(fin)
    decor_finish(s, "decor_rocket", parts, yaw=-10)


# --- desk mats ------------------------------------------------------------------------------------------------

def decor_task_lamp():
    s = reset()
    paint = mat("ochre powder coat", "#bd693c", 0.46, 0.12)
    steel = mat("brushed hardware", "#b79a73", 0.4, 0.65)
    diffuser = mat("opal diffuser", "#f5e5cc", 0.4, emit="#ffc18c", emit_strength=0.45)
    parts = [cylinder("weighted foot", 0.041, 0.009, (0, 0, 0.0045), paint),
             cylinder("stem", 0.006, 0.111, (0, 0, 0.061), steel),
             cylinder("shade", 0.055, 0.043, (0, 0, 0.136), paint, verts=64, r2=0.030),
             cylinder("glass diffuser", 0.052, 0.003, (0, 0, 0.1145), diffuser, verts=64),
             cylinder("switch", 0.004, 0.004, (0.025, -0.023, 0.011), steel, verts=20)]
    decor_finish(s, "decor_task_lamp", parts, elevation=22)


def decor_film_camera():
    s = reset()
    metal = mat("brushed silver", "#c1c1ba", 0.45, 0.54)
    leather = mat("olive leatherette", "#32382d", 0.92)
    dark = mat("lens barrel", "#22272b", 0.48, 0.35)
    glass = mat("coated glass", "#305766", 0.12, 0.35, coat=0.8)
    parts = [cube("cast body", (0.125, 0.035, 0.070), (0, 0, 0.035), metal, bev=0.005),
             cube("grip panels", (0.127, 0.036, 0.041), (0, 0, 0.033), leather, bev=0.004),
             cube("viewfinder", (0.026, 0.002, 0.011), (-0.038, -0.0185, 0.057), glass, bev=0.002),
             cylinder("shutter", 0.010, 0.005, (0.044, 0, 0.072), dark, verts=32)]
    for radius, depth, y, material in [(0.026, 0.012, -0.021, metal), (0.022, 0.024, -0.034, dark),
                                       (0.020, 0.008, -0.045, metal), (0.017, 0.004, -0.050, glass)]:
        ring = cylinder("lens assembly", radius, depth, (0.009, y, 0.032), material, verts=48)
        ring.rotation_euler.x = math.pi / 2
        parts.append(ring)
    decor_finish(s, "decor_film_camera", parts, yaw=-13, elevation=22)


def decor_notebook():
    s = reset()
    cloth = mat("linen cover", "#27666c", 0.86)
    paper = mat("uncoated paper", "#d9c5a4", 0.9)
    ink = mat("gold foil", "#d4ac66", 0.44, 0.45)
    black = mat("graphite barrel", "#252a2c", 0.42, 0.24)
    parts = [cube("pages", (0.136, 0.108, 0.015), (0.001, 0, 0.010), paper, bev=0.003)]
    for height in (0.002, 0.019):
        parts.append(cube("cloth cover", (0.142, 0.117, 0.004), (0, 0, height), cloth, bev=0.002))
    parts.append(cube("cloth spine", (0.009, 0.116, 0.021), (-0.067, 0, 0.011), cloth, bev=0.002))
    parts.append(cube("elastic strap", (0.008, 0.118, 0.0018), (0.045, 0, 0.022), black, bev=0.001))
    parts.append(lettering("FIELD NOTES", 0.012, (-0.010, 0.019, 0.0212), ink))
    pen = cylinder("pen", 0.0045, 0.112, (0.046, 0.0, 0.028), black, verts=24)
    pen.rotation_euler = (math.pi / 2, 0, -0.25)
    parts.append(pen)
    decor_finish(s, "decor_notebook", parts, yaw=-22, elevation=30)


def scene_work_lamp():
    s = reset()
    enamel = mat("sage enamel", "#4d5a55", 0.39, 0.31)
    joint = mat("brushed joint pins", "#a2a09a", 0.4, 0.7)
    grip = mat("rubber", "#222724", 0.89)
    diffuser = mat("warm reflector", "#e4bd87", 0.42, emit="#ffd1a2", emit_strength=0.37)
    parts = [cylinder("rubber base", 0.062, 0.007, (0, 0, 0.0035), grip),
             cylinder("enamel base", 0.060, 0.014, (0, 0, 0.014), enamel),
             cylinder("swivel collar", 0.016, 0.026, (0, 0, 0.032), joint)]
    points = [Vector((0, 0, 0.04)), Vector((0.043, 0.027, 0.185)), Vector((-0.063, -0.006, 0.293))]
    for start, end in zip(points, points[1:]):
        axis = end - start
        for shift in (-0.009, 0.009):
            arm = cylinder("articulated arm", 0.0042, axis.length, (start + end) / 2 + Vector((0, shift, 0)), enamel, verts=20)
            arm.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
            parts.append(arm)
        pin = cylinder("pivot pin", 0.010, 0.029, end, joint, verts=24)
        pin.rotation_euler.x = math.pi / 2
        parts.append(pin)
    center = points[-1] + Vector((-0.031, -0.014, -0.023))
    normal = Vector((0.46, 0.13, 0.88)).normalized()
    shade = cylinder("metal shade", 0.064, 0.060, center, enamel, verts=64, r2=0.019)
    glass = cylinder("reflector", 0.060, 0.003, center - normal * 0.030, diffuser, verts=64)
    for part in (shade, glass):
        part.rotation_euler = normal.to_track_quat("Z", "Y").to_euler()
        parts.append(part)
    decor_finish(s, "scene_work_lamp", parts, yaw=-12, elevation=20)

def desk_mat(item_id, kind):
    s = reset()
    W, D = 0.54, 0.24
    parts = []
    if kind == "navy":
        parts.append(cube("edge", (W + 0.004, D + 0.004, 0.0032), (0, 0, 0.0016), mat("stitch", "#2c3a54", 0.9), bev=0.0012))
        parts.append(cube("mat", (W, D, 0.004), (0, 0, 0.002), mat("felt", "#0f1520", 0.97), bev=0.0015))
    elif kind == "pixel":
        m = mat("pixel", "#2b1f4a", 0.85)
        nt = m.node_tree
        chk = nt.nodes.new("ShaderNodeTexChecker")
        chk.inputs["Scale"].default_value = 28.0
        chk.inputs["Color1"].default_value = (*srgb("#2b1f4a"), 1)
        chk.inputs["Color2"].default_value = (*srgb("#3b2d6b"), 1)
        nt.links.new(chk.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
        parts.append(cube("mat", (W, D, 0.004), (0, 0, 0.002), m, bev=0.0015))
        for i, col in enumerate(["#f472b6", "#22d3ee", "#facc15"]):
            parts.append(cube("px%d" % i, (0.018, 0.018, 0.0008), (W / 2 - 0.05 - i * 0.022, -D / 2 + 0.03, 0.0044), mat("px" + col, col, 0.6)))
    elif kind == "cork":
        m = mat("cork", "#a0764b", 0.95)
        nt = m.node_tree
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 180.0
        noise.inputs["Detail"].default_value = 6.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*srgb("#5e3f22"), 1)
        ramp.color_ramp.elements[1].color = (*srgb("#9a6e45"), 1)
        nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
        parts.append(cube("mat", (W, D, 0.005), (0, 0, 0.0025), m, bev=0.002))
    elif kind == "rgb":
        parts.append(cube("glow", (W + 0.014, D + 0.014, 0.0035), (0, 0, 0.00175), mat("edge", "#111111", 0.4, emit="#c026d3", emit_strength=12.0), bev=0.001))
        parts.append(cube("mat", (W, D, 0.004), (0, 0, 0.0025), mat("black", "#0b0b0e", 0.9), bev=0.0015))
    m = join(parts, item_id)
    finish(s, item_id, 22, (2400, 700), light=0.3)


BUILDERS = {
    "kb_basic": lambda: keyboard("kb_basic", "#1b1e25", "#2a2e38", "#22252d"),
    "kb_white": lambda: keyboard("kb_white", "#d9dde3", "#f4f5f7", "#c9ced6"),
    "kb_rgb": lambda: keyboard("kb_rgb", "#101114", "#1a1b20", "#15161a", rgb=True),
    "kb_retro": lambda: keyboard("kb_retro", "#d8cdb4", "#e9e0c9", "#8f8576", retro=True),
    "kb_moss": lambda: keyboard("kb_moss", "#274039", "#e2dcc3", "#83a084", legend="#253332"),
    "mouse_basic": lambda: mouse("mouse_basic", "#08090b", "#3a3d45"),
    "mouse_white": lambda: mouse("mouse_white", "#eceef2", "#c9ced6"),
    "mouse_gaming": lambda: mouse("mouse_gaming", "#060708", "#30333a", accent="#22d3ee"),
    "mug_white": lambda: mug("mug_white", "#ebe6dc", text="{ }"),
    "mug_black": lambda: mug("mug_black", "#1c1d21", inner_col="#e8e2d6", rough=0.45),
    "mug_nexora": lambda: mug("mug_nexora", "#4f8cff", text="NEXORA", text_col="#ffffff"),
    "mug_moonlight": lambda: mug("mug_moonlight", "#1d2547", moon=True),
    "plant_fern": plant_fern,
    "plant_snake": plant_snake,
    "plant_cactus": plant_cactus,
    "plant_succulent": plant_succulent,
    "decor_pen_cup": decor_pen_cup,
    "decor_clock": decor_clock,
    "decor_duck": decor_duck,
    "decor_robot": decor_robot,
    "decor_lucky_cat": decor_lucky_cat,
    "decor_trophy": decor_trophy,
    "decor_controller": decor_controller,
    "decor_cube": decor_cube,
    "decor_bonsai": decor_bonsai,
    "decor_snowglobe": decor_snowglobe,
    "decor_rocket": decor_rocket,
    "decor_task_lamp": decor_task_lamp,
    "decor_film_camera": decor_film_camera,
    "decor_notebook": decor_notebook,
    "scene_work_lamp": scene_work_lamp,
    "mat_navy": lambda: desk_mat("mat_navy", "navy"),
    "mat_pixel": lambda: desk_mat("mat_pixel", "pixel"),
    "mat_cork": lambda: desk_mat("mat_cork", "cork"),
    "mat_rgb": lambda: desk_mat("mat_rgb", "rgb"),
}

for item_id, build in BUILDERS.items():
    if ONLY and item_id not in ONLY:
        continue
    build()
print("ALL_DONE")
