extends Control
## A draggable, resizable application window inside WORKSTATION OS.
## Drag the title bar to move, double-click it to maximize, drag the corner to resize.

signal closed
signal minimized

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const BAR_H := 44.0
const FRAME_INSET := 4.0
const FOOT_H := 13.0
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
var _body: Control
var _grip: Control
var _title: Label
var _actions: HBoxContainer
var _maximize_button: Button
var _maximize_glyph: Control
var _frame_style: StyleBoxFlat
var _title_style: StyleBoxFlat
var _accent: Color
var _geometry_tween: Tween


func setup(id: String, title: String, accent: Color, icon_name: String, content: Control, win_size: Vector2) -> void:
	app_id = id
	_accent = accent
	size = win_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style = UITheme.box(Color("1c232c"), 10, Color("424e60"), 0)
	_frame_style.shadow_size = 20
	_frame_style.shadow_color = Color(0.02, 0.03, 0.05, 0.60)
	_frame_style.shadow_offset = Vector2(0, 8)
	frame.add_theme_stylebox_override("panel", _frame_style)
	add_child(frame)

	_bar = Panel.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = 1.0
	_bar.offset_right = -1.0
	_bar.offset_top = 1.0
	_bar.offset_bottom = BAR_H
	_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_title_style = UITheme.box(Color("252e3a"), 9, Color("364252"))
	_title_style.corner_radius_bottom_left = 0
	_title_style.corner_radius_bottom_right = 0
	_title_style.set_border_width_all(0)
	_title_style.border_width_bottom = 1
	_bar.add_theme_stylebox_override("panel", _title_style)
	_bar.gui_input.connect(_on_bar_input)
	add_child(_bar)

	var row := UITheme.hbox(9)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_right = -8.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(row)

	var mark := UITheme.panel(Color(_accent, 0.15), 6, 0, Color(_accent, 0.34))
	mark.custom_minimum_size = Vector2(27, 27)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centered_mark := CenterContainer.new()
	centered_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centered_mark.add_child(Icon.make(icon_name, _accent.lightened(0.18), 21 if icon_name == "relay" else 17))
	mark.add_child(centered_mark)
	row.add_child(mark)

	_title = UITheme.bold(title, 14, UITheme.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_title)
	_actions = UITheme.hbox(4)
	_actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_actions)

	var minimize := _title_button("minus", Game.L("최소화 (Ctrl+M)", "Minimize (Ctrl+M)"))
	minimize.pressed.connect(func() -> void: minimized.emit())
	_actions.add_child(minimize)
	_maximize_button = _title_button("maximize", Game.L("최대화", "Maximize"))
	_maximize_glyph = _maximize_button.get_child(0).get_child(0)
	_maximize_button.pressed.connect(toggle_maximize)
	_actions.add_child(_maximize_button)
	var dismiss := _title_button("x", Game.L("닫기 (Ctrl+W)", "Close (Ctrl+W)"), true)
	dismiss.pressed.connect(close)
	_actions.add_child(dismiss)

	# Plain Control keeps the viewport inside the frame even if an app has a large minimum size.
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.offset_top = BAR_H
	_body.offset_left = FRAME_INSET
	_body.offset_right = -FRAME_INSET
	_body.offset_bottom = -FOOT_H
	_body.clip_contents = true
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_body.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_grip = Control.new()
	_grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_grip.offset_left = -20.0
	_grip.offset_top = -19.0
	_grip.offset_right = -2.0
	_grip.offset_bottom = -2.0
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	var groove := Icon.make("resize_grip", Color("748396"), 13)
	_grip.add_child(groove)
	groove.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grip.gui_input.connect(_on_grip_input)
	add_child(_grip)
	set_active(false)


func _ready() -> void:
	get_parent_control().resized.connect(_fit_workspace)
	_fit_workspace()


func _title_button(icon_name: String, tooltip: String, danger := false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(30, 28)
	button.tooltip_text = tooltip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var hover := Color("652f3b") if danger else Color("394656")
	var pressed := Color("873d4c") if danger else Color("47596c")
	button.add_theme_stylebox_override("normal", UITheme.box(Color("202834"), 5, Color("384454")))
	button.add_theme_stylebox_override("hover", UITheme.box(hover, 5))
	button.add_theme_stylebox_override("pressed", UITheme.box(pressed, 5))
	button.add_theme_stylebox_override("focus", UITheme.box(Color.TRANSPARENT, 5, _accent))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(Icon.make(icon_name, Color("d0dbe8"), 15))
	return button


func set_active(active: bool) -> void:
	_frame_style.border_color = Color("667689") if active else Color("374353")
	_title_style.bg_color = Color("293442").lerp(_accent, 0.07) if active else Color("212933")
	_title.add_theme_color_override("font_color", UITheme.TEXT if active else UITheme.TEXT2)


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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()
	pivot_offset = size / 2.0
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * 0.95, 0.14)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	t.tween_callback(queue_free)


func _workspace() -> Rect2:
	var area := get_parent_control().size
	var origin := Vector2(8, TOP_LIMIT + 6)
	return Rect2(origin, Vector2(maxf(1, area.x - 16), maxf(1, area.y - origin.y - DOCK_SPACE)))


func _fit_rect(requested: Rect2) -> Rect2:
	var usable := _workspace()
	var fitted_size := requested.size.clamp(MIN_SIZE.min(usable.size), usable.size)
	var fitted_position := requested.position.clamp(usable.position, usable.end - fitted_size)
	return Rect2(fitted_position, fitted_size)


func _fit_workspace() -> void:
	if _geometry_tween:
		_geometry_tween.kill()
	var fitted := _workspace() if _maximized else _fit_rect(Rect2(position, size))
	position = fitted.position
	size = fitted.size


func toggle_maximize() -> void:
	if _closing:
		return
	var moving := _geometry_tween != null and _geometry_tween.is_running()
	if _geometry_tween:
		_geometry_tween.kill()
	if not _maximized and not moving:
		_restore = Rect2(position, size)
	var target := _fit_rect(_restore) if _maximized else _workspace()
	_maximized = not _maximized
	_drag = false
	_resize = false
	_maximize_glyph.icon = "restore" if _maximized else "maximize"
	_maximize_glyph.queue_redraw()
	_maximize_button.tooltip_text = Game.L("원래 크기로 복원", "Restore window") if _maximized else Game.L("최대화", "Maximize")
	_grip.visible = not _maximized
	_geometry_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_geometry_tween.tween_property(self, "position", target.position, 0.18)
	_geometry_tween.parallel().tween_property(self, "size", target.size, 0.18)


func _on_bar_input(event: InputEvent) -> void:
	var parent := get_parent_control()
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and mb.double_click:
			_drag = false
			toggle_maximize()
			return
		_drag = mb.pressed and not _maximized
		if _drag and _geometry_tween:
			_geometry_tween.kill()
		_grab = parent.get_local_mouse_position() - position
		return
	if event is InputEventMouseMotion and _drag:
		position = _fit_rect(Rect2(parent.get_local_mouse_position() - _grab, size)).position


func _on_grip_input(event: InputEvent) -> void:
	var parent := get_parent_control()
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_resize = mb.pressed and not _maximized
		if _resize and _geometry_tween:
			_geometry_tween.kill()
		_grab = parent.get_local_mouse_position()
		_start_size = size
		return
	if event is InputEventMouseMotion and _resize:
		var desired := _start_size + parent.get_local_mouse_position() - _grab
		var available := (_workspace().end - position).max(Vector2.ONE)
		size = desired.clamp(MIN_SIZE.min(available), available)
