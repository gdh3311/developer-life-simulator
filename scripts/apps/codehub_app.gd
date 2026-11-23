extends HSplitContainer
## CodeHub: pull requests, CI results, review comments. Juniors open PRs and comment;
## seniors approve and merge.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")

var desktop: Control
var _list: VBoxContainer
var _right: VBoxContainer
var _selected := 0
var _mode := "empty"   # empty | new | pr
var _tab := 0
var _diff_cache := {}  # pr id -> {head, text}
var _picked := {}      # "file:line" -> {file, line, text}
var _busy := false


func _ready() -> void:
	split_offset = 250
	add_theme_constant_override("separation", 0)
	var left := UITheme.panel(UITheme.BG0, 0, 10, Color(0, 0, 0, 0))
	left.custom_minimum_size.x = 240
	var lv := UITheme.vbox(8)
	var new_btn := UITheme.button(Game.L("+  새 Pull Request", "+  New Pull Request"), "primary")
	new_btn.pressed.connect(func() -> void:
		_mode = "new"
		_render())
	lv.add_child(new_btn)
	_list = UITheme.vbox(4)
	lv.add_child(UITheme.scroll(_list))
	left.add_child(lv)
	add_child(left)
	_right = UITheme.vbox(0)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_right)
	CodeHub.prs_changed.connect(_render)
	CodeHub.pr_changed.connect(func(id: int) -> void:
		_render_list()
		if _mode == "pr" and id == _selected:
			_render_detail())
	for p in CodeHub.prs():
		if p["state"] == "open" and (p["flags"].get("needs_my_comment", false) or p["author"] == "me"):
			_selected = p["id"]
			_mode = "pr"
	_render()


func open_mission_diff(mission_id: String) -> void:
	for p in CodeHub.prs():
		if p.get("mission", "") == mission_id:
			_selected = int(p["id"])
			_mode = "pr"
			_tab = 1
			_render()
			return


func _report_diff(p: Dictionary) -> void:
	var cache: Dictionary = _diff_cache.get(int(p["id"]), {})
	if _tab == 1 and _selected == int(p["id"]) and not String(cache.get("text", "")).is_empty():
		Game.emit_event("pr_diff_viewed", {"mission": p.get("mission", ""), "text": cache["text"]})


func _render() -> void:
	_render_list()
	match _mode:
		"new":
			_render_new()
		"pr":
			_render_detail()
		_:
			UITheme.clear(_right)
			var c := CenterContainer.new()
			c.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var v := UITheme.vbox(8)
			var ic := Icon.make("pr", UITheme.MUTED, 40)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(ic)
			v.add_child(UITheme.label(Game.L("작업 브랜치를 push 한 뒤 '새 Pull Request'를 만드세요.", "Push a working branch, then create a 'New Pull Request'."), 13, UITheme.MUTED))
			c.add_child(v)
			_right.add_child(c)


func _who(id: String) -> String:
	return Game.L("나", "me") if id == "me" else Game.npc_name(id)


