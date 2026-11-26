extends Control
## The desk and office around the monitor.
## The window's sky follows the in-game clock.

const VIEW := Vector2(1920, 1080)
const DeskItems := preload("res://scripts/room/desk_items.gd")
const DeskModels := preload("res://scripts/room/desk_models.gd")
const CityView := preload("res://scripts/room/city_view.gd")
const MODEL_SLOTS := ["plant", "mug", "keyboard", "mouse"]

var monitor_rect := Rect2()   # outer frame of the monitor (set by main)
var screen_glow := 0.0        # 0..1, monitor light on the desk/wall
var time_override := -1.0     # minutes; set during day transitions
var tier := 0                 # workstation tier (0 intern, 1 side monitor, 2 desk mat + nameplate)
var _buildings: Array = []    # [x, w, h, lit windows seed]
var _rng := RandomNumberGenerator.new()
var _views := {}              # window_day/dusk/night renders of the 3D city (tools/blender/city_window.py)
var highlight := ""           # toy being dragged in decorating mode (drawn with a glow)
var _models: SubViewport
var _city: SubViewport
var _preview := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = VIEW
	_models = DeskModels.new()
	add_child(_models)
	_city = CityView.new()
	add_child(_city)
	for v in ["day", "dusk", "night"]:
		var path := "res://content/room/window_%s.png" % v
		if not _city.available and ResourceLoader.exists(path, "Texture2D"):
			_views[v] = load(path)
	_rng.seed = 7
	var x := 0.0
	while x < 520:
		var w := _rng.randf_range(34, 80)
		_buildings.append([x, w, _rng.randf_range(120, 420), _rng.randi()])
		x += w + _rng.randf_range(2, 10)
	Game.time_changed.connect(func(_d: int, _m: int) -> void: refresh_props())
	Game.event.connect(func(kind: String, d: Dictionary) -> void:
		if kind == "purchase":
			# A new keyboard goes straight onto the desk.
			if String(d.get("item", d.get("id", ""))) == "keyboard_rgb":
				DeskItems.equip("keyboard", "kb_rgb")
			refresh_props()
		elif kind == "desk_changed":
			refresh_props()
		if kind in ["ticket_done", "achievement", "pr_merged", "purchase", "promoted", "skill_up", "ai_used", "form_submitted", "arc_stage"]:
			_announce_new_items())
	Game.state_reset.connect(refresh_props)
	refresh_props()


func refresh_props() -> void:
	_models.sync(MODEL_SLOTS, placements(), tier)
	queue_redraw()


func set_preview(placement: Dictionary) -> void:
	_preview = placement
	refresh_props()


func placements() -> Array:
	if _preview.is_empty():
		return DeskItems.placed()
	var current := DeskItems.placed().filter(func(p: Dictionary) -> bool: return p["id"] != _preview["id"])
	current.append(_preview)
	return current


func set_camera_depth(closer: bool) -> void:
	_city.lean(closer)


func prop_bounds(key: String, fallback: Rect2) -> Rect2:
	return _models.bounds_for(key, fallback)


func layout_point(pixel: Vector2) -> Vector2:
	return _models.layout_point(pixel)


func canvas_point(layout: Vector2) -> Vector2:
	return _models.canvas_point(layout)


func pick_prop(pixel: Vector2, keys: Array) -> String:
	return _models.pick(pixel, keys)


## "New desk toy!" — tell the player when something they did unlocked a mat or a toy.
func _announce_new_items() -> void:
	for it in DeskItems.newly_unlocked():
		if it["slot"] in ["decor", "mat"] and it["id"] != "mat_none":
			Sfx.play("promote", 1.3, -8.0)
			Game.notify("dashboard", Game.L("🎁 새 책상 소품", "🎁 New desk item"),
				Game.L("%s · Dashboard의 내 책상에서 배치하세요.", "%s · Arrange it under My desk in Dashboard.") % Game.tx(it["name"]))


