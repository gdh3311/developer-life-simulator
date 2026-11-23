extends Control
## WORKSTATION OS — the in-game operating system shown on the monitor.

signal booted

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const OSWindow := preload("res://scripts/desktop/os_window.gd")
const Apps := preload("res://scripts/desktop/apps.gd")

const TOPBAR_H := 32.0
const DOCK_H := 86.0

var apps: Array[Dictionary] = [
	{"id": "ide", "name": "DevIDE", "icon": "code", "color": Color("5b8cff"), "size": Vector2(900, 540)},
	{"id": "terminal", "name": "Terminal", "icon": "terminal", "color": Color("3ddc84"), "size": Vector2(720, 420)},
	{"id": "codehub", "name": "CodeHub", "icon": "pr", "color": Color("a78bfa"), "size": Vector2(940, 560)},
	{"id": "chat", "name": "TeamChat", "icon": "chat", "color": Color("f5a524"), "size": Vector2(800, 520)},
	{"id": "tasks", "name": "TaskBoard", "icon": "tasks", "color": Color("ec4899"), "size": Vector2(900, 520)},
	{"id": "lab", "name": "Request Lab", "icon": "lab", "color": Color("2dd4bf"), "size": Vector2(860, 560)},
	{"id": "wiki", "name": "Wiki", "icon": "wiki", "color": Color("22c3c3"), "size": Vector2(800, 540)},
	{"id": "monitor", "name": "Monitor", "icon": "monitor", "color": Color("ff6b6b"), "size": Vector2(860, 520)},
	{"id": "ai", "name": "AICode", "icon": "ai", "color": Color("c084fc"), "size": Vector2(600, 500)},
	{"id": "browser", "name": "Browser", "icon": "globe", "color": Color("38bdf8"), "size": Vector2(880, 560)},
	{"id": "dashboard", "name": "Dashboard", "icon": "dashboard", "color": Color("94a3b8"), "size": Vector2(860, 540)},
]

var _windows: Control
var _toasts: VBoxContainer
var _pills: VBoxContainer
var _clock: Label
var _mission_chip: Label
var _status_label: Label
var _end_day_btn: Button
var _guide: PanelContainer
var _guide_body: VBoxContainer
var _boot: ColorRect
var _boot_log: Label
var _boot_logo: Control
var _overlay: Control
var _alert: ColorRect
var _open := {}
var _dots := {}
var _badges := {}
var _dock_buttons := {}
var _cascade := 0
var _chapter_done := false
var _content_done := false
var _slack_time := 0.0
var _walkby_cooldown := 25.0
var _walkby_active := false
var _highlight := ""
var _pulse := 0.0
var _day_transitioning := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_wallpaper()
	_windows = Control.new()
	_windows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_windows)
	_build_topbar()
	_build_dock()
	_build_guide()
	_build_toasts()
	_alert = ColorRect.new()
	_alert.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alert.color = Color(1, 0.2, 0.2, 0)
	_alert.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_alert)
	_build_boot_screen()

	Game.time_changed.connect(func(_d: int, _m: int) -> void: _clock.text = Game.clock_text())
	Game.toast.connect(notify)
	Game.relation_changed.connect(_on_relation)
	Game.chat_added.connect(func(_m: Dictionary) -> void: _update_badges())
	Game.chat_updated.connect(_update_badges)
	Game.condition_changed.connect(_update_status)
	Game.wallet_changed.connect(_update_status)
	CodeHub.pr_changed.connect(func(_id: int) -> void: _update_badges())
	CodeHub.prs_changed.connect(_update_badges)
	Story.objectives_changed.connect(_on_objectives_changed)
	Game.day_finished.connect(_on_day_finished)
	Story.chapter_finished.connect(func() -> void: _chapter_done = true)
	Story.content_paused.connect(func() -> void: _content_done = true)


func _process(delta: float) -> void:
	# Tutorial: pulse the dock icon of the app the current step needs.
	_pulse += delta
	for id in _dock_buttons:
		var b: Control = _dock_buttons[id]
		if id == _highlight and not _open.has(id):
			b.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.6, 1.6), 0.5 + 0.5 * sin(_pulse * 5.0))
		else:
			b.modulate = Color.WHITE
	_check_slacking(delta)


## Clicking anywhere on a window brings it to the front.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode != KEY_F2:
		Sfx.type_key(key.keycode)
		if key.ctrl_pressed and _overlay == null and not (is_instance_valid(_boot) and _boot.visible and not _boot.is_queued_for_deletion()):
			# Ctrl+1..0 opens dock apps, Ctrl+W closes, Ctrl+M minimizes the front window.
			var digit := key.keycode - KEY_1 if key.keycode >= KEY_1 and key.keycode <= KEY_9 else (9 if key.keycode == KEY_0 else -1)
			if digit >= 0 and digit < apps.size():
				open_app(apps[digit]["id"])
				get_viewport().set_input_as_handled()
				return
			var front := top_window_app()
			if front != "" and key.keycode == KEY_W:
				(_open[front] as Control).close()
				get_viewport().set_input_as_handled()
				return
			if front != "" and key.keycode == KEY_M:
				minimize(front)
				get_viewport().set_input_as_handled()
				return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		Sfx.play("click", randf_range(0.95, 1.05), -12.0)
	var count := _windows.get_child_count()
	for i in range(count - 1, -1, -1):
		var w := _windows.get_child(i) as Control
		if w.get_global_rect().has_point(mb.position):
			if i != count - 1:
				w.move_to_front()
			return


# --- Apps & windows ---------------------------------------------------------

