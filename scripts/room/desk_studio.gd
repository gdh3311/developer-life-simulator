extends Control
## Decorating mode (🎨 next to F2): drag collectible toys from the tray onto the desk, move them, drag
## them off the desk to put them away, click the keyboard / mouse / mug / plant to cycle variants, and
## flip through desk mats. Locked toys show what unlocks them, so the tray doubles as a collection.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const DeskItems := preload("res://scripts/room/desk_items.gd")
const GOLD := Color("f4c95d")

signal closed

var room: Control                 # scripts/room/room.gd
var _tray: HBoxContainer
var _status: Label
var _count: Label
var _drag := ""                   # toy id being dragged
var _drag_new := false            # came from the tray (not placed yet)
var _tray_panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Top bar.
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.07, 0.09, 0.92), 12, Color(GOLD, 0.35), 12))
	_pin(top, 0.0, 14.0)
	top.custom_minimum_size = Vector2(700, 0)
	add_child(top)
	var row := UITheme.hbox(12)
	top.add_child(row)
	var titles := UITheme.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UITheme.bold(Game.L("책상 꾸미기", "Decorate your desk"), 16, GOLD))
	_status = UITheme.label(Game.L("소품을 끌어다 책상에 놓아 보세요. 키보드·마우스·머그·화분을 누르면 바뀌어요.",
		"Drag toys onto the desk. Click the keyboard, mouse, mug or plant to swap it."), 11, UITheme.TEXT2)
	titles.add_child(_status)
	row.add_child(titles)
	var mat := UITheme.button(Game.L("매트 바꾸기", "Change mat"))
	mat.pressed.connect(func() -> void: _cycle("mat"))
	row.add_child(mat)
	var done := UITheme.button(Game.L("완료", "Done"), "primary")
	done.pressed.connect(close)
	row.add_child(done)
	# Bottom tray: the whole collection.
	_tray_panel = PanelContainer.new()
	_tray_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.07, 0.09, 0.92), 12, Color(1, 1, 1, 0.08), 10))
	_pin(_tray_panel, 0.0, 100.0)   # over the monitor: the front of the desk stays free for toys
	add_child(_tray_panel)
	var tv := UITheme.vbox(6)
	_tray_panel.add_child(tv)
	_count = UITheme.label("", 11, UITheme.MUTED)
	tv.add_child(_count)
	_tray = UITheme.hbox(8)
	tv.add_child(_tray)
	_render_tray()
	Game.event.connect(_on_event)


## Centre a panel horizontally, pinned to the top (edge 0) or bottom (edge 1); it grows from its content.
static func _pin(c: Control, edge: float, offset: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = edge
	c.anchor_bottom = edge
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = offset
	c.offset_bottom = offset
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_END if edge == 0.0 else Control.GROW_DIRECTION_BEGIN


func _on_event(kind: String, _d: Dictionary) -> void:
	if kind == "desk_changed" and is_inside_tree():
		_render_tray()


func close() -> void:
	if room != null:
		room.highlight = ""
		room.queue_redraw()
	Sfx.play("click", 0.9, -6.0)
	closed.emit()
	queue_free()


func _render_tray() -> void:
	if _tray == null:
		return
	UITheme.clear(_tray)
	var toys := DeskItems.decor_items()
	var owned := toys.filter(func(it: Dictionary) -> bool: return DeskItems.unlocked(it)).size()
	_count.text = Game.L("소품 수집 %d / %d · 책상 위 %d / %d", "Collected %d / %d · on the desk %d / %d") % [owned, toys.size(), DeskItems.placed().size(), DeskItems.MAX_DECOR]
	for it in toys:
		_tray.add_child(_toy_tile(it))


func _toy_tile(it: Dictionary) -> Control:
	var open := DeskItems.unlocked(it)
	var on_desk := DeskItems.is_placed(String(it["id"]))
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.06 if open else 0.02), 8, GOLD if on_desk else Color(1, 1, 1, 0.08), 6))
	tile.custom_minimum_size = Vector2(76, 88)
	tile.tooltip_text = Game.tx(it["name"]) + ("" if open else "\n🔒 " + DeskItems.lock_reason(it))
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_HELP
	var v := UITheme.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(v)
	var pic := TextureRect.new()
	pic.texture = DeskItems.texture(it)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(64, 58)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.modulate = Color.WHITE if open else Color(0, 0, 0, 0.55)   # a silhouette until unlocked
	v.add_child(pic)
	var name := UITheme.label(Game.tx(it["name"]) if open else "?", 10, UITheme.TEXT if open else UITheme.MUTED)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.custom_minimum_size.x = 70
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name)
	var id := String(it["id"])
	tile.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if not open:
			_say(Game.L("🔒 %s — %s", "🔒 %s — %s") % [Game.tx(it["name"]), DeskItems.lock_reason(it)])
			return
		if on_desk:
			DeskItems.remove(id)   # clicking a placed toy in the tray puts it away
			Sfx.play("click", 0.8, -6.0)
			return
		if DeskItems.placed().size() >= DeskItems.MAX_DECOR:
			_say(Game.L("책상이 꽉 찼어요. 하나를 치우고 놓아 보세요.", "The desk is full. Put one away first."))
			return
		_begin(id, true))
	return tile