func _owns(item: String) -> bool:
	return Game.state["owned"].has(item)


## 0 = night, 1 = full day, with warm tones near sunrise/sunset.
func _now() -> float:
	return time_override if time_override >= 0.0 else float(Game.minutes())


func _daylight() -> float:
	var h := _now() / 60.0
	if h < 6.0 or h > 20.0:
		return 0.0
	if h < 8.0:
		return (h - 6.0) / 2.0
	if h > 17.5:
		return clampf(1.0 - (h - 17.5) / 2.5, 0.0, 1.0)
	return 1.0


func _sunset() -> float:
	var h := _now() / 60.0
	return clampf(1.0 - absf(h - 18.45) / 1.65, 0.0, 1.0)


func _draw() -> void:
	var day := _daylight()
	var dusk := _sunset()

	# Wall
	var wall_top := Color("10131b").lerp(Color("1d2433"), day * 0.6)
	var wall_bottom := Color("0a0c11").lerp(Color("161b26"), day * 0.5)
	_vgradient(Rect2(-400, -400, VIEW.x + 800, 1400), wall_top, wall_bottom)
	for i in range(-6, 30):
		draw_line(Vector2(i * 96, -400), Vector2(i * 96, 960), Color(1, 1, 1, 0.012), 2.0)

	_draw_window(Rect2(34, 90, 506, 560), day, dusk)
	_draw_shelf(Rect2(1420, 210, 360, 14))
	_draw_poster(Rect2(1500, 380, 170, 230))

	# Monitor spill on the wall. The worktop and its lighting are in the desk viewport.
	var desk_y := 900.0
	if screen_glow > 0.0:
		_radial(Vector2(VIEW.x / 2.0, 470), Vector2(1050, 620), Color(0.4, 0.55, 1.0, 0.07 * screen_glow))
	_models.lighting(day, dusk, screen_glow)
	draw_texture_rect(_models.get_texture(), DeskModels.AREA, false)

	if _owns("neon"):
		_draw_neon(Vector2(1700, 120))
	if _owns("plant_big"):
		_draw_monstera(Vector2(1830, 1000))
	if tier < 1 and not _models.visible_model("work_lamp"):
		_draw_lamp(Vector2(1640, desk_y), day)
	var mat_item := DeskItems.equipped("mat")
	if not _models.visible_model("mat") and not mat_item.is_empty() and mat_item["id"] != "mat_none":
		_draw_slot("mat", func() -> void: pass)
	if _owns("coffee_machine"):
		_draw_coffee_machine(Vector2(560, desk_y))
	if _owns("figure"):
		_draw_figure(Vector2(1380, desk_y))
	if _owns("headphones"):
		_draw_headphones(Vector2(1500, desk_y))
	# Custom PNG/SVG items and missing model fallbacks retain their original footprint.
	var layers: Array = []
	var fallbacks := {
		"plant": func() -> void: _draw_plant(Vector2(250, desk_y)),
		"mug": func() -> void: _draw_mug(Vector2(420, desk_y)),
		"keyboard": func() -> void: _draw_keyboard(Vector2(VIEW.x / 2.0, desk_y + 58)),
		"mouse": func() -> void: _draw_mouse(Vector2(VIEW.x / 2.0 + 470, desk_y + 70)),
	}
	for slot in fallbacks:
		if not _models.visible_model(slot):
			var it := DeskItems.equipped(slot)
			var bottom := DeskItems.rect_for(it).end.y if not it.is_empty() else desk_y
			layers.append([bottom, slot, null])
	for p in placements():
		var it := DeskItems.item(String(p["id"]))
		if not it.is_empty() and DeskItems.unlocked(it) and not _models.visible_model(it["id"]):
			layers.append([float(p["y"]), "", p])
	layers.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for layer in layers:
		if layer[2] == null:
			_draw_slot(layer[1], fallbacks[layer[1]])
		else:
			_draw_decor(layer[2])
	if monitor_rect.size != Vector2.ZERO:
		if _owns("light_bar"):
			_draw_light_bar()
	if highlight != "" and _models.visible_model(highlight):
		var bounds := prop_bounds(highlight, Rect2())
		draw_line(bounds.end - Vector2(bounds.size.x, 0), bounds.end, Color("cdb280"), 1.5, true)