func _render_list() -> void:
	UITheme.clear(_list)
	var prs: Array = CodeHub.prs().duplicate()
	prs.reverse()
	if prs.is_empty():
		_list.add_child(UITheme.label(Game.L("PR이 없습니다.", "No pull requests."), 12, UITheme.MUTED))
	for p in prs:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size.y = 58
		var sel: bool = _mode == "pr" and int(p["id"]) == _selected
		b.add_theme_stylebox_override("normal", UITheme.box(UITheme.BG3 if sel else Color(0, 0, 0, 0), 8, UITheme.ACCENT.darkened(0.3) if sel else Color(0, 0, 0, 0), 8))
		b.add_theme_stylebox_override("hover", UITheme.box(Color(1, 1, 1, 0.05), 8, Color(0, 0, 0, 0), 8))
		var v := UITheme.vbox(3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10
		v.offset_top = 8
		v.offset_right = -8
		var top := UITheme.hbox(6)
		top.add_child(_state_icon(p))
		var t := UITheme.label("#%d %s" % [p["id"], p["title"]], 12, UITheme.TEXT)
		t.clip_text = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(t)
		v.add_child(top)
		var sub := "%s · %s" % [_who(p["author"]), p["branch"]]
		var needs: bool = p["state"] == "open" and p["flags"].get("needs_my_comment", false)
		if needs:
			sub = Game.L("코멘트 요청됨 · ", "Comments requested · ") + sub
		v.add_child(UITheme.label(sub, 11, UITheme.WARN if needs else UITheme.MUTED))
		b.add_child(v)
		var id := int(p["id"])
		b.pressed.connect(func() -> void:
			_selected = id
			_mode = "pr"
			_tab = 0
			_picked.clear()
			_render())
		_list.add_child(b)


func _state_icon(p: Dictionary) -> Control:
	if p["state"] == "merged":
		return Icon.make("pr", Color("a78bfa"), 14)
	if p["ci"]["state"] == "fail":
		return Icon.make("x", UITheme.ERR, 14)
	if p["ci"]["state"] == "pass":
		return Icon.make("check", UITheme.OK, 14)
	return Icon.make("ring", UITheme.WARN, 14)


# --- New PR -------------------------------------------------------------------

func _render_new() -> void:
	UITheme.clear(_right)
	var v := UITheme.vbox(10)
	_right.add_child(UITheme.margin(v, 20))
	v.add_child(UITheme.bold(Game.L("새 Pull Request", "New Pull Request"), 18))
	v.add_child(UITheme.label(Game.L("원격(origin)에 push 된 작업 브랜치를 main에 병합해 달라고 요청합니다.", "Ask for a branch pushed to origin to be merged into main."), 12, UITheme.MUTED))
	v.add_child(UITheme.label(Game.L("브랜치", "Branch"), 12, UITheme.TEXT2))
	var branch := OptionButton.new()
	v.add_child(branch)
	v.add_child(UITheme.label(Game.L("제목", "Title"), 12, UITheme.TEXT2))
	var title := LineEdit.new()
	title.placeholder_text = Game.L("fix(users): 무엇을 고쳤는지", "fix(users): what you fixed")
	v.add_child(title)
	v.add_child(UITheme.label(Game.L("설명", "Description"), 12, UITheme.TEXT2))
	var body := TextEdit.new()
	body.custom_minimum_size.y = 110
	body.placeholder_text = Game.L("무엇을, 왜 바꿨는지. 어떻게 테스트했는지.", "What changed and why. How you tested it.")
	body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(body)
	var err := UITheme.label("", 12, UITheme.ERR)
	var row := UITheme.hbox(10)
	var create := UITheme.button(Game.L("PR 만들기", "Create PR"), "ok")
	create.custom_minimum_size = Vector2(130, 36)
	row.add_child(create)
	var cancel := UITheme.button(Game.L("취소", "Cancel"))
	cancel.pressed.connect(func() -> void:
		_mode = "pr" if _selected > 0 else "empty"
		_render())
	row.add_child(cancel)
	row.add_child(err)
	v.add_child(row)

	var candidates: Array = await CodeHub.pr_candidates()
	if not is_instance_valid(branch):
		return
	if candidates.is_empty():
		branch.add_item(Game.L("(push 된 작업 브랜치 없음)", "(no pushed branches)"))
		branch.disabled = true
		create.disabled = true
		err.text = Game.L("먼저 작업 브랜치를 만들어 git push 하세요.", "Create a branch and git push it first.")
	for c in candidates:
		branch.add_item(c)
	for i in branch.item_count:
		if branch.get_item_text(i) == Workspace.branch:
			branch.select(i)
	var fill_title := func() -> void:
		if branch.disabled:
			return
		var commits := await Workspace.pr_commits(branch.get_item_text(branch.selected))
		if not commits.is_empty() and is_instance_valid(title) and title.text == "":
			title.text = String(commits[0]).get_slice("|", 2)
	branch.item_selected.connect(func(_i: int) -> void:
		title.text = ""
		fill_title.call())
	fill_title.call()
	create.pressed.connect(func() -> void:
		if _busy:
			return
		_busy = true
		create.disabled = true
		var r := await CodeHub.open_pr(branch.get_item_text(branch.selected), title.text, body.text)
		_busy = false
		if not r["ok"]:
			err.text = r["error"]
			create.disabled = false
			return
		_selected = r["pr"]["id"]
		_mode = "pr"
		_tab = 0
		_render())


# --- PR detail ------------------------------------------------------------------

func _render_detail() -> void:
	var p := CodeHub.get_pr(_selected)
	UITheme.clear(_right)
	if p.is_empty():
		return
	var head := UITheme.vbox(8)
	_right.add_child(UITheme.margin(head, 16))
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.add_theme_font_override("normal_font", UITheme.font(false, true))
	title.add_theme_font_size_override("normal_font_size", 17)
	title.text = "%s  [color=#6f7a8c]#%d[/color]" % [String(p["title"]).replace("[", "[lb]"), p["id"]]
	head.add_child(title)
	var meta := UITheme.hbox(8)
	var st: Array = {"open": ["Open", UITheme.OK], "merged": ["Merged", Color("a78bfa")], "closed": ["Closed", UITheme.ERR]}[p["state"]]
	meta.add_child(UITheme.chip(st[0], st[1]))
	meta.add_child(UITheme.label(Game.L("%s 님이 %s → main 병합을 요청", "%s wants to merge %s → main") % [_who(p["author"]), p["branch"]], 12, UITheme.TEXT2))
	head.add_child(meta)
	var checks := UITheme.hbox(8)
	var ci: Dictionary = p["ci"]
	var ci_text: Array = {"none": [Game.L("CI 대기", "CI queued"), UITheme.MUTED], "running": [Game.L("CI 실행 중…", "CI running…"), UITheme.WARN],
		"pass": [Game.L("CI 통과 · %d", "CI passed · %d") % int(ci.get("passed", 0)), UITheme.OK], "fail": [Game.L("CI 실패 · %d", "CI failed · %d") % int(ci.get("failed", 0)), UITheme.ERR]}[ci["state"]]
	checks.add_child(UITheme.chip(ci_text[0], ci_text[1]))
	var rv: Dictionary = p["review"]
	var rv_by := _who(rv["by"])
	var rv_text: Array = {"pending": [Game.L("리뷰 대기 (%s)", "Review pending (%s)") % rv_by, UITheme.WARN], "changes": [Game.L("변경 요청 (%s)", "Changes requested (%s)") % rv_by, UITheme.ERR],
		"approved": [Game.L("승인 (%s)", "Approved (%s)") % rv_by, UITheme.OK], "commented": [Game.L("코멘트", "Commented"), UITheme.MUTED]}[rv["state"]]
	checks.add_child(UITheme.chip(rv_text[0], rv_text[1]))
	if p["state"] == "open":
		var mg: Array = {"unknown": [Game.L("병합 가능 여부 확인 중", "Checking mergeability"), UITheme.MUTED], "clean": [Game.L("충돌 없음", "No conflicts"), UITheme.OK], "conflict": [Game.L("충돌 있음", "Has conflicts"), UITheme.ERR]}[p["mergeable"]]
		checks.add_child(UITheme.chip(mg[0], mg[1]))
	head.add_child(checks)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 13)
	_right.add_child(tabs)
	var conv := _conversation(p)
	conv.name = Game.L("대화", "Conversation")
	tabs.add_child(conv)
	var diff := UITheme.vbox(0)
	diff.name = Game.L("변경 사항", "Changes")
	tabs.add_child(diff)
	var cires := _ci_view(p)
	cires.name = Game.L("CI 결과", "CI results")
	tabs.add_child(cires)
	tabs.current_tab = _tab
	tabs.tab_changed.connect(func(i: int) -> void:
		_tab = i
		_report_diff(p))
	_fill_diff(p, diff)

	var footer := UITheme.panel(UITheme.BG0, 0, 12, Color(0, 0, 0, 0))
	_right.add_child(footer)
	footer.add_child(_footer(p))


