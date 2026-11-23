extends Control
## A draggable, resizable application window inside WORKSTATION OS.
## Drag the title bar to move, double-click it to maximize, drag the corner to resize.

signal closed

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const BAR_H := 34.0
const MIN_SIZE := Vector2(320, 200)
const TOP_LIMIT := 30.0   # below the OS top bar
const DOCK_SPACE := 100.0 # keep the dock visible when maximized

var _drag := false
var _resize := false
var _grab := Vector2.ZERO
var _start_size := Vector2.ZERO
var _restore := Rect2()
var _maximized := false
var _closing := false


func setup(title: String, accent: Color, content: Control, win_size: Vector2) -> void:
	size = win_size

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UITheme.box(Color("1a1e26"), 10, Color("2d333f"), 0, 1, 24))
	add_child(bg)

	var bar := Panel.new()
	bar.anchor_right = 1.0
	bar.offset_bottom = BAR_H
	var bar_style := UITheme.box(Color("222733"), 10)
	bar_style.corner_radius_bottom_left = 0
	bar_style.corner_radius_bottom_right = 0
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.gui_input.connect(_on_bar_input)
	add_child(bar)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -6.0
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	var dot := ColorRect.new()
	dot.color = accent
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)
	var title_label := UITheme.label(title, 13, Color("c9cfd9"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_vertical = Control.SIZE_FILL
	row.add_child(title_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	row.add_child(close_btn)

	var body := MarginContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_top = BAR_H
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
	scale = Vector2.ONE * 0.92
	modulate.a = 0.0
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.22)
	t.parallel().tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	pivot_offset = size / 2.0
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * 0.94, 0.14)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	t.tween_callback(queue_free)


func toggle_maximize() -> void:
	var target := _restore
	if not _maximized:
		_restore = Rect2(position, size)
		var area := get_parent_control().size
		target = Rect2(Vector2(0, TOP_LIMIT), Vector2(area.x, area.y - TOP_LIMIT - DOCK_SPACE))
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