func _draw_window(r: Rect2, day: float, dusk: float) -> void:
	var night_top := Color("070a14")
	var night_bottom := Color("141a33")
	var day_top := Color("5d8fd6")
	var day_bottom := Color("b9d4ef")
	var dusk_top := Color("3b3a78")
	var dusk_bottom := Color("f08a5d")
	var top := night_top.lerp(day_top, day).lerp(dusk_top, dusk * 0.8)
	var bottom := night_bottom.lerp(day_bottom, day).lerp(dusk_bottom, dusk * 0.85)
	_vgradient(r, top, bottom)
	if _city.available:
		_city.light(day, dusk)
		draw_texture_rect(_city.get_texture(), r, false)
		_draw_window_frame(r, day, dusk)
		return

	# The 3D city rendered for night, day and dusk, cross-faded by the clock.
	if _views.size() == 3:
		draw_texture_rect(_views["night"], r, false)
		if day > 0.0:
			draw_texture_rect(_views["day"], r, false, Color(1, 1, 1, day))
		if dusk > 0.0:
			draw_texture_rect(_views["dusk"], r, false, Color(1, 1, 1, dusk * 0.9))
		_draw_window_frame(r, day, dusk)
		return

	# Fallback skyline (no renders)
	var base := r.end.y
	for b in _buildings:
		var bx: float = r.position.x + b[0]
		var bw: float = b[1]
		if bx > r.end.x:
			continue
		bw = minf(bw, r.end.x - bx)
		var bh: float = b[2]
		var col := Color("0b0f1c").lerp(Color("4a5b78"), day * 0.7).lerp(Color("2c2440"), dusk * 0.6)
		draw_rect(Rect2(bx, base - bh, bw, bh), col)
		var rng := RandomNumberGenerator.new()
		rng.seed = b[3]
		var lit_chance := 0.55 - day * 0.45
		var wy := base - bh + 10
		while wy < base - 8:
			var wx := bx + 6
			while wx < bx + bw - 8:
				if rng.randf() < lit_chance:
					draw_rect(Rect2(wx, wy, 6, 8), Color(1.0, 0.85, 0.5, 0.75 - day * 0.4))
				wx += 13
			wy += 16
	_draw_window_frame(r, day, dusk)


func _draw_window_frame(r: Rect2, day: float, dusk: float) -> void:
	# Glass reflection + blinds + frame
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.55, 0), r.position + Vector2(r.size.x * 0.75, 0),
		r.position + Vector2(r.size.x * 0.35, r.size.y), r.position + Vector2(r.size.x * 0.15, r.size.y)]), Color(1, 1, 1, 0.035))
	var y := r.position.y + 8
	while y < r.position.y + r.size.y * 0.38:
		draw_rect(Rect2(r.position.x, y, r.size.x, 3), Color(0.85, 0.85, 0.8, 0.10))
		y += 14
	draw_rect(r, Color("2a2f3a"), false, 10.0)
	draw_rect(r.grow(6), Color("141821"), false, 4.0)
	draw_line(r.position + Vector2(2, 3), Vector2(r.end.x - 2, r.position.y + 3), Color("495266"), 2.0)
	draw_rect(Rect2(r.position.x + r.size.x / 2.0 - 4, r.position.y, 8, r.size.y), Color("2a2f3a"))
	draw_rect(Rect2(r.position.x - 18, r.end.y + 4, r.size.x + 36, 14), Color("323846"))
	# Daylight spill on the wall
	if day > 0.0:
		draw_colored_polygon(PackedVector2Array([r.end + Vector2(0, -r.size.y), r.end, Vector2(r.end.x + 520, 980), Vector2(r.end.x + 380, r.position.y + 40)]),
			Color(1.0, 0.92, 0.75, 0.035 * day + 0.03 * dusk))


