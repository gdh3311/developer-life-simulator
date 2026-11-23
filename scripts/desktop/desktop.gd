extends Control
## WORKSTATION OS — the in-game operating system shown on the monitor.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const OSWindow := preload("res://scripts/desktop/os_window.gd")
const Apps := preload("res://scripts/desktop/apps.gd")

const TOPBAR_H := 30.0
const DOCK_H := 92.0

var apps: Array[Dictionary] = [
	{"id": "ide", "name": "DevIDE", "glyph": "</>", "color": Color("4f8cff"), "size": Vector2(880, 520)},
	{"id": "terminal", "name": "Terminal", "glyph": ">_", "color": Color("3ddc84"), "size": Vector2(660, 380)},
	{"id": "chat", "name": "TeamChat", "glyph": "@", "color": Color("f5a524"), "size": Vector2(740, 470)},
	{"id": "tasks", "name": "TaskBoard", "glyph": "#", "color": Color("c86bfa"), "size": Vector2(840, 440)},
	{"id": "wiki", "name": "Wiki", "glyph": "?", "color": Color("22c3c3"), "size": Vector2(620, 500)},
	{"id": "ai", "name": "AICode", "glyph": "AI", "color": Color("ff6b8a"), "size": Vector2(480, 300)},
]

var _windows: Control
var _toasts: VBoxContainer
var _clock: Label
var _boot: ColorRect
var _boot_log: Label
var _boot_logo: Label
var _open := {}  # app id -> window
var _dots := {}  # app id -> running indicator under the dock icon
var _cascade := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_wallpaper()
	_windows = Control.new()
	_windows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_windows)
	_build_topbar()
	_build_dock()
	_build_toasts()
	_build_boot_screen()
	Game.time_changed.connect(func(_d: int, _m: int) -> void: _clock.text = Game.clock_text() + "  ")
	Game.message.connect(notify)


## Clicking anywhere on a window brings it to the front.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var count := _windows.get_child_count()
	for i in range(count - 1, -1, -1):
		var w := _windows.get_child(i) as Control
		if w.get_global_rect().has_point(mb.position):
			if i != count - 1:
				w.move_to_front()
			return


# --- Apps & windows ---------------------------------------------------------

func open_app(id: String) -> void:
	if _open.has(id):
		(_open[id] as Control).move_to_front()
		return
	var app := _app(id)
	var win_size: Vector2 = app["size"]
	var win := OSWindow.new()
	win.setup(app["name"], app["color"], Apps.build(id), win_size)
	var pos := Vector2(50 + _cascade * 34, TOPBAR_H + 20 + _cascade * 28)
	pos.x = minf(pos.x, size.x - win_size.x - 10)
	win.position = pos
	_cascade = (_cascade + 1) % 6
	_windows.add_child(win)
	win.closed.connect(_on_window_closed.bind(id))
	_open[id] = win
	(_dots[id] as ColorRect).color = Color(1, 1, 1, 0.8)
	win.pop_in()


func _on_window_closed(id: String) -> void:
	_open.erase(id)
	(_dots[id] as ColorRect).color = Color(1, 1, 1, 0)


func _app(id: String) -> Dictionary:
	for a in apps:
		if a["id"] == id:
			return a
	return {}


# --- Notifications ----------------------------------------------------------

