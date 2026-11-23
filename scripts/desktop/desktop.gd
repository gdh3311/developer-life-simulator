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
	{"id": "wiki", "name": "Wiki", "icon": "wiki", "color": Color("22c3c3"), "size": Vector2(800, 540)},
	{"id": "monitor", "name": "Monitor", "icon": "monitor", "color": Color("ff6b6b"), "size": Vector2(860, 520)},
	{"id": "ai", "name": "AICode", "icon": "ai", "color": Color("c084fc"), "size": Vector2(600, 500)},
	{"id": "dashboard", "name": "Dashboard", "icon": "dashboard", "color": Color("94a3b8"), "size": Vector2(860, 540)},
]

var _windows: Control
var _toasts: VBoxContainer
var _pills: VBoxContainer
var _clock: Label
var _mission_chip: Label
var _end_day_btn: Button
var _boot: ColorRect
var _boot_log: Label
var _boot_logo: Control
var _overlay: Control
var _open := {}
var _dots := {}
var _badges := {}
var _dock_labels := {}
var _cascade := 0
var _chapter_done := false


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

	Game.time_changed.connect(func(_d: int, _m: int) -> void: _clock.text = Game.clock_text())
	Game.toast.connect(notify)
	Game.relation_changed.connect(_on_relation)
	Game.chat_added.connect(func(_m: Dictionary) -> void: _update_badges())
	Game.chat_updated.connect(_update_badges)
	CodeHub.pr_changed.connect(func(_id: int) -> void: _update_badges())
	CodeHub.prs_changed.connect(_update_badges)
	Story.objectives_changed.connect(_update_mission_chip)
	Game.day_finished.connect(_on_day_finished)
	Story.chapter_finished.connect(func() -> void: _chapter_done = true)


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
	Game.emit_event("app_opened", {"app": id})
	if _open.has(id):
		(_open[id] as Control).move_to_front()
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
	_open[id] = win
	(_dots[id] as Control).modulate.a = 1.0
	win.pop_in()


func close_all() -> void:
	for id in _open.keys():
		(_open[id] as Control).queue_free()
		_on_window_closed(id)
	_open.clear()


func _on_window_closed(id: String) -> void:
	_open.erase(id)
	(_dots[id] as Control).modulate.a = 0.0