func _say(text: String) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", GOLD)


func _begin(id: String, from_tray: bool) -> void:
	_drag = id
	_drag_new = from_tray
	room.highlight = id
	if from_tray:
		var spot := DeskItems.clamp_spot(room.get_local_mouse_position())
		DeskItems.placed().append({"id": id, "x": spot.x, "y": spot.y})   # previewed; committed on release
	Sfx.play("click", 1.2, -6.0)
	room.queue_redraw()


## Toy under the pointer, front-most first.
func _toy_at(p: Vector2) -> String:
	var spots := DeskItems.placed().duplicate()
	spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) > float(b["y"]))
	for s in spots:
		var it := DeskItems.item(String(s["id"]))
		if not it.is_empty() and DeskItems.decor_rect(it, Vector2(float(s["x"]), float(s["y"]))).grow(6).has_point(p):
			return String(s["id"])
	return ""


func _slot_at(p: Vector2) -> String:
	for slot in ["mouse", "mug", "plant", "keyboard"]:
		var it := DeskItems.equipped(slot)
		if not it.is_empty() and DeskItems.rect_for(it).has_point(p):
			return slot
	return ""


func _cycle(slot: String) -> void:
	var id := DeskItems.cycle(slot)
	if id == "":
		return
	Sfx.play("purchase", 1.25, -10.0)
	_say("%s · %s" % [Game.tx(DeskItems.slot_info(slot).get("name", {})), Game.tx(DeskItems.item(id)["name"])])


## Presses on the desk: pick up a toy or swap the item under the pointer.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if room == null or mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed or _drag != "":
		return
	var p: Vector2 = room.get_local_mouse_position()
	var toy := _toy_at(p)
	if toy != "":
		_begin(toy, false)
	else:
		var slot := _slot_at(p)
		if slot != "":
			_cycle(slot)
	accept_event()


## While dragging, follow the pointer everywhere (the press may have started on a tray tile).
func _input(event: InputEvent) -> void:
	if _drag == "" or room == null:
		return
	var p: Vector2 = room.get_local_mouse_position()
	if event is InputEventMouseMotion:
		move_drag(p)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop(p)
		get_viewport().set_input_as_handled()


func move_drag(p: Vector2) -> void:
	for s in DeskItems.placed():
		if s["id"] == _drag:
			var spot := DeskItems.clamp_spot(p)
			s["x"] = spot.x
			s["y"] = spot.y
	room.queue_redraw()


## Release: inside the desk area it stays (one save), above the desk or over the tray it's put away.
func _drop(p: Vector2) -> void:
	var id := _drag
	_drag = ""
	room.highlight = ""
	var screen_point: Vector2 = room.get_global_transform_with_canvas() * p   # the drop point itself, not the OS cursor
	var over_tray := _tray_panel.get_global_rect().has_point(screen_point)
	var off_desk := p.y < DeskItems.DECOR_AREA.position.y - 60
	if over_tray or off_desk:
		DeskItems.remove(id)
		Sfx.play("click", 0.8, -6.0)
		_say(Game.L("%s을(를) 치웠어요.", "Put away the %s.") % Game.tx(DeskItems.item(id)["name"]))
	else:
		DeskItems.place(id, p)
		Sfx.play("success", 1.4, -10.0)
		if _drag_new:
			_say(Game.L("%s 자리 잡았어요! 끌어서 옮기거나, 책상 밖으로 끌어내면 치워져요.", "The %s found a spot! Drag to move it, or off the desk to put it away.") % Game.tx(DeskItems.item(id)["name"]))
	room.queue_redraw()
