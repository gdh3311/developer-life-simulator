extends Control
## The portrait side monitor that arrives with the first promotion: a glanceable status board
## (clock, today's task, my latest PR's CI, unread messages, service health). Read-only.

const UITheme := preload("res://scripts/ui/ui_theme.gd")

var _root: VBoxContainer
var _dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color("0b0e14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_root = UITheme.vbox(8)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := UITheme.margin(_root, 12)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	Game.time_changed.connect(func(_d: int, _m: int) -> void: _dirty = true)
	Game.chat_added.connect(func(_msg: Dictionary) -> void: _dirty = true)
	Game.chat_updated.connect(func() -> void: _dirty = true)
	Game.event.connect(func(_k: String, _d: Dictionary) -> void: _dirty = true)
	Game.state_reset.connect(func() -> void: _dirty = true)
	Story.objectives_changed.connect(func() -> void: _dirty = true)
	CodeHub.prs_changed.connect(func() -> void: _dirty = true)
	CodeHub.pr_changed.connect(func(_id: int) -> void: _dirty = true)


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_render()


func _card(title: String) -> VBoxContainer:
	var p := UITheme.panel(Color("141924"), 8, 10, Color(1, 1, 1, 0.05))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UITheme.vbox(4)
	p.add_child(v)
	v.add_child(UITheme.label(title, 11, UITheme.MUTED))
	_root.add_child(p)
	return v


func _latest_pr() -> Dictionary:
	var best := {}
	for pr in CodeHub.prs():
		if pr.get("author", "") == "me" and (best.is_empty() or int(pr["id"]) > int(best["id"])):
			best = pr
	return best


func _render() -> void:
	UITheme.clear(_root)
	var clock := UITheme.bold("%02d:%02d" % [Game.minutes() / 60, Game.minutes() % 60], 34)
	clock.add_theme_font_override("font", UITheme.font(true, true))
	_root.add_child(clock)
	_root.add_child(UITheme.label(Game.date_text(), 12, UITheme.TEXT2))

	var task := _card(Game.L("지금 업무", "NOW"))
	var m = Story.active
	if m == null:
		task.add_child(UITheme.label(Game.L("업무 없음", "Nothing active"), 13, UITheme.TEXT2))
	else:
		task.add_child(UITheme.label(m.issue, 11, UITheme.ACCENT, true))
		var title := UITheme.wrap(m.title_text(), 13, UITheme.TEXT)
		task.add_child(title)
		var done := 0
		for o in m.objectives:
			if m.is_done(o["id"]):
				done += 1
		task.add_child(UITheme.label("%d / %d" % [done, m.objectives.size()], 12, UITheme.OK if done == m.objectives.size() else UITheme.TEXT2))
		var next: Dictionary = m.current_objective()
		if not next.is_empty():
			task.add_child(UITheme.wrap("→ " + Game.tx(next["text"]), 11, UITheme.TEXT2))

	var ci := _card("CI")
	var pr := _latest_pr()
	if pr.is_empty():
		ci.add_child(UITheme.label(Game.L("내 PR 없음", "No PR yet"), 12, UITheme.MUTED))
	else:
		var state := String(pr["ci"].get("state", ""))
		var color: Color = UITheme.OK if state == "pass" else (UITheme.ERR if state == "fail" else UITheme.WARN)
		var text: String = {"pass": "● PASS", "fail": "● FAIL", "running": "● RUNNING"}.get(state, "● —")
		ci.add_child(UITheme.bold(text, 15, color))
		ci.add_child(UITheme.label("#%d · %s" % [int(pr["id"]), String(pr.get("state", ""))], 11, UITheme.TEXT2))

	var inbox := _card(Game.L("알림", "INBOX"))
	var unread := 0
	for ch in Game.state["unread"]:
		unread += int(Game.state["unread"][ch])
	inbox.add_child(UITheme.bold(str(unread), 22, UITheme.WARN if unread > 0 else UITheme.TEXT2))

	var svc := _card(Game.L("서비스", "SERVICES"))
	var statuses: Dictionary = Game.state["monitor"]["status"]
	for name in statuses:
		var s := String(statuses[name])
		var c: Color = UITheme.OK if s == "ok" else (UITheme.ERR if s == "down" else UITheme.WARN)
		svc.add_child(UITheme.label("● " + String(name), 12, c))