func notify(app_id: String, title: String, body: String) -> void:
	var app := _app(app_id)
	var accent: Color = app["color"]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.1, 0.11, 0.15, 0.96), 10, Color(accent, 0.5), 12, 1, 12))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UITheme.label("%s · %s" % [app["name"], title], 12, accent.lightened(0.3)))
	var text := UITheme.label(body, 13, Color("e6e8eb"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 290
	v.add_child(text)
	card.add_child(v)
	card.gui_input.connect(func(e: InputEvent) -> void:
		var click := e as InputEventMouseButton
		if click != null and click.pressed:
			open_app(app_id)
			_dismiss(card)
	)
	card.modulate.a = 0.0
	# Keep at most 4 visible: drop the oldest.
	var live := _toasts.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	if live.size() >= 4:
		live[0].queue_free()
	_toasts.add_child(card)
	create_tween().tween_property(card, "modulate:a", 1.0, 0.25)
	get_tree().create_timer(7.0).timeout.connect(_dismiss.bind(card))


func _dismiss(card) -> void:  # untyped: the card may already be freed
	if not is_instance_valid(card) or (card as Node).is_queued_for_deletion():
		return
	var t := create_tween()
	t.tween_property(card, "modulate:a", 0.0, 0.2)
	t.tween_callback(card.queue_free)


# --- Boot & first day -------------------------------------------------------

func boot() -> void:
	var lines := [
		"NEXORA Workstation BIOS v2.6.1",
		"CPU: 12-Core @ 3.8GHz .............. OK",
		"Memory: 32768 MB ................... OK",
		"Storage: NVMe 1TB .................. OK",
		"Network: corp-lan .................. CONNECTED",
	]
	for line in lines:
		_boot_log.text += str(line) + "\n"
		await get_tree().create_timer(0.16).timeout
	_boot_log.text += "Mounting workspace ~/commerce-api ... "
	var ws := await Workspace.prepare()
	_boot_log.text += ("OK" if ws["ok"] else "FAILED") + "\n\n"
	if not ws["ok"]:
		_boot_log.text += "[!] %s\n" % ws["message"]
		await get_tree().create_timer(2.0).timeout
	_boot_log.text += "Booting WORKSTATION OS...\n"
	await get_tree().create_timer(0.4).timeout
	var t := create_tween()
	t.tween_property(_boot_log, "modulate:a", 0.0, 0.3)
	t.tween_property(_boot_logo, "modulate:a", 1.0, 0.5)
	t.tween_interval(0.9)
	t.tween_property(_boot, "modulate:a", 0.0, 0.6)
	await t.finished
	_boot.queue_free()
	_start_first_day()


func _start_first_day() -> void:
	await get_tree().create_timer(0.8).timeout
	notify("chat", "Alex Kim", "NEXORA에 오신 걸 환영해요! 오늘 첫 출근이죠? 위키에서 프로젝트 개요부터 봐 주세요 :)")
	await get_tree().create_timer(2.5).timeout
	notify("tasks", "새 이슈 #001", "프로필 이름이 비어 있으면 화면에 'undefined'가 표시됩니다.")


# --- Layout -----------------------------------------------------------------

func _build_wallpaper() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color("10182b"))
	grad.set_color(1, Color("241536"))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 1)
	var wp := TextureRect.new()
	wp.texture = tex
	wp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wp.set_anchors_preset(Control.PRESET_FULL_RECT)
	wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wp)

	var logo := UITheme.label("NEXORA", 96, Color(1, 1, 1, 0.05))
	logo.add_theme_font_override("font", UITheme.font(false, true))
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(logo)


func _build_topbar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.05, 0.07, 0.85), 0, Color(0, 0, 0, 0), 6))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = TOPBAR_H
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	row.add_child(UITheme.label("  ◆  WORKSTATION OS", 12, Color("9aa4b5")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UITheme.label("Junior Developer · NEXORA", 12, Color("7c8698")))
	_clock = UITheme.label(Game.clock_text() + "  ", 13, Color("e6e8eb"), true)
	row.add_child(_clock)


func _build_dock() -> void:
	var holder := CenterContainer.new()
	holder.anchor_left = 0.0
	holder.anchor_right = 1.0
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_top = -DOCK_H
	holder.offset_bottom = -8.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", UITheme.box(Color(0.08, 0.09, 0.12, 0.78), 18, Color(1, 1, 1, 0.06), 10))
	holder.add_child(dock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	dock.add_child(row)
	for app in apps:
		row.add_child(_dock_item(app))


func _dock_item(app: Dictionary) -> Control:
	var c: Color = app["color"]
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var btn := Button.new()
	btn.text = app["glyph"]
	btn.tooltip_text = app["name"]
	btn.custom_minimum_size = Vector2(52, 52)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", UITheme.box(c.darkened(0.45), 14))
	btn.add_theme_stylebox_override("hover", UITheme.box(c.darkened(0.25), 14))
	btn.add_theme_stylebox_override("pressed", UITheme.box(c.darkened(0.6), 14))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(state, c.lightened(0.55))
	btn.add_theme_font_override("font", UITheme.font(true, true))
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(open_app.bind(app["id"]))
	btn.mouse_entered.connect(_bounce.bind(btn, 1.1))
	btn.mouse_exited.connect(_bounce.bind(btn, 1.0))
	btn.resized.connect(func() -> void: btn.pivot_offset = btn.size / 2.0)
	col.add_child(btn)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(6, 3)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.color = Color(1, 1, 1, 0)
	col.add_child(dot)
	_dots[app["id"]] = dot
	return col


func _bounce(node: Control, s: float) -> void:
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(node, "scale", Vector2.ONE * s, 0.15)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -334.0
	_toasts.offset_right = -14.0
	_toasts.offset_top = TOPBAR_H + 12.0
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


func _build_boot_screen() -> void:
	_boot = ColorRect.new()
	_boot.color = Color("050608")
	_boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_boot)
	_boot_log = UITheme.label("", 14, Color("9aa4b5"), true)
	_boot_log.position = Vector2(36, 30)
	_boot.add_child(_boot_log)
	_boot_logo = UITheme.label("WORKSTATION OS", 34, Color("e6e8eb"))
	_boot_logo.add_theme_font_override("font", UITheme.font(false, true))
	_boot_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boot_logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boot_logo.modulate.a = 0.0
	_boot.add_child(_boot_logo)