func open_app(id: String) -> void:
	Game.emit_event("app_opened", {"app": id})
	if _open.has(id):
		var w: Control = _open[id]
		if not w.visible:
			w.visible = true
			w.move_to_front()
			Sfx.play("window", 1.1, -8.0)
			w.pop_in()
		elif top_window_app() == id:
			minimize(id)
		else:
			w.move_to_front()
		return
	var app := _app(id)
	var win_size: Vector2 = app["size"]
	var win := OSWindow.new()
	win.setup(id, app["name"], app["color"], app["icon"], Apps.build(id, self), win_size)
	var pos := Vector2(40 + _cascade * 30, TOPBAR_H + 14 + _cascade * 22)
	pos.x = clampf(pos.x, 6, size.x - win_size.x - 6)
	pos.y = clampf(pos.y, TOPBAR_H + 4, maxf(TOPBAR_H + 4, size.y - DOCK_H - win_size.y))
	win.position = pos
	_cascade = (_cascade + 1) % 6
	_windows.add_child(win)
	win.closed.connect(_on_window_closed.bind(id))
	win.minimized.connect(minimize.bind(id))
	_open[id] = win
	(_dots[id] as Control).modulate.a = 1.0
	Sfx.play("window", 1.1, -6.0)
	win.pop_in()


## Hide a window into the dock (click the dock icon to bring it back).
func minimize(id: String) -> void:
	if not _open.has(id):
		return
	var w: Control = _open[id]
	Sfx.play("window", 0.85, -10.0)
	w.pivot_offset = Vector2(w.size.x / 2.0, w.size.y)
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(w, "scale", Vector2.ONE * 0.6, 0.16)
	t.parallel().tween_property(w, "modulate:a", 0.0, 0.16)
	t.tween_callback(func() -> void:
		w.visible = false
		w.scale = Vector2.ONE
		w.modulate.a = 1.0)


func close_all() -> void:
	for id in _open.keys():
		(_open[id] as Control).queue_free()
		_on_window_closed(id)
	_open.clear()


## Source shortcuts only navigate; they never execute terminal commands.
func open_resource(app_id: String, target: String) -> void:
	open_app(app_id)
	var method := {"wiki": "open_page", "ide": "open_file", "codehub": "open_mission_diff"}.get(app_id, "") as String
	if method != "":
		var content := _find_method(_open[app_id], method)
		if content != null:
			content.call(method, Story.active.id if app_id == "codehub" and Story.active != null else target)


func _on_window_closed(id: String) -> void:
	if _open.has(id):
		Sfx.play("window", 0.8, -8.0)
	_open.erase(id)
	(_dots[id] as Control).modulate.a = 0.0


func _app(id: String) -> Dictionary:
	for a in apps:
		if a["id"] == id:
			return a
	return {}


func top_window_app() -> String:
	var n := _windows.get_child_count()
	for i in range(n - 1, -1, -1):
		var w = _windows.get_child(i)
		if not w.is_queued_for_deletion() and w.visible:
			return w.app_id
	return ""


# --- Slacking & the boss walk-by -----------------------------------------------------

func _is_slacking() -> bool:
	if top_window_app() != "browser" or not _open.has("browser"):
		return false
	var b = _find_method(_open["browser"], "is_slacking")
	return b != null and b.is_slacking()


func _check_slacking(delta: float) -> void:
	if _walkby_active or _overlay != null or Story.active == null or Game.state["day_done"] or not Game.walkby_enabled:
		return
	_walkby_cooldown -= delta
	if not _is_slacking():
		_slack_time = maxf(0.0, _slack_time - delta)
		return
	_slack_time += delta
	if _walkby_cooldown <= 0.0 and _slack_time > 6.0 and randf() < delta / 12.0:
		_walkby()


func _walkby() -> void:
	_walkby_active = true
	var boss := "alex" if Game.day() >= 4 else "daniel"
	Sfx.footsteps(7, 0.45)
	Sfx.play("heart", 1.0, -2.0)
	_main_call("boss_pass")
	notify("dashboard", Game.L("누군가 다가오는 발소리...", "Footsteps behind you..."), Game.L("%s 님이 자리 쪽으로 걸어옵니다! 업무 화면으로 바꾸세요!", "%s is walking toward your desk! Switch to something work-related!") % Game.npc_name(boss))
	var t := create_tween().set_loops(3)
	t.tween_property(_alert, "color:a", 0.16, 0.35)
	t.tween_property(_alert, "color:a", 0.0, 0.35)
	await get_tree().create_timer(3.2).timeout
	if _is_slacking():
		Game.emit_event("caught", {})
		_main_call("shake", 14.0)
		Game.inc_stat("caught_slacking")
		var n := Game.stat("caught_slacking")
		Game.relate(boss, {"work": -6 * n, "agree": -2})
		Game.say(boss, Game.LL("...업무 시간이에요. 지금 하는 일부터 마무리해 주세요." if n == 1 else "또요? 이건 평가에 반영할 수밖에 없어요.",
			"...It's work time. Please finish what you're on first." if n == 1 else "Again? I'll have to factor this into your review."))
	else:
		Sfx.play("relief")
		notify("dashboard", Game.L("휴...", "Phew..."), Game.L("안 들켰다.", "Not caught."))
	_slack_time = 0.0
	_walkby_cooldown = 45.0
	_walkby_active = false