func _conversation(p: Dictionary) -> Control:
	var v := UITheme.vbox(12)
	if p["body"] != "" and p["author"] == "me":
		v.add_child(_comment_box("me", "", p["body"]))
	var timeline: Array = p["timeline"]
	for i in timeline.size():
		var item: Dictionary = timeline[i]
		var text := Game.tx(item["text"])
		if item["from"] in ["system", "ci"]:
			var row := UITheme.hbox(8)
			var bad: bool = item["from"] == "ci" and ("실패" in text or "failed" in text) or "충돌" in text or "conflict" in text
			var good: bool = not bad and item["from"] == "ci"
			var ic := Icon.make("x" if bad else ("check" if good else "dot"), UITheme.ERR if bad else (UITheme.OK if good else UITheme.MUTED), 14)
			ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(ic)
			row.add_child(UITheme.wrap(text, 12, UITheme.TEXT2))
			row.add_child(UITheme.label(item["time"], 11, UITheme.MUTED))
			v.add_child(row)
			continue
		var box := _comment_box(item["from"], item["time"], text)
		var choices: Array = item["choices"]
		if not choices.is_empty() and item["answered"] == "":
			var opts := UITheme.vbox(6)
			for c in choices:
				var b := UITheme.choice_button(Game.tx(c["label"]))
				b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				var idx := i
				var cid: String = c["id"]
				var pid := int(p["id"])
				b.pressed.connect(func() -> void: CodeHub.answer(pid, idx, cid))
				opts.add_child(b)
			box.get_child(0).get_child(1).add_child(opts)
		v.add_child(box)
	var s := UITheme.scroll(UITheme.margin(v, 14))
	(func() -> void:
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(s):
			s.scroll_vertical = int(s.get_v_scroll_bar().max_value)).call()
	return s