func _draw_shelf(r: Rect2) -> void:
	draw_rect(r, Color("3b2c20"))
	var x := r.position.x + 16
	var colors := ["8b5cf6", "3b82f6", "ef4444", "f59e0b", "10b981", "64748b", "e11d48"]
	for i in 9:
		var w := 14.0 + (i * 7 % 9)
		var h := 70.0 + (i * 13 % 30)
		draw_rect(Rect2(x, r.position.y - h, w, h), Color(colors[i % colors.size()]).darkened(0.45))
		x += w + 3
	draw_circle(Vector2(r.end.x - 60, r.position.y - 26), 26, Color("1f2937"))
	draw_circle(Vector2(r.end.x - 60, r.position.y - 26), 20, Color("e5e7eb").darkened(0.3))
	draw_line(Vector2(r.end.x - 60, r.position.y - 26), Vector2(r.end.x - 60, r.position.y - 40), Color("111827"), 3.0)
	draw_line(Vector2(r.end.x - 60, r.position.y - 26), Vector2(r.end.x - 50, r.position.y - 22), Color("111827"), 3.0)


func _draw_poster(r: Rect2) -> void:
	draw_rect(r.grow(6), Color("23262f"))
	_vgradient(r, Color("1e3a8a"), Color("312e81"))
	draw_string(get_theme_default_font(), r.position + Vector2(18, 60), "SHIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.85))
	draw_string(get_theme_default_font(), r.position + Vector2(18, 104), "IT.", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.85))
	draw_string(get_theme_default_font(), r.position + Vector2(18, 200), "(with tests)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.5))


func _draw_lamp(base: Vector2, day: float) -> void:
	var on := 1.0 - day * 0.7
	# light cone
	draw_colored_polygon(PackedVector2Array([base + Vector2(-120, -330), base + Vector2(-60, -330), base + Vector2(60, 0), base + Vector2(-330, 0)]),
		Color(1.0, 0.82, 0.5, 0.06 * on))
	_radial(base + Vector2(-140, 6), Vector2(260, 40), Color(1.0, 0.8, 0.45, 0.25 * on))
	draw_rect(Rect2(base.x - 46, base.y - 12, 92, 12), Color("1c1f26"))
	draw_line(base + Vector2(0, -12), base + Vector2(40, -220), Color("2b2f38"), 8.0, true)
	draw_line(base + Vector2(40, -220), base + Vector2(-80, -320), Color("2b2f38"), 8.0, true)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-140, -350), base + Vector2(-50, -330), base + Vector2(-70, -300), base + Vector2(-130, -315)]), Color("343a46"))
	draw_circle(base + Vector2(-95, -318), 9, Color(1.0, 0.9, 0.6, 0.4 + 0.6 * on))


## Draw the equipped asset for a desk slot; fall back to the vector drawing if it can't load.
func _draw_slot(slot: String, fallback: Callable) -> void:
	var it := DeskItems.equipped(slot)
	var tex := DeskItems.texture(it) if not it.is_empty() else null
	if tex == null:
		fallback.call()
		return
	var live: bool = _models.visible_model(slot)
	var r: Rect2 = prop_bounds(slot, DeskItems.rect_for(it))
	# Soft contact shadow so rendered items sit on the desk instead of floating over it.
	var foot := Vector2(r.get_center().x, r.end.y - r.size.y * (0.08 if slot in ["keyboard", "mouse"] else 0.03))
	_radial(foot, Vector2(r.size.x * 0.55, maxf(10.0, r.size.y * 0.12)), Color(0, 0, 0, 0.42))
	if live:
		return
	# Renders are lit like a bright room; dim them a little with the evening.
	var shade := lerpf(0.78, 1.0, _daylight())
	draw_texture_rect(tex, r, false, Color(shade, shade * 0.99, shade * 1.02))


