extends Control
## A draggable, resizable application window inside WORKSTATION OS.
## Drag the title bar to move, double-click it to maximize, drag the corner to resize.

signal closed
signal minimized

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const BAR_H := 36.0
const MIN_SIZE := Vector2(360, 220)
const TOP_LIMIT := 32.0
const DOCK_SPACE := 96.0

var app_id := ""
var _drag := false
var _resize := false
var _grab := Vector2.ZERO
var _start_size := Vector2.ZERO
var _restore := Rect2()
var _maximized := false
var _closing := false
var _bar: Panel


func setup(id: String, title: String, accent: Color, icon_name: String, content: Control, win_size: Vector2) -> void:
	app_id = id
	size = win_size

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := UITheme.box(UITheme.BG1, 12, Color(1, 1, 1, 0.08), 0, 1, 0)
	sb.shadow_size = 28
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_offset = Vector2(0, 10)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)

	_bar = Panel.new()
	_bar.anchor_right = 1.0
	_bar.offset_bottom = BAR_H
	var bar_style := UITheme.box(UITheme.BG2, 12)
	bar_style.corner_radius_bottom_left = 0
	bar_style.corner_radius_bottom_right = 0
	bar_style.border_color = Color(1, 1, 1, 0.05)
	bar_style.border_width_bottom = 1
	_bar.add_theme_stylebox_override("panel", bar_style)
	_bar.gui_input.connect(_on_bar_input)
	add_child(_bar)

	var row := UITheme.hbox(10)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_right = -8.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(row)
	var ic := Icon.make(icon_name, accent, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var title_label := UITheme.bold(title, 13, UITheme.TEXT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_vertical = Control.SIZE_FILL
	row.add_child(title_label)
	var min_btn := Button.new()
	min_btn.flat = true
	min_btn.focus_mode = Control.FOCUS_NONE
	min_btn.custom_minimum_size = Vector2(28, 24)
	min_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	min_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	min_btn.tooltip_text = "Ctrl+M"
	min_btn.add_theme_stylebox_override("hover", UITheme.box(Color(1, 1, 1, 0.08), 6))
	var mi := Icon.make("minus", UITheme.TEXT2, 12)
	mi.position = Vector2(8, 6)
	min_btn.add_child(mi)
	min_btn.pressed.connect(func() -> void: minimized.emit())
	row.add_child(min_btn)
	var close_btn := Button.new()
	close_btn.tooltip_text = "Ctrl+W"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(28, 24)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_stylebox_override("hover", UITheme.box(UITheme.ERR.darkened(0.2), 6))
	var x := Icon.make("x", UITheme.TEXT2, 12)
	x.set_anchors_preset(Control.PRESET_CENTER)
	x.position = Vector2(8, 6)
	close_btn.add_child(x)
	close_btn.pressed.connect(close)
	row.add_child(close_btn)

	var body := MarginContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_top = BAR_H
	body.offset_left = 1
	body.offset_right = -1
	body.offset_bottom = -1
	body.clip_contents = true
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	add_child(body)

	var grip := Control.new()
	grip.anchor_left = 1.0
	grip.anchor_top = 1.0
	grip.anchor_right = 1.0
	grip.anchor_bottom = 1.0
	grip.offset_left = -16.0
	grip.offset_top = -16.0
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.gui_input.connect(_on_grip_input)
	add_child(grip)


func pop_in() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 0.94
	modulate.a = 0.0
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.24)
	t.parallel().tween_property(self, "modulate:a", 1.0, 0.16)


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	pivot_offset = size / 2.0
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * 0.95, 0.14)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	t.tween_callback(queue_free)


func toggle_maximize() -> void:
	var target := _restore
	if not _maximized:
		_restore = Rect2(position, size)
		var area := get_parent_control().size
		target = Rect2(Vector2(6, TOP_LIMIT + 4), Vector2(area.x - 12, area.y - TOP_LIMIT - DOCK_SPACE))
	_maximized = not _maximized
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", target.position, 0.2)
	t.parallel().tween_property(self, "size", target.size, 0.2)


func _on_bar_input(event: InputEvent) -> void:
	var parent := get_parent_control()
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and mb.double_click:
			_drag = false
			toggle_maximize()
			return
		_drag = mb.pressed and not _maximized
		_grab = parent.get_local_mouse_position() - position
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _drag:
		var p := parent.get_local_mouse_position() - _grab
		p.x = clampf(p.x, -size.x + 80.0, parent.size.x - 80.0)
		p.y = clampf(p.y, TOP_LIMIT, parent.size.y - BAR_H)
		position = p


func _on_grip_input(event: InputEvent) -> void:
	var parent := get_parent_control()
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_resize = mb.pressed and not _maximized
		_grab = parent.get_local_mouse_position()
		_start_size = size
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _resize:
		var s := _start_size + parent.get_local_mouse_position() - _grab
		size = Vector2(maxf(s.x, MIN_SIZE.x), maxf(s.y, MIN_SIZE.y))
