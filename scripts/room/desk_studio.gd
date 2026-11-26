extends Control
## Desk catalogue, matching sets, and direct placement and rotation of props.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const DeskItems := preload("res://scripts/room/desk_items.gd")
const GOLD := Color("f4c95d")
const SETS := [
	{"keyboard": "kb_basic", "mouse": "mouse_basic", "mug": "mug_black", "plant": "plant_fern", "mat": "mat_none"},
	{"keyboard": "kb_white", "mouse": "mouse_white", "mug": "mug_white", "plant": "plant_snake", "mat": "mat_navy"},
	{"keyboard": "kb_moss", "mouse": "mouse_basic", "mug": "mug_black", "plant": "plant_cactus", "mat": "mat_navy"},
]

signal closed

var room: Control                 # scripts/room/room.gd
var _tray: HBoxContainer
var _status: Label
var _count: Label
var _drag := ""                   # toy id being dragged
var _drag_new := false            # came from the tray (not placed yet)
var _drag_angle := 0.0
var _drag_point := Vector2.ZERO
var _selected := ""
var _category := "decor"
var _tray_panel: PanelContainer
var _left: Button
var _right: Button
var _lamp: CheckButton
var _selection: Label


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
	_status = UITheme.label(Game.L("소품을 놓고 Q / E로 방향을 바꿔 보세요.", "Drag in a prop. Press Q / E to turn it."), 12, UITheme.TEXT2)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(_status)
	row.add_child(titles)
	var sets := OptionButton.new()
	sets.add_item(Game.L("장비 세트", "Equipment sets"))
	sets.set_item_disabled(0, true)
	sets.add_item(Game.L("월넛", "Walnut"))
	sets.add_item(Game.L("화이트 스튜디오", "White studio"))
	sets.add_item(Game.L("모스", "Moss"))
	sets.select(0)
	sets.item_selected.connect(func(index: int) -> void:
		if index > 0 and DeskItems.equip_set(SETS[index - 1]):
			Sfx.play("purchase", 1.2, -10.0)
			_say(Game.L("%s 세트를 적용했어요.", "Applied the %s set.") % sets.get_item_text(index))
		sets.select(0))
	row.add_child(sets)
	var done := UITheme.button(Game.L("완료", "Done"), "primary")
	done.pressed.connect(close)
	row.add_child(done)
	# Bottom tray: the whole collection.
	_tray_panel = PanelContainer.new()
	_tray_panel.custom_minimum_size.x = minf(1090.0, get_viewport_rect().size.x - 40.0)
	_tray_panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.07, 0.09, 0.92), 12, Color(1, 1, 1, 0.08), 10))
	_pin(_tray_panel, 0.0, 100.0)   # over the monitor: the front of the desk stays free for toys
	add_child(_tray_panel)
	var tv := UITheme.vbox(6)
	_tray_panel.add_child(tv)
	var controls := UITheme.hbox(8)
	tv.add_child(controls)
	var categories := OptionButton.new()
	var slots := ["decor"] + DeskItems.slots()
	for slot in slots:
		categories.add_item(Game.L("소품", "Props") if slot == "decor" else Game.tx(DeskItems.slot_info(slot)["name"]))
	categories.item_selected.connect(func(index: int) -> void:
		_category = slots[index]
		_render_tray())
	controls.add_child(categories)
	_count = UITheme.label("", 12, UITheme.MUTED)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(_count)
	_selection = UITheme.label("", 12, GOLD)
	controls.add_child(_selection)
	_left = UITheme.button("↶ 15°")
	_left.tooltip_text = Game.L("왼쪽으로 돌리기 (Q)", "Rotate left (Q)")
	_left.pressed.connect(_rotate.bind(-15.0))
	controls.add_child(_left)
	_right = UITheme.button("↷ 15°")
	_right.tooltip_text = Game.L("오른쪽으로 돌리기 (E)", "Rotate right (E)")
	_right.pressed.connect(_rotate.bind(15.0))
	controls.add_child(_right)
	_lamp = CheckButton.new()
	_lamp.text = Game.L("조명", "Lamp")
	_lamp.toggled.connect(DeskItems.set_lamp)
	controls.add_child(_lamp)
	_tray = UITheme.hbox(8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 110
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_tray)
	tv.add_child(scroll)
	categories.item_selected.connect(func(_index: int) -> void: scroll.scroll_horizontal = 0)
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
	_cancel_drag()
	Sfx.play("click", 0.9, -6.0)
	closed.emit()
	queue_free()


func _render_tray() -> void:
	if _tray == null:
		return
	UITheme.clear(_tray)
	var items := DeskItems.items_for(_category)
	var owned := items.filter(func(it: Dictionary) -> bool: return DeskItems.unlocked(it)).size()
	_count.text = Game.L("수집 %d / %d", "Collected %d / %d") % [owned, items.size()]
	if _category == "decor":
		_count.text += Game.L("   ·   배치 %d / %d", "   ·   Placed %d / %d") % [DeskItems.placed().size(), DeskItems.MAX_DECOR]
	for it in items:
		_tray.add_child(_toy_tile(it))
	_update_selection()