## A placed toy: base centre at (x, y), with the same contact shadow and evening shade as slot items.
func _draw_decor(p: Dictionary) -> void:
	var it := DeskItems.item(String(p["id"]))
	var tex := DeskItems.texture(it)
	if tex == null:
		return
	var id: String = p["id"]
	var r := prop_bounds(id, DeskItems.decor_rect(it, Vector2(float(p["x"]), float(p["y"]))))
	if String(p["id"]) == highlight:
		_radial(Vector2(r.get_center().x, r.end.y - 4), Vector2(r.size.x * 0.9, 18), Color(1.0, 0.85, 0.4, 0.35))
	_radial(Vector2(r.get_center().x, r.end.y - 3), Vector2(r.size.x * 0.55, maxf(8.0, r.size.y * 0.1)), Color(0, 0, 0, 0.45))
	if _models.visible_model(id):
		return
	var shade := lerpf(0.78, 1.0, _daylight())
	draw_texture_rect(tex, r, false, Color(shade, shade * 0.99, shade * 1.02))


func equipped_texture(slot: String) -> Texture2D:
	var it := DeskItems.equipped(slot)
	return DeskItems.texture(it) if not it.is_empty() else null


func _draw_plant(base: Vector2) -> void:
	var leaf := Color("2f6b45")
	for i in 7:
		var a := deg_to_rad(-150 + i * 20)
		var tip := base + Vector2(0, -60) + Vector2(cos(a), sin(a)) * (90 + (i % 3) * 18)
		var mid := (base + Vector2(0, -60) + tip) / 2.0
		var n := (tip - base).orthogonal().normalized() * 14
		draw_colored_polygon(PackedVector2Array([base + Vector2(0, -60), mid + n, tip, mid - n]), leaf.lightened(0.08 * (i % 3)))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-44, -70), base + Vector2(44, -70), base + Vector2(34, 0), base + Vector2(-34, 0)]), Color("c2734f"))
	draw_rect(Rect2(base.x - 48, base.y - 78, 96, 10), Color("d48562"))


func _draw_mug(base: Vector2) -> void:
	draw_rect(Rect2(base.x - 30, base.y - 70, 60, 70), Color("e8e2d6"))
	draw_rect(Rect2(base.x - 30, base.y - 70, 60, 8), Color("cfc8bb"))
	draw_arc(base + Vector2(32, -36), 16, -PI / 2, PI / 2, 16, Color("e8e2d6"), 7.0, true)
	draw_string(get_theme_default_font(), base + Vector2(-20, -26), "{ }", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("4f8cff"))


func _draw_keyboard(c: Vector2) -> void:
	var top := 300.0
	var bottom := 340.0
	var h := 64.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-top, -h / 2), c + Vector2(top, -h / 2), c + Vector2(bottom, h / 2), c + Vector2(-bottom, h / 2)]), Color("1b1e25"))
	for row in 4:
		var t := (row + 0.5) / 4.0
		var y := c.y - h / 2 + 8 + row * 13.5
		var half := lerpf(top, bottom, t) - 14
		var keys := 15
		var kw := (half * 2) / keys
		for k in keys:
			var key_col := Color("2a2e38")
			if _owns("keyboard_rgb"):
				key_col = Color.from_hsv(fmod(float(k) / keys + row * 0.07, 1.0), 0.7, 0.9)
			draw_rect(Rect2(c.x - half + k * kw + 1.5, y, kw - 3, 10), key_col)
	draw_rect(Rect2(c.x - 120, c.y + h / 2 - 12, 240, 8), Color("2a2e38"))