func _comment_box(from: String, time: String, text: String) -> Control:
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := UITheme.hbox(10)
	row.add_child(UITheme.avatar(from, 30))
	var col := UITheme.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UITheme.hbox(8)
	head.add_child(UITheme.bold(Game.npc_name(from), 13))
	head.add_child(UITheme.label(time, 11, UITheme.MUTED))
	col.add_child(head)
	var bubble := UITheme.panel(UITheme.BG3, 8, 10, Color(1, 1, 1, 0.05))
	bubble.add_child(UITheme.wrap(text, 13, UITheme.TEXT))
	col.add_child(bubble)
	row.add_child(col)
	wrap.add_child(row)
	return wrap


func _ci_view(p: Dictionary) -> Control:
	var v := UITheme.vbox(8)
	var ci: Dictionary = p["ci"]
	match ci["state"]:
		"none", "running":
			v.add_child(UITheme.label(Game.L("CI 실행 중... (테스트 + [CI] 추가 검증)", "CI running... (tests + [CI] extra checks)"), 13, UITheme.WARN))
		_:
			v.add_child(UITheme.bold(Game.L("성공 %d · 실패 %d", "%d passed · %d failed") % [int(ci["passed"]), int(ci["failed"])], 15, UITheme.OK if ci["state"] == "pass" else UITheme.ERR))
			if int(ci.get("hidden", 0)) > 0:
				v.add_child(UITheme.label(Game.L("이 PR에는 [CI] 추가 검증 테스트 %d개 파일이 함께 실행되었습니다.", "This PR also ran %d [CI] extra check file(s).") % int(ci["hidden"]), 12, UITheme.MUTED))
			if String(ci.get("error", "")) != "":
				v.add_child(UITheme.wrap(ci["error"], 13, UITheme.ERR))
			for f in ci["failures"]:
				var card := UITheme.panel(Color(UITheme.ERR, 0.08), 8, 10, Color(UITheme.ERR, 0.35))
				var cv := UITheme.vbox(4)
				cv.add_child(UITheme.bold("✗ " + String(f["name"]), 13, UITheme.ERR.lightened(0.3)))
				for d in f["detail"]:
					cv.add_child(UITheme.label("   " + String(d), 12, UITheme.TEXT2, true))
				card.add_child(cv)
				v.add_child(card)
			if ci["state"] == "pass":
				v.add_child(UITheme.label(Game.L("모든 테스트가 통과했습니다.", "All tests passed."), 13, UITheme.TEXT2))
	return UITheme.scroll(UITheme.margin(v, 14))


func _fill_diff(p: Dictionary, holder: VBoxContainer) -> void:
	var id := int(p["id"])
	var cache: Dictionary = _diff_cache.get(id, {})
	if cache.get("head", "") != p["head"] and not (p["state"] == "merged" and not cache.is_empty()):
		holder.add_child(UITheme.margin(UITheme.label(Game.L("변경 사항 불러오는 중...", "Loading changes..."), 12, UITheme.MUTED), 14))
		var text := await Workspace.pr_diff(p["branch"])
		cache = {"head": p["head"], "text": text}
		_diff_cache[id] = cache
		if not is_instance_valid(holder):
			return
		UITheme.clear(holder)
	var selectable: bool = p["state"] == "open" and p["flags"].get("needs_my_comment", false)
	var v := UITheme.vbox(0)
	if selectable:
		v.add_child(UITheme.margin(UITheme.label(Game.L("문제가 있어 보이는 줄을 클릭해서 선택하세요. 선택한 줄은 코멘트에 포함됩니다.", "Click lines that look wrong to select them. They'll be quoted in your comment."), 12, UITheme.WARN), 8))
	var file := ""
	var new_line := 0
	for line in String(cache["text"]).split("\n"):
		if line.begins_with("diff --git") or line.begins_with("index ") or line.begins_with("--- ") or line.begins_with("new file") or line.begins_with("deleted file"):
			continue
		if line.begins_with("+++ "):
			file = line.substr(6)
			var fh := UITheme.panel(UITheme.BG3, 0, 8, Color(0, 0, 0, 0))
			fh.add_child(UITheme.bold(file, 12, UITheme.TEXT))
			v.add_child(fh)
			continue
		if line.begins_with("@@"):
			new_line = int(line.get_slice("+", 1).get_slice(",", 0).get_slice(" ", 0)) - 1
			v.add_child(UITheme.margin(UITheme.label(line, 11, Color("6b8fd6"), true), 4))
			continue
		var kind := line.left(1)
		if kind != "-":
			new_line += 1
		v.add_child(_diff_line(file, new_line if kind != "-" else 0, line, selectable))
	holder.add_child(UITheme.scroll(v))
	_report_diff(p)