func _app(id: String) -> Dictionary:
	for a in apps:
		if a["id"] == id:
			return a
	return {}


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
	if app_id == "chat" and npc != "":
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
			open_app(app_id)
			_dismiss(card)
	)
	card.modulate.a = 0.0
	var live := _toasts.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	if live.size() >= 4:
		live[0].queue_free()
	_toasts.add_child(card)
	card.position.x = 40
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate:a", 1.0, 0.25)
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
	pill.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.07, 0.1, 0.92), 14, Color(c, 0.6), 0))
	(pill.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 12
	(pill.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 12
	(pill.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 3
	(pill.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 3
	pill.add_child(UITheme.label("%s  ·  %s %s%d" % [Game.npc_name(npc), Game.REL_KEYS[key], "+" if good else "", delta], 12, c.lightened(0.2)))
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
		unread += int(Game.state["unread"][ch])
	_set_badge("chat", unread)
	var pending := 0
	for p in CodeHub.prs():
		if p["state"] != "open":
			continue
		if p["reviewer"] == "me" and p["review"]["state"] == "pending":
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


func _update_mission_chip() -> void:
	var m = Story.active
	if m == null:
		_mission_chip.text = "업무 없음" if not Game.state["day_done"] else "오늘 업무 완료"
	else:
		var done: int = m.objectives.filter(func(o: Dictionary) -> bool: return m.is_done(o["id"])).size()
		_mission_chip.text = "%s%s  ·  %d/%d" % [(m.issue + " ") if m.issue != "" else "", m.title, done, m.objectives.size()]


# --- Boot ---------------------------------------------------------------------

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
		await get_tree().create_timer(0.12).timeout
	var continuing := Workspace.exists() and Game.has_save()
	if Workspace.exists() and not continuing:
		Workspace.wipe()
	_boot_log.text += "Mounting /home/newhire ................ "
	var ws := await Workspace.prepare()
	_boot_log.text += ("OK" if ws["ok"] else "FAILED") + "\n"
	if not ws["ok"]:
		_boot_log.text += "\n[!] %s\n" % ws["message"]
		return
	if continuing:
		Game.load_game()
		_boot_log.text += "Restoring session (DAY %d) ............. OK\n" % Game.day()
	_boot_log.text += "\nBooting WORKSTATION OS...\n"
	await get_tree().create_timer(0.4).timeout
	var t := create_tween()
	t.tween_property(_boot_log, "modulate:a", 0.0, 0.3)
	t.tween_property(_boot_logo, "modulate:a", 1.0, 0.5)
	t.tween_interval(0.8)
	t.tween_property(_boot, "modulate:a", 0.0, 0.6)
	await t.finished
	_boot.queue_free()
	_clock.text = Game.clock_text()
	booted.emit()
	_update_badges()
	if continuing:
		Story.resume()
		if Game.state["day_done"]:
			_on_day_finished(Game.day())
	else:
		Story.start_new()
	_update_mission_chip()


# --- Day cycle ----------------------------------------------------------------

func _on_day_finished(_d: int) -> void:
	_end_day_btn.visible = true
	_update_mission_chip()
	notify("dashboard", "오늘 업무 완료", "상단의 '퇴근하기' 버튼을 눌러 하루를 마무리하세요.")


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
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var v := UITheme.vbox(12)
	card.add_child(v)
	v.add_child(UITheme.label("DAY %d · %s" % [Game.day(), Game.DAY_NAMES[(Game.day() - 1) % 7]], 12, UITheme.MUTED))
	v.add_child(UITheme.bold("업무 종료  ·  %s 퇴근" % Game.clock_text().substr(4), 24))

	var today: Dictionary = Game.state["stats_today"]
	var stats := UITheme.hbox(10)
	for s in [["commits", "커밋"], ["test_runs", "테스트 실행"], ["ci_pass", "CI 통과"], ["ci_fail", "CI 실패"], ["reviews", "리뷰"], ["merges", "병합"]]:
		var box := UITheme.panel(UITheme.BG2, 10, 10, Color(0, 0, 0, 0))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bv := UITheme.vbox(0)
		var n := UITheme.bold(str(int(today.get(s[0], 0))), 22, UITheme.ERR if s[0] == "ci_fail" and int(today.get(s[0], 0)) > 0 else UITheme.TEXT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(n)
		var l := UITheme.label(s[1], 11, UITheme.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(l)
		box.add_child(bv)
		stats.add_child(box)
	v.add_child(stats)

	v.add_child(UITheme.label("오늘의 팀 관계 변화", 12, UITheme.MUTED))
	var rel_today: Dictionary = Game.state["rel_today"]
	if rel_today.is_empty():
		v.add_child(UITheme.label("변화 없음", 13, UITheme.TEXT2))
	for npc in rel_today:
		var row := UITheme.hbox(10)
		row.add_child(UITheme.avatar(npc, 26))
		var nl := UITheme.label(Game.npc_name(npc), 13, UITheme.TEXT)
		nl.custom_minimum_size.x = 110
		row.add_child(nl)
		for key in rel_today[npc]:
			var dv := int(rel_today[npc][key])
			if dv != 0:
				row.add_child(UITheme.chip("%s %s%d" % [Game.REL_KEYS[key], "+" if dv > 0 else "", dv], UITheme.OK if dv > 0 else UITheme.ERR))
		v.add_child(row)

	var btn := UITheme.button("엔딩 보기" if _chapter_done else "다음 날 출근하기  →", "primary")
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(_on_next_day)
	v.add_child(btn)
	card.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_overlay, "color:a", 0.85, 0.4)
	t.tween_property(card, "modulate:a", 1.0, 0.4)


func _on_next_day() -> void:
	if _chapter_done:
		_show_ending()
		return
	var t := create_tween()
	t.tween_property(_overlay, "color:a", 1.0, 0.5)
	t.parallel().tween_property(_overlay.get_child(0), "modulate:a", 0.0, 0.3)
	await t.finished
	close_all()
	Game.next_day()
	_end_day_btn.visible = false
	UITheme.clear(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var title := UITheme.bold("DAY %d · %s   09:00" % [Game.day(), Game.DAY_NAMES[(Game.day() - 1) % 7]], 30, UITheme.TEXT)
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
	Story.start_day(Game.day())
	_update_mission_chip()


func _show_ending() -> void:
	UITheme.clear(_overlay)
	(_overlay as ColorRect).color = Color(0.02, 0.03, 0.05, 0.96)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var v := UITheme.vbox(14)
	center.add_child(v)
	for l in [
		[UITheme.label("CHAPTER 1  —  FIRST WEEK", 13, UITheme.ACCENT), true],
		[UITheme.bold("NEXORA에서의 첫 3일을 마쳤습니다", 28), true],
		[UITheme.label("직급: %s   ·   팀 평균 신뢰도 %d점" % [Game.rank_name(), roundi(float(Game.state["flags"].get("review_avg", 0)))], 15, UITheme.TEXT2), true],
		[UITheme.label("커밋 %d  ·  PR %d  ·  CI 통과 %d / 실패 %d  ·  리뷰 %d  ·  힌트 %d" % [Game.stat("commits"), Game.stat("prs"), Game.stat("ci_pass"), Game.stat("ci_fail"), Game.stat("reviews"), Game.stat("hints")], 13, UITheme.MUTED), true],
		[UITheme.label("다음 챕터(새 회사, 프로덕션 배포, AI 에이전트 감독)는 Early Access에서 이어집니다.", 13, UITheme.TEXT2), true],
	]:
		var lab: Label = l[0]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lab)
	var btn := UITheme.button("자유 모드로 계속하기", "primary")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(220, 40)
	btn.pressed.connect(func() -> void:
		_overlay.queue_free()
		_overlay = null
		_end_day_btn.visible = false)
	v.add_child(btn)


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
	var sub := UITheme.label("build things that work · together", 14, Color(1, 1, 1, 0.08))
	sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.offset_top = 90
	add_child(sub)


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
	_end_day_btn = UITheme.button("퇴근하기", "ok")
	_end_day_btn.visible = false
	_end_day_btn.custom_minimum_size.y = 24
	_end_day_btn.add_theme_font_size_override("font_size", 12)
	_end_day_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_day_btn.pressed.connect(_show_day_summary)
	row.add_child(_end_day_btn)
	var wifi := Icon.make("wifi", UITheme.TEXT2, 14)
	wifi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(wifi)
	row.add_child(UITheme.label("New Hire · " + Game.rank_name(), 12, UITheme.MUTED))
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
		if i == 1 or i == 6:
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
	var normal := UITheme.box(c.darkened(0.62), 14, Color(c, 0.35), 0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", UITheme.box(c.darkened(0.45), 14, Color(c, 0.7), 0))
	btn.add_theme_stylebox_override("pressed", UITheme.box(c.darkened(0.7), 14, Color(c, 0.5), 0))
	var ic := Icon.make(app["icon"], c.lightened(0.35), 26)
	ic.position = Vector2(12, 12)
	btn.add_child(ic)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UITheme.box(UITheme.ERR, 8, Color(0, 0, 0, 0), 0))
	(badge.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 5
	(badge.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 5
	badge.add_child(UITheme.bold("0", 10, Color.WHITE))
	badge.position = Vector2(34, -4)
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	_badges[app["id"]] = badge
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
	_pills.alignment = BoxContainer.ALIGNMENT_BEGIN
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