func _draw_mouse(c: Vector2) -> void:
	draw_rect(Rect2(c.x - 70, c.y - 34, 140, 80), Color("15171d"))
	draw_circle(c, 18, Color("1f2229"))
	draw_rect(Rect2(c.x - 18, c.y - 4, 36, 22), Color("1f2229"))
	draw_line(c + Vector2(0, -16), c + Vector2(0, -2), Color("2e323c"), 2.0)


func _draw_neon(p: Vector2) -> void:
	var font := get_theme_default_font()
	for i in 4:
		draw_string(font, p + Vector2(-i, i), "</>", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(1.0, 0.3, 0.8, 0.08))
	draw_string(font, p, "</>", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(1.0, 0.55, 0.9))
	_radial(p + Vector2(55, -20), Vector2(160, 90), Color(1.0, 0.3, 0.8, 0.12))


func _draw_monstera(base: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([base + Vector2(-50, -90), base + Vector2(50, -90), base + Vector2(40, 0), base + Vector2(-40, 0)]), Color("3f3f46"))
	for i in 6:
		var a := deg_to_rad(-160 + i * 28)
		var c := base + Vector2(0, -100) + Vector2(cos(a), sin(a)) * 150
		draw_circle(c, 52, Color("1f5f3a").lightened(0.06 * (i % 3)))
		draw_line(base + Vector2(0, -90), c, Color("2f6b45"), 5.0)


func _draw_coffee_machine(base: Vector2) -> void:
	draw_rect(Rect2(base.x - 40, base.y - 120, 80, 120), Color("1f2228"))
	draw_rect(Rect2(base.x - 30, base.y - 110, 60, 30), Color("3b3f4a"))
	draw_circle(base + Vector2(18, -95), 5, Color("3ddc84"))
	draw_rect(Rect2(base.x - 16, base.y - 40, 32, 34), Color("e8e2d6"))


func _draw_figure(base: Vector2) -> void:
	draw_rect(Rect2(base.x - 18, base.y - 46, 36, 30), Color("5b8cff"))
	draw_rect(Rect2(base.x - 14, base.y - 70, 28, 22), Color("94a3b8"))
	draw_circle(base + Vector2(-6, -60), 3, Color("38bdf8"))
	draw_circle(base + Vector2(6, -60), 3, Color("38bdf8"))
	draw_line(base + Vector2(0, -70), base + Vector2(0, -80), Color("94a3b8"), 2.0)
	draw_circle(base + Vector2(0, -82), 3, Color("ff6b8a"))
	draw_rect(Rect2(base.x - 14, base.y - 16, 10, 16), Color("334155"))
	draw_rect(Rect2(base.x + 4, base.y - 16, 10, 16), Color("334155"))


func _draw_headphones(base: Vector2) -> void:
	draw_arc(base + Vector2(0, -20), 44, PI, TAU, 24, Color("2b2f38"), 8.0, true)
	draw_rect(Rect2(base.x - 56, base.y - 34, 24, 34), Color("3b3f4a"))
	draw_rect(Rect2(base.x + 32, base.y - 34, 24, 34), Color("3b3f4a"))


func _draw_light_bar() -> void:
	var r := monitor_rect
	var bar := Rect2(r.position.x + r.size.x * 0.32, r.position.y - 14, r.size.x * 0.36, 12)
	draw_rect(bar, Color("1c1f26"))
	draw_rect(Rect2(bar.position.x + 6, bar.end.y - 3, bar.size.x - 12, 3), Color(1.0, 0.95, 0.85, 0.9))
	_radial(Vector2(bar.get_center().x, 900), Vector2(520, 70), Color(1.0, 0.95, 0.85, 0.12))


# --- drawing helpers ------------------------------------------------------------

func _vgradient(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _radial(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var steps := 48
	pts.append(center)
	cols.append(color)
	for i in steps + 1:
		var a := TAU * i / steps
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
		cols.append(Color(color, 0.0))
	# triangle fan
	for i in range(1, steps + 1):
		draw_polygon(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), PackedColorArray([cols[0], cols[i], cols[i + 1]]))