func _find_method(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var f := _find_method(c, method)
		if f != null:
			return f
	return null


# --- Notifications ----------------------------------------------------------

func notify(app_id: String, title: String, body: String) -> void:
	var app := _app(app_id)
	if app.is_empty():
		app = {"name": "NEXORA", "color": UITheme.TEXT2, "icon": "bell"}
	var accent: Color = app["color"]
	var card := PanelContainer.new()
	var sb := UITheme.box(Color(0.09, 0.1, 0.14, 0.97), 12, Color(1, 1, 1, 0.08), 12, 1, 0)
	sb.shadow_size = 16
	sb.shadow_color = Color(0, 0, 0, 0.4)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := UITheme.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var npc := _npc_from_title(title)
	if (app_id == "chat" or app_id == "browser") and npc != "":
		row.add_child(UITheme.avatar(npc, 30))
	else:
		var holder := PanelContainer.new()
		holder.add_theme_stylebox_override("panel", UITheme.box(Color(accent, 0.18), 8, Color(0, 0, 0, 0), 6))
		holder.add_child(Icon.make(app["icon"], accent, 18))
		holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(holder)
	var v := UITheme.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UITheme.hbox(6)
	head.add_child(UITheme.bold(title, 12, accent.lightened(0.35)))
	head.add_child(UITheme.label("· " + String(app["name"]), 11, UITheme.MUTED))
	v.add_child(head)
	var text := UITheme.label(body if body.length() < 140 else body.left(137) + "...", 13, UITheme.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 250
	v.add_child(text)
	row.add_child(v)
	card.add_child(row)
	card.gui_input.connect(func(e: InputEvent) -> void:
		var click := e as InputEventMouseButton
		if click != null and click.pressed:
			if _app(app_id).size() > 0:
				open_app(app_id)
			_dismiss(card)
	)
	card.modulate.a = 0.0
	var live := _toasts.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	if live.size() >= 4:
		live[0].queue_free()
	_toasts.add_child(card)
	card.pivot_offset = Vector2(330, 0)
	card.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_property(card, "scale", Vector2.ONE, 0.3)
	get_tree().create_timer(7.0).timeout.connect(_dismiss.bind(card))


func _npc_from_title(title: String) -> String:
	for id in Game.NPCS:
		if Game.NPCS[id]["name"] == title:
			return id
	return ""


func _dismiss(card) -> void:  # untyped: the card may already be freed
	if not is_instance_valid(card) or (card as Node).is_queued_for_deletion():
		return
	var t := create_tween()
	t.tween_property(card, "modulate:a", 0.0, 0.2)
	t.tween_callback(card.queue_free)


func _on_relation(npc: String, key: String, delta: int) -> void:
	if delta == 0:
		return
	var good := delta > 0
	var pill := PanelContainer.new()
	var c := UITheme.OK if good else UITheme.ERR
	var sb := UITheme.box(Color(0.06, 0.07, 0.1, 0.92), 14, Color(c, 0.6), 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", sb)
	pill.add_child(UITheme.label("%s  ·  %s %s%d" % [Game.npc_name(npc), Game.rel_label(key), "+" if good else "", delta], 12, c.lightened(0.2)))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pills.add_child(pill)
	var t := create_tween()
	t.tween_interval(2.6)
	t.tween_property(pill, "modulate:a", 0.0, 0.4)
	t.tween_callback(pill.queue_free)


func _update_badges() -> void:
	var unread := 0
	for ch in Game.state["unread"]:
		if ch != "connectly":
			unread += int(Game.state["unread"][ch])
	_set_badge("chat", unread)
	_set_badge("browser", int(Game.state["unread"].get("connectly", 0)))
	var pending := 0
	for p in CodeHub.prs():
		if p["state"] != "open":
			continue
		if p["flags"].get("needs_my_comment", false):
			pending += 1
		elif p["author"] == "me" and p["review"]["state"] == "changes":
			pending += 1
	_set_badge("codehub", pending)


func _set_badge(id: String, n: int) -> void:
	if not _badges.has(id):
		return
	var b: PanelContainer = _badges[id]
	b.visible = n > 0
	(b.get_child(0) as Label).text = str(n) if n < 10 else "9+"


func _update_status() -> void:
	var c := Game.condition()
	var col := UITheme.OK if c >= 60 else (UITheme.WARN if c >= 25 else UITheme.ERR)
	_status_label.text = "%s %d%%   %s" % [Game.L("컨디션", "Energy"), c, Game.won(Game.money())]
	_status_label.add_theme_color_override("font_color", col.lightened(0.2))


func _on_objectives_changed() -> void:
	var m = Story.active
	if m == null:
		_mission_chip.text = Game.L("오늘 업무 완료", "Done for today") if Game.state["day_done"] else Game.L("업무 없음", "No task")
	else:
		var done: int = m.objectives.filter(func(o: Dictionary) -> bool: return m.is_done(o["id"])).size()
		_mission_chip.text = "%s%s  ·  %d/%d" % [(m.issue + " ") if m.issue != "" else "", m.title_text(), done, m.objectives.size()]
	_render_guide()


# --- Tutorial guide ---------------------------------------------------------------

func _build_guide() -> void:
	_guide = PanelContainer.new()
	var sb := UITheme.box(Color(0.07, 0.09, 0.14, 0.96), 12, Color(UITheme.ACCENT, 0.5), 14, 1, 0)
	sb.shadow_size = 18
	sb.shadow_color = Color(0, 0, 0, 0.4)
	_guide.add_theme_stylebox_override("panel", sb)
	_guide.anchor_top = 1.0
	_guide.anchor_bottom = 1.0
	_guide.offset_left = 12
	_guide.offset_top = -DOCK_H - 10
	_guide.offset_right = 352
	_guide.offset_bottom = -DOCK_H - 10
	_guide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_guide.visible = false
	_guide_body = UITheme.vbox(6)
	_guide.add_child(_guide_body)
	add_child(_guide)


func _render_guide() -> void:
	var m = Story.active
	if m == null or not m.tutorial:
		_guide.visible = false
		_highlight = ""
		return
	var o: Dictionary = m.current_objective()
	if o.is_empty():
		_guide.visible = false
		_highlight = ""
		return
	_guide.visible = true
	_highlight = String(o.get("app", ""))
	UITheme.clear(_guide_body)
	var head := UITheme.hbox(8)
	head.add_child(Icon.make("ai", UITheme.ACCENT, 14))
	var done: int = m.objectives.filter(func(x: Dictionary) -> bool: return m.is_done(x["id"])).size()
	head.add_child(UITheme.bold(Game.L("튜토리얼  %d/%d", "Tutorial  %d/%d") % [done + 1, m.objectives.size()], 12, UITheme.ACCENT.lightened(0.3)))
	_guide_body.add_child(head)
	_guide_body.add_child(UITheme.wrap(Game.tx(o["text"]), 14, UITheme.TEXT))
	if o.has("guide"):
		var g := UITheme.label(Game.tx(o["guide"]), 12, UITheme.TEXT2)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g.custom_minimum_size.x = 300
		if "\n  " in Game.tx(o["guide"]):
			g.add_theme_font_override("font", UITheme.font(true))
		_guide_body.add_child(g)
	_guide.modulate.a = 0.0
	create_tween().tween_property(_guide, "modulate:a", 1.0, 0.3)


# --- Boot ---------------------------------------------------------------------

func boot() -> void:
	if Workspace.exists() != Game.has_save():
		_boot_log.text += Game.L("작업 저장소와 진행 파일 중 하나를 찾을 수 없습니다. 기존 파일은 유지했습니다.\n", "The repository or progress file is missing. Existing files were retained.\n")
		_show_load_recovery()
		return
	if not Game.has_settings() or not (Workspace.exists() and Game.has_save()):
		await _first_run_setup()
	var lines := [
		"NEXORA Workstation BIOS v2.6.1",
		"CPU: 12-Core @ 3.8GHz .............. OK",
		"Memory: 32768 MB ................... OK",
		"Network: corp-lan .................. CONNECTED",
	]
	for line in lines:
		_boot_log.text += str(line) + "\n"
		await get_tree().create_timer(0.1).timeout
	var continuing := Workspace.exists() and Game.has_save()
	if Workspace.exists() and not continuing:
		Workspace.wipe()
	if continuing:
		if not Game.load_game():
			_boot_log.text += Game.L("\n저장 파일을 읽지 못했습니다. 원본과 백업은 유지했습니다.\n", "\nCould not read the save. Original and backup files were retained.\n")
			_boot_log.text += Game.L("저장 버전 또는 파일 상태를 확인한 뒤 다시 실행해 주세요.", "Check the save version or file contents, then restart.")
			_show_load_recovery()
			return
		if Game.last_load_recovered:
			_boot_log.text += Game.L("이전 백업에서 진행을 복구했습니다.\n", "Progress recovered from the previous backup.\n")
	_boot_log.text += "Mounting /home/newhire ................ "
	var ws := await Workspace.prepare()
	_boot_log.text += ("OK" if ws["ok"] else "FAILED") + "\n"
	if not ws["ok"]:
		_boot_log.text += "\n[!] %s\n" % ws["message"]
		return
	if continuing:
		_boot_log.text += "Restoring session (DAY %d) ............. OK\n" % Game.day()
	_boot_log.text += "\nBooting WORKSTATION OS...\n"
	await get_tree().create_timer(0.3).timeout
	var t := create_tween()
	t.tween_property(_boot_log, "modulate:a", 0.0, 0.3)
	t.tween_callback(func() -> void: Sfx.play("boot"))
	t.tween_property(_boot_logo, "modulate:a", 1.0, 0.5)
	t.tween_interval(0.7)
	t.tween_property(_boot, "modulate:a", 0.0, 0.6)
	await t.finished
	_boot.queue_free()
	_clock.text = Game.clock_text()
	_update_status()
	_end_day_btn.text = Game.L("퇴근하기", "Clock out")
	Sfx.start_music()
	Game.event.connect(_on_fx_event)
	booted.emit()
	if continuing and Workspace.restore_changed:
		Game.notify("dashboard", Game.L("저장된 상태와 Git 상태가 다릅니다", "Git changed since the saved checkpoint"), Game.L("현재 파일과 커밋은 유지했습니다. 진행 중인 PR과 CI를 다시 확인합니다.", "Current files and commits were preserved. Pending PRs and CI will be checked again."))
	_update_badges()
	if continuing:
		Story.resume()
		if Game.state["day_done"]:
			_on_day_finished(Game.day())
	else:
		Story.start_new()
	_on_objectives_changed()


func _show_load_recovery() -> void:
	var actions := UITheme.vbox(10)
	actions.position = Vector2(36, 250)
	actions.custom_minimum_size.x = 650
	_boot.add_child(actions)
	actions.add_child(UITheme.wrap(Game.L("진행을 임의로 초기화하지 않았습니다. 파일을 복구한 뒤 다시 시도하거나, 두 번 확인하고 새 게임을 시작할 수 있어요.", "Progress was not reset. Restore the files and retry, or confirm a new game in two steps."), 14, UITheme.TEXT2))
	var retry := UITheme.button(Game.L("다시 읽기", "Retry loading"), "primary")
	retry.pressed.connect(func() -> void: get_tree().reload_current_scene())
	actions.add_child(retry)
	var reset := UITheme.button(Game.L("새 게임 시작…", "Start a new game…"))
	var confirmed := [false]
	reset.pressed.connect(func() -> void:
		if not confirmed[0]:
			confirmed[0] = true
			reset.text = Game.L("진행과 회사 저장소를 모두 지우고 새로 시작", "Delete progress and the company repository, then start over")
			return
		if Game.new_game():
			get_tree().reload_current_scene())
	actions.add_child(reset)


## First run: pick a language and enter your name.
func _first_run_setup() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot.add_child(center)
	var v := UITheme.vbox(14)
	v.custom_minimum_size.x = 420
	center.add_child(v)
	var title := UITheme.bold("", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(UITheme.label("Language / 언어", 12, UITheme.MUTED))
	var langs := UITheme.hbox(10)
	var ko := UITheme.button("한국어")
	var en := UITheme.button("English")
	for b in [ko, en]:
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		langs.add_child(b)
	v.add_child(langs)
	var name_label := UITheme.label("", 12, UITheme.MUTED)
	v.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.max_length = 20
	name_edit.custom_minimum_size.y = 38
	v.add_child(name_edit)
	var start := UITheme.button("", "ok")
	start.custom_minimum_size.y = 42
	v.add_child(start)
	var refresh := func() -> void:
		name_label.text = Game.L("이름 (사내 메신저와 커밋에 표시됩니다)", "Your name (shown in chat and commits)")
		name_edit.placeholder_text = Game.L("예: 김개발", "e.g. Alex Doe")
		start.text = Game.L("입사하기  →", "Start your first day  →")
		title.text = Game.L("NEXORA 입사를 환영합니다", "Welcome to NEXORA")
		var on := UITheme.box(UITheme.ACCENT.darkened(0.15), 7, Color(0, 0, 0, 0), 7)
		var off := UITheme.box(UITheme.BG3, 7, UITheme.LINE, 7)
		ko.add_theme_stylebox_override("normal", on if Game.lang == "ko" else off)
		en.add_theme_stylebox_override("normal", on if Game.lang == "en" else off)
	ko.pressed.connect(func() -> void:
		Game.set_language("ko")
		refresh.call())
	en.pressed.connect(func() -> void:
		Game.set_language("en")
		refresh.call())
	refresh.call()
	var done := [false]
	var submit := func() -> void:
		Game.set_language(Game.lang)
		var n := name_edit.text.strip_edges()
		Game.state["player_name"] = n if n != "" else "New Hire"
		Game.state["repo_lang"] = Game.lang
		done[0] = true
	start.pressed.connect(submit)
	name_edit.text_submitted.connect(func(_t: String) -> void: submit.call())
	name_edit.call_deferred("grab_focus")
	while not done[0]:
		await get_tree().process_frame
	center.queue_free()


# --- Day cycle ----------------------------------------------------------------

func _on_day_finished(_d: int) -> void:
	_end_day_btn.visible = true
	_on_objectives_changed()
	notify("dashboard", Game.L("오늘 업무 완료", "Done for today"), Game.L("상단의 '퇴근하기' 버튼을 눌러 하루를 마무리하세요.", "Press 'Clock out' at the top to wrap up the day."))


func _show_day_summary() -> void:
	if _overlay != null:
		return
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0.02, 0.03, 0.05, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card := UITheme.panel(UITheme.BG1, 16, 26, Color(1, 1, 1, 0.08))
	card.custom_minimum_size = Vector2(640, 0)
	center.add_child(card)
	var v := UITheme.vbox(12)
	card.add_child(v)
	v.add_child(UITheme.label(Game.date_text(), 12, UITheme.MUTED))
	v.add_child(UITheme.bold(Game.L("업무 종료  ·  %s 퇴근", "Clocking out at %s") % Game.time_text(), 24))

	var today: Dictionary = Game.state["stats_today"]
	var stats := UITheme.hbox(8)
	for s in [["commits", Game.L("커밋", "Commits")], ["test_runs", Game.L("테스트", "Test runs")], ["ci_pass", Game.L("CI 통과", "CI green")],
			["ci_fail", Game.L("CI 실패", "CI red")], ["merges", Game.L("병합", "Merged")], ["caught_slacking", Game.L("딴짓 적발", "Caught")]]:
		var box := UITheme.panel(UITheme.BG2, 10, 10, Color(0, 0, 0, 0))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bv := UITheme.vbox(0)
		var val := int(today.get(s[0], 0))
		var n := UITheme.bold(str(val), 22, UITheme.ERR if s[0] == "caught_slacking" and val > 0 else UITheme.TEXT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(n)
		var l := UITheme.label(s[1], 11, UITheme.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(l)
		box.add_child(bv)
		stats.add_child(box)
	v.add_child(stats)
	var investigations_today := Cases.archive().filter(func(id: String) -> bool: return int(Cases.record(id)["day"]) == Game.day()).size()
	if investigations_today > 0:
		v.add_child(UITheme.wrap(Game.L("오늘 조사 %d개를 정리했어요. Dashboard에서 가설과 배운 점을 다시 볼 수 있습니다.", "Filed %d investigations today. Revisit your hypotheses and lessons in Dashboard.") % investigations_today, 13, UITheme.ACCENT.lightened(0.3)))

	v.add_child(UITheme.label(Game.L("오늘의 팀 관계 변화", "Team relationships today"), 12, UITheme.MUTED))
	var rel_today: Dictionary = Game.state["rel_today"]
	if rel_today.is_empty():
		v.add_child(UITheme.label(Game.L("변화 없음", "No change"), 13, UITheme.TEXT2))
	for npc in rel_today:
		var row := UITheme.hbox(10)
		row.add_child(UITheme.avatar(npc, 26))
		var nl := UITheme.label(Game.npc_name(npc), 13, UITheme.TEXT)
		nl.custom_minimum_size.x = 110
		row.add_child(nl)
		var chips := HFlowContainer.new()
		chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for key in rel_today[npc]:
			var dv := int(rel_today[npc][key])
			if dv != 0:
				chips.add_child(UITheme.chip("%s %s%d" % [Game.rel_label(key), "+" if dv > 0 else "", dv], UITheme.OK if dv > 0 else UITheme.ERR))
		row.add_child(chips)
		v.add_child(row)
	var salary: int = Game.SALARY[clampi(Game.state["rank"], 0, Game.SALARY.size() - 1)]
	v.add_child(UITheme.label((Game.L("오늘 급여 지급 완료 · %s", "Today's pay already received · %s") if Game.state["salary_days"].has(str(Game.day())) else Game.L("오늘 급여 +%s", "Today's pay +%s")) % Game.won(salary), 13, UITheme.OK))

	var btn := UITheme.button(Game.L("챕터 결과 보기", "Chapter result") if _chapter_done else (Game.L("현재 구간 정리", "Review this segment") if _content_done else Game.L("다음 날 출근하기  →", "Next day  →")), "primary")
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(_on_next_day)
	v.add_child(btn)
	card.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_overlay, "color:a", 0.85, 0.4)
	t.tween_property(card, "modulate:a", 1.0, 0.4)


func _on_next_day() -> void:
	if _day_transitioning:
		return
	_day_transitioning = true
	if _chapter_done:
		Game.claim_salary()
		_show_ending()
		return
	if _content_done:
		Game.claim_salary()
		_show_content_summary()
		return
	_advance_workday()


func _continue_chapter() -> void:
	if not Story.can_continue_chapter() or not _chapter_done or not _day_transitioning:
		return
	_chapter_done = false
	_content_done = false
	_advance_workday()


func _advance_workday() -> void:
	var t := create_tween()
	t.tween_property(_overlay, "color:a", 1.0, 0.5)
	t.parallel().tween_property(_overlay.get_child(0), "modulate:a", 0.0, 0.3)
	await t.finished
	close_all()
	var main := get_tree().current_scene
	if main != null and main.has_method("night_transition"):
		await main.night_transition()
	Game.next_day()
	if main != null and main.has_method("morning_transition"):
		await main.morning_transition()
	Sfx.play("morning")
	_end_day_btn.visible = false
	UITheme.clear(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var title := UITheme.bold(Game.date_text() + "   09:00", 30, UITheme.TEXT)
	center.add_child(title)
	_overlay.add_child(center)
	title.modulate.a = 0.0
	var t2 := create_tween()
	t2.tween_property(title, "modulate:a", 1.0, 0.5)
	t2.tween_interval(1.2)
	t2.tween_property(_overlay, "modulate:a", 0.0, 0.6)
	await t2.finished
	_overlay.queue_free()
	_overlay = null
	_day_transitioning = false
	Story.start_day(Game.day())
	_on_objectives_changed()


func _show_ending() -> void:
	if Game.chapter() >= 2:
		_show_chapter2_ending()
		return
	UITheme.clear(_overlay)
	Sfx.play("promote")
	confetti(220)
	(_overlay as ColorRect).color = Color(0.02, 0.03, 0.05, 0.96)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var v := UITheme.vbox(14)
	center.add_child(v)
	var left: bool = Game.state["flags"].get("ending", "") == "left"
	var promoted: bool = int(Game.state["rank"]) >= 1
	var interviewing: bool = left and Game.state["flags"].get("offer_stage", "") == "interview"
	var headline := (Game.L("Brightloop 면담을 이어 갑니다", "Continuing talks with Brightloop") if interviewing else Game.L("Brightloop으로 이직합니다", "You're moving to Brightloop")) if left else (
		Game.L("NEXORA 정규직 전환!", "Full-time at NEXORA!") if promoted else Game.L("인턴 기간이 연장되었습니다", "Your internship was extended"))
	var sub := (Game.L("현재 업무를 이어 가며 다음 기회를 알아봅니다.", "Keep building experience while exploring the next opportunity.") if interviewing else Game.L("NEXORA에서 배운 것들이 다음 커리어의 밑거름이 될 거예요.", "What you learned at NEXORA will carry your next role.")) if left else (
		Game.L("인턴으로 시작해 4일 만에 팀의 신뢰를 얻었습니다.", "You started as an intern and earned the team's trust in four days.") if promoted
		else Game.L("다음 달에는 더 많은 신뢰를 쌓아 보세요.", "Build more trust next month."))
	for lab in [
		UITheme.label("CHAPTER 1  —  " + Game.L("인턴의 첫 주", "THE INTERN WEEK"), 13, UITheme.ACCENT),
		UITheme.bold(headline, 28),
		UITheme.label(sub, 15, UITheme.TEXT2),
		UITheme.label(Game.L("직급: %s   ·   팀 평균 신뢰도 %d점   ·   잔액 %s", "Rank: %s   ·   Avg. team trust %d   ·   Balance %s") % [Game.rank_name(), roundi(float(Game.state["flags"].get("review_avg", Game.avg_trust()))), Game.won(Game.money())], 13, UITheme.MUTED),
		UITheme.label(Game.L("커밋 %d · PR %d · CI 통과 %d / 실패 %d · 리뷰 %d · 딴짓 적발 %d", "Commits %d · PRs %d · CI %d green / %d red · Reviews %d · Caught slacking %d") % [Game.stat("commits"), Game.stat("prs"), Game.stat("ci_pass"), Game.stat("ci_fail"), Game.stat("reviews"), Game.stat("caught_slacking")], 13, UITheme.MUTED),
		UITheme.label(Game.L("챕터 2 · 내 이름이 적힌 업무 — 첫 고객의 중복 주문을 끝까지 맡습니다.", "Chapter 2 · A task with my name on it — own a customer's duplicate orders end to end."), 13, UITheme.TEXT2),
	]:
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
	if left and not interviewing:
		v.add_child(UITheme.label(Game.L("기존 이직 선택을 유지합니다. 다음 장은 이직 전 NEXORA 업무 기록으로 이어집니다.", "Your saved career choice is preserved. The next chapter revisits your NEXORA work before that move."), 12, UITheme.MUTED))
	if Story.can_continue_chapter():
		var next := UITheme.button(Game.L("챕터 2 시작하기  →", "Start Chapter 2  →"), "primary")
		next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next.custom_minimum_size = Vector2(260, 42)
		next.pressed.connect(_continue_chapter)
		v.add_child(next)
	var btn := UITheme.button(Game.L("현재 데스크톱 둘러보기", "Review this desktop"))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(240, 40)
	btn.pressed.connect(func() -> void:
		_overlay.queue_free()
		_overlay = null
		_day_transitioning = false
		_end_day_btn.visible = true)
	v.add_child(btn)


func _show_chapter2_ending() -> void:
	UITheme.clear(_overlay)
	Sfx.play("promote")
	confetti(160)
	(_overlay as ColorRect).color = Color(0.02, 0.03, 0.05, 0.96)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var v := UITheme.vbox(14)
	center.add_child(v)
	var r: Dictionary = Game.state["flags"].get("c02_rollout", {})
	var reply: Dictionary = Game.state["flags"].get("c02_reply", {})
	for lab in [
		UITheme.label("CHAPTER 2  —  " + Game.L("내 이름이 적힌 업무", "A TASK WITH MY NAME ON IT"), 13, UITheme.ACCENT),
		UITheme.bold(Game.L("오늘 저녁, 달빛상점은 주문 목록을 대조하지 않았습니다", "Tonight, Moonlight didn't cross-check its order list"), 26),
		UITheme.label(Game.L("고객 기록 → 재현 → 순차·동시 요청 계약 → 로그 · 화면 상태 → 제한 적용과 관찰 → 고객 답장", "Customer records → reproduction → sequential & concurrent contracts → logs · screen states → limited rollout → customer reply"), 14, UITheme.TEXT2),
		UITheme.label(Game.L("관찰 담당 %s · 되돌림 %d회 · 답장 시도 %d회   ·   팀 평균 신뢰도 %d점   ·   잔액 %s", "Observation owner %s · Rollbacks %d · Reply drafts %d   ·   Avg. team trust %d   ·   Balance %s") % [String(r.get("owner", "-")), int(r.get("rollbacks", 0)), int(reply.get("attempts", 0)), roundi(Game.avg_trust()), Game.won(Game.money())], 13, UITheme.MUTED),
		UITheme.label(Game.L("커밋 %d · PR %d · CI 통과 %d / 실패 %d · 리뷰 %d", "Commits %d · PRs %d · CI %d green / %d red · Reviews %d") % [Game.stat("commits"), Game.stat("prs"), Game.stat("ci_pass"), Game.stat("ci_fail"), Game.stat("reviews")], 13, UITheme.MUTED),
		UITheme.label(Game.L("다음 이야기: LEGACY-17 · 예전 주문의 번호가 맞지 않는다 — 챕터 3 개발 중", "Next: LEGACY-17 · old orders whose IDs don't match — Chapter 3 in development"), 13, UITheme.WARN),
	]:
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
	var btn := UITheme.button(Game.L("현재 데스크톱 둘러보기", "Review this desktop"), "primary")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(240, 40)
	btn.pressed.connect(func() -> void:
		_overlay.queue_free()
		_overlay = null
		_day_transitioning = false
		_end_day_btn.visible = true)
	v.add_child(btn)


func _show_content_summary() -> void:
	UITheme.clear(_overlay)
	(_overlay as ColorRect).color = Color(0.02, 0.03, 0.05, 0.96)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var v := UITheme.vbox(16)
	center.add_child(v)
	for item in [
		UITheme.label("CHAPTER %d · %d / %d" % [Game.chapter(), Story.chapter_missions(Game.chapter()).size(), int(preload("res://scripts/story/chapters.gd").DATA[Game.chapter()]["planned"])], 14, UITheme.ACCENT),
		UITheme.bold(Game.L("같은 요청, 하나의 주문", "The same request, one order"), 28),
		UITheme.label(Game.L("고객 기록 조사 → 지연·재전송 재현 → 순차 요청 계약 검증", "Customer records → delay and retry reproduction → sequential contract verified"), 14, UITheme.TEXT2),
		UITheme.label(Game.L("현재 제공되는 3개 업무를 마쳤습니다. 계획된 8개 중 나머지는 개발 중입니다.", "You finished the three available tasks. The remaining five of eight are in development."), 13, UITheme.MUTED),
		UITheme.label(Game.L("동시 요청, 고객 환경 배포와 후속 확인은 아직 남아 있습니다.", "Concurrent requests, customer rollout, and follow-up are still pending."), 13, UITheme.WARN),
	]:
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(item)
	var back := UITheme.button(Game.L("파일과 실험 기록 돌아보기", "Review files and experiment history"), "primary")
	back.pressed.connect(func() -> void:
		_overlay.queue_free()
		_overlay = null
		_day_transitioning = false
		_end_day_btn.visible = true)
	v.add_child(back)


# --- Effects ------------------------------------------------------------------

func _main_call(method: String, arg = null) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method(method):
		if arg == null:
			main.call(method)
		else:
			main.call(method, arg)


func _on_fx_event(kind: String, d: Dictionary) -> void:
	match kind:
		"pr_merged":
			if CodeHub.get_pr(int(d["pr"])).get("author", "") == "me":
				confetti()
		"ci":
			if CodeHub.get_pr(int(d["pr"])).get("author", "") == "me" and not d["ok"]:
				_main_call("shake", 6.0)
		"promoted":
			Sfx.play("promote")
			confetti(200)
		"purchase":
			confetti(40)


func confetti(amount := 120) -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x / 2.0, -10)
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 2.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x / 2.0, 4)
	p.direction = Vector2(0, 1)
	p.spread = 30
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 60
	p.initial_velocity_max = 220
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = 4
	p.scale_amount_max = 8
	var g := Gradient.new()
	g.set_color(0, Color("5b8cff"))
	g.add_point(0.25, Color("3ddc84"))
	g.add_point(0.5, Color("f5a524"))
	g.add_point(0.75, Color("ff6b8a"))
	g.set_color(g.get_point_count() - 1, Color("c084fc"))
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(3.5).timeout.connect(p.queue_free)


# --- Layout -----------------------------------------------------------------

func _build_wallpaper() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color("0f1730"))
	grad.set_color(1, Color("1c1033"))
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
	for blob in [[Vector2(0.2, 0.25), Color(0.36, 0.55, 1.0, 0.22), 0.55], [Vector2(0.85, 0.75), Color(0.75, 0.4, 1.0, 0.2), 0.6], [Vector2(0.6, 0.1), Color(0.2, 0.9, 0.8, 0.08), 0.4]]:
		var g := Gradient.new()
		g.set_color(0, blob[1])
		g.set_color(1, Color(blob[1], 0.0))
		var bt := GradientTexture2D.new()
		bt.gradient = g
		bt.fill = GradientTexture2D.FILL_RADIAL
		bt.fill_from = Vector2(0.5, 0.5)
		bt.fill_to = Vector2(1.0, 0.5)
		var br := TextureRect.new()
		br.texture = bt
		br.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var s: float = blob[2] * 1280.0
		br.size = Vector2(s, s)
		br.position = Vector2(blob[0].x * 1280.0 - s / 2.0, blob[0].y * 720.0 - s / 2.0)
		br.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(br)
	var logo := UITheme.bold("NEXORA", 88, Color(1, 1, 1, 0.045))
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(logo)


func _build_topbar() -> void:
	var bar := PanelContainer.new()
	var sb := UITheme.box(Color(0.03, 0.04, 0.06, 0.82), 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.border_color = Color(1, 1, 1, 0.05)
	sb.border_width_bottom = 1
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = TOPBAR_H
	add_child(bar)
	var row := UITheme.hbox(14)
	bar.add_child(row)
	var logo := Icon.make("dot", UITheme.ACCENT, 12)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)
	row.add_child(UITheme.bold("WORKSTATION OS", 12, UITheme.TEXT2))
	row.add_child(UITheme.spacer())
	var mission := PanelContainer.new()
	var msb := UITheme.box(Color(1, 1, 1, 0.06), 10, Color(0, 0, 0, 0), 0)
	msb.content_margin_left = 12
	msb.content_margin_right = 12
	mission.add_theme_stylebox_override("panel", msb)
	mission.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mission_chip = UITheme.label("", 12, UITheme.TEXT)
	mission.add_child(_mission_chip)
	mission.mouse_filter = Control.MOUSE_FILTER_STOP
	mission.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mission.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			open_app("tasks"))
	row.add_child(mission)
	row.add_child(UITheme.spacer())
	_end_day_btn = UITheme.button("Clock out", "ok")
	_end_day_btn.visible = false
	_end_day_btn.custom_minimum_size.y = 24
	_end_day_btn.add_theme_font_size_override("font_size", 12)
	_end_day_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_day_btn.pressed.connect(_show_day_summary)
	row.add_child(_end_day_btn)
	_status_label = UITheme.label("", 12, UITheme.TEXT2)
	row.add_child(_status_label)
	var wifi := Icon.make("wifi", UITheme.TEXT2, 14)
	wifi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(wifi)
	_clock = UITheme.label(Game.clock_text(), 13, UITheme.TEXT, true)
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
	var sb := UITheme.box(Color(0.07, 0.08, 0.11, 0.72), 20, Color(1, 1, 1, 0.08), 10, 1, 0)
	sb.shadow_size = 20
	sb.shadow_color = Color(0, 0, 0, 0.35)
	dock.add_theme_stylebox_override("panel", sb)
	holder.add_child(dock)
	var row := UITheme.hbox(8)
	dock.add_child(row)
	for i in apps.size():
		row.add_child(_dock_item(apps[i]))
		if i == 1 or i == 7:
			var sep := ColorRect.new()
			sep.color = Color(1, 1, 1, 0.08)
			sep.custom_minimum_size = Vector2(1, 40)
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(sep)


func _dock_item(app: Dictionary) -> Control:
	var c: Color = app["color"]
	var col := UITheme.vbox(4)
	var btn := Button.new()
	btn.tooltip_text = app["name"]
	btn.custom_minimum_size = Vector2(50, 50)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", UITheme.box(c.darkened(0.62), 14, Color(c, 0.35), 0))
	btn.add_theme_stylebox_override("hover", UITheme.box(c.darkened(0.45), 14, Color(c, 0.7), 0))
	btn.add_theme_stylebox_override("pressed", UITheme.box(c.darkened(0.7), 14, Color(c, 0.5), 0))
	var ic := Icon.make(app["icon"], c.lightened(0.35), 26)
	ic.position = Vector2(12, 12)
	btn.add_child(ic)
	var badge := PanelContainer.new()
	var bsb := UITheme.box(UITheme.ERR, 8, Color(0, 0, 0, 0), 0)
	bsb.content_margin_left = 5
	bsb.content_margin_right = 5
	badge.add_theme_stylebox_override("panel", bsb)
	badge.add_child(UITheme.bold("0", 10, Color.WHITE))
	badge.position = Vector2(34, -4)
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	_badges[app["id"]] = badge
	_dock_buttons[app["id"]] = btn
	btn.pressed.connect(open_app.bind(app["id"]))
	btn.mouse_entered.connect(_bounce.bind(btn, 1.12))
	btn.mouse_exited.connect(_bounce.bind(btn, 1.0))
	btn.resized.connect(func() -> void: btn.pivot_offset = Vector2(btn.size.x / 2.0, btn.size.y))
	col.add_child(btn)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(5, 5)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.color = c.lightened(0.3)
	dot.modulate.a = 0.0
	col.add_child(dot)
	_dots[app["id"]] = dot
	return col


func _bounce(node: Control, s: float) -> void:
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(node, "scale", Vector2.ONE * s, 0.16)


func _build_toasts() -> void:
	_toasts = UITheme.vbox(8)
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -340.0
	_toasts.offset_right = -12.0
	_toasts.offset_top = TOPBAR_H + 10.0
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	_pills = UITheme.vbox(6)
	_pills.anchor_left = 0.5
	_pills.anchor_right = 0.5
	_pills.offset_left = -200
	_pills.offset_right = 200
	_pills.offset_top = TOPBAR_H + 10.0
	_pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pills)


func _build_boot_screen() -> void:
	_boot = ColorRect.new()
	_boot.color = Color("050608")
	_boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_boot)
	_boot_log = UITheme.label("", 14, Color("9aa4b5"), true)
	_boot_log.position = Vector2(36, 30)
	_boot.add_child(_boot_log)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UITheme.vbox(10)
	var ic := Icon.make("dot", UITheme.ACCENT, 28)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var title := UITheme.bold("WORKSTATION OS", 30, UITheme.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UITheme.label("NEXORA Inc.", 13, UITheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	center.add_child(v)
	center.modulate.a = 0.0
	_boot_logo = center
	_boot.add_child(center)