func _toy_tile(it: Dictionary) -> Control:
	var open := DeskItems.unlocked(it)
	var decor: bool = it["slot"] == "decor"
	var on_desk: bool = DeskItems.is_placed(String(it["id"])) if decor else DeskItems.equipped(it["slot"]).get("id") == it["id"]
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.06 if open else 0.02), 8, GOLD if on_desk else Color(1, 1, 1, 0.08), 6))
	tile.custom_minimum_size = Vector2(110, 92)
	tile.tooltip_text = Game.tx(it["name"]) + ("" if open else "\n🔒 " + DeskItems.lock_reason(it))
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_HELP
	var v := UITheme.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(v)
	var pic := TextureRect.new()
	pic.texture = DeskItems.texture(it)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(96, 58)
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
		if not decor:
			DeskItems.equip(it["slot"], id)
			_say(Game.tx(it["name"]))
			Sfx.play("click", 1.1, -6.0)
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
	_selected = id
	var saved := _placement(id)
	_drag_angle = float(saved.get("angle", 0.0))
	room.highlight = id
	var pointer: Vector2 = room.get_local_mouse_position()
	move_drag(room.layout_point(pointer) if saved.is_empty() else Vector2(float(saved["x"]), float(saved["y"])))
	Sfx.play("click", 1.2, -6.0)
	_update_selection()


func _placement(id: String) -> Dictionary:
	for placement in DeskItems.placed():
		if placement["id"] == id:
			return placement
	return {}


func _update_selection() -> void:
	var placement := _placement(_selected)
	var active := _drag != "" or not placement.is_empty()
	_left.disabled = not active
	_right.disabled = not active
	_selection.text = ""
	if active:
		var angle := _drag_angle if _drag != "" else float(placement.get("angle", 0.0))
		_selection.text = "%s · %d°" % [Game.tx(DeskItems.item(_selected)["name"]), roundi(angle)]
	_lamp.visible = DeskItems.is_placed("decor_task_lamp")
	_lamp.set_pressed_no_signal(DeskItems.lamp_on())


func _rotate(amount: float) -> void:
	if _drag != "":
		_drag_angle = wrapf(_drag_angle + amount, -180.0, 180.0)
		move_drag(_drag_point)
	else:
		var placement := _placement(_selected)
		if placement.is_empty():
			return
		DeskItems.place(_selected, Vector2(float(placement["x"]), float(placement["y"])), float(placement.get("angle", 0)) + amount)
	_update_selection()
	Sfx.play("click", 1.1, -10.0)


func _slot_at(p: Vector2) -> String:
	for slot in ["mouse", "mug", "plant", "keyboard"]:
		var it := DeskItems.equipped(slot)
		if not it.is_empty() and room.prop_bounds(slot, DeskItems.rect_for(it)).has_point(p):
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
	var props := DeskItems.placed().map(func(entry: Dictionary) -> String: return entry["id"])
	var hit: String = room.pick_prop(p, props + ["mouse", "mug", "plant", "keyboard"])
	if hit in props:
		_begin(hit, false)
	else:
		var slot := _slot_at(p) if hit.is_empty() else hit
		if slot != "":
			_cycle(slot)
	accept_event()


## While dragging, follow the pointer everywhere (the press may have started on a tray tile).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if _drag != "":
					_cancel_drag()
					_update_selection()
				else:
					close()
			KEY_Q:
				_rotate(-15.0)
			KEY_E:
				_rotate(15.0)
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if _drag == "" or room == null:
		return
	var p: Vector2 = room.get_local_mouse_position()
	if event is InputEventMouseMotion:
		move_drag(room.layout_point(p))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop(p)
		get_viewport().set_input_as_handled()


func move_drag(p: Vector2) -> void:
	_drag_point = DeskItems.clamp_spot(p)
	room.set_preview({"id": _drag, "x": _drag_point.x, "y": _drag_point.y, "angle": _drag_angle})


func _cancel_drag() -> void:
	_drag = ""
	if room != null:
		room.highlight = ""
		room.set_preview({})


## Release: inside the desk area it stays (one save), above the desk or over the tray it's put away.
func _drop(p: Vector2) -> void:
	var id := _drag
	var from_tray := _drag_new
	var angle := _drag_angle
	_cancel_drag()
	var screen_point: Vector2 = room.get_global_transform_with_canvas() * p   # the drop point itself, not the OS cursor
	var over_tray := _tray_panel.get_global_rect().has_point(screen_point)
	var layout: Vector2 = room.layout_point(p)
	var off_desk := not DeskItems.DECOR_AREA.grow_individual(120, 34, 120, 34).has_point(layout)
	if over_tray or off_desk:
		if not from_tray:
			DeskItems.remove(id)
		Sfx.play("click", 0.8, -6.0)
		_say(Game.L("%s을(를) 치웠어요.", "Put away the %s.") % Game.tx(DeskItems.item(id)["name"]))
	else:
		DeskItems.place(id, layout, angle)
		Sfx.play("success", 1.4, -10.0)
		if from_tray:
			_say(Game.L("%s 자리 잡았어요! 끌어서 옮기거나, 책상 밖으로 끌어내면 치워져요.", "The %s found a spot! Drag to move it, or off the desk to put it away.") % Game.tx(DeskItems.item(id)["name"]))
	_update_selection()