func _diff_line(file: String, num: int, line: String, selectable: bool) -> Control:
	var kind := line.left(1)
	var key := "%s:%d" % [file, num]
	var bg := Color(0, 0, 0, 0)
	if kind == "+":
		bg = Color(UITheme.OK, 0.10)
	elif kind == "-":
		bg = Color(UITheme.ERR, 0.10)
	if _picked.has(key):
		bg = Color(UITheme.WARN, 0.28)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", UITheme.font(true))
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_stylebox_override("normal", UITheme.box(bg, 0, Color(0, 0, 0, 0), 1))
	b.add_theme_stylebox_override("hover", UITheme.box(bg.lightened(0.05) if selectable else bg, 0, Color(UITheme.WARN, 0.5) if selectable else Color(0, 0, 0, 0), 1))
	b.add_theme_stylebox_override("pressed", UITheme.box(bg, 0, Color(0, 0, 0, 0), 1))
	var fc := UITheme.OK.lightened(0.35) if kind == "+" else (UITheme.ERR.lightened(0.3) if kind == "-" else UITheme.TEXT2)
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.text = "%4s  %s" % [str(num) if num > 0 else "", line]
	if selectable and kind != "-" and line.strip_edges() != "":
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void:
			if _picked.has(key):
				_picked.erase(key)
			else:
				_picked[key] = {"file": file, "line": num, "text": line.substr(1)}
			_render_detail())
	else:
		b.mouse_filter = Control.MOUSE_FILTER_PASS
	return b


func _footer(p: Dictionary) -> Control:
	var row := UITheme.hbox(10)
	if p["state"] != "open":
		row.add_child(UITheme.label(Game.L("이 PR은 병합되었습니다.", "This PR was merged.") if p["state"] == "merged" else Game.L("닫힌 PR입니다.", "This PR is closed."), 13, UITheme.TEXT2))
		return row
	if p["author"] != "me":
		if not p["flags"].get("needs_my_comment", false):
			row.add_child(UITheme.label(Game.L("코멘트를 남겼습니다. 승인과 병합은 %s 님이 합니다.", "You commented. %s will approve and merge.") % Game.npc_name(p["reviewer"]), 12, UITheme.MUTED))
			return row
		row.add_child(UITheme.label(Game.L("선택 %d줄", "%d lines") % _picked.size(), 12, UITheme.WARN if _picked.size() > 0 else UITheme.MUTED))
		var note := LineEdit.new()
		note.placeholder_text = Game.L("코멘트 (선택)", "Comment (optional)")
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(note)
		var concern := UITheme.button(Game.L("문제 있음", "Problem"), "danger")
		var lgtm := UITheme.button("LGTM", "ok")
		concern.disabled = p["ci"]["state"] == "running"
		lgtm.disabled = p["ci"]["state"] == "running"
		var pid := int(p["id"])
		concern.pressed.connect(func() -> void:
			var lines := _picked.values()
			_picked.clear()
			CodeHub.submit_comments(pid, "concern", lines, note.text))
		lgtm.pressed.connect(func() -> void:
			var lines := _picked.values()
			_picked.clear()
			CodeHub.submit_comments(pid, "lgtm", lines, note.text))
		row.add_child(concern)
		row.add_child(lgtm)
		return row
	var blockers := CodeHub.merge_blockers(p)
	var ic := Icon.make("ring" if not blockers.is_empty() else "check", UITheme.MUTED if not blockers.is_empty() else UITheme.OK, 14)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var msg := Game.L("병합 대기 중 — 필요: %s", "Waiting to merge — needs: %s") % ", ".join(blockers) if not blockers.is_empty() \
		else Game.L("모든 조건 충족 — %s 님이 곧 병합합니다.", "All set — %s will merge shortly.") % Game.npc_name(p["review"]["by"])
	row.add_child(UITheme.wrap(msg, 12, UITheme.TEXT2))
	row.add_child(UITheme.label(Game.L("인턴·주니어는 직접 병합할 수 없어요", "Interns/juniors can't merge"), 11, UITheme.MUTED))
	return row
