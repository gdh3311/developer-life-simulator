extends HSplitContainer
## CodeHub: pull requests, CI results, code review and merging.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")

var desktop: Control
var _list: VBoxContainer
var _right: VBoxContainer
var _selected := 0
var _mode := "empty"   # empty | new | pr
var _tab := 0
var _diff_cache := {}  # pr id -> {head, files}
var _picked := {}      # "file:line" -> {file, line, text}
var _busy := false


func _ready() -> void:
	split_offset = 250
	add_theme_constant_override("separation", 0)
	var left := UITheme.panel(UITheme.BG0, 0, 10, Color(0, 0, 0, 0))
	left.custom_minimum_size.x = 240
	var lv := UITheme.vbox(8)
	var new_btn := UITheme.button("+  새 Pull Request", "primary")
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
	# Open the PR that needs attention first.
	for p in CodeHub.prs():
		if p["state"] == "open" and ((p["reviewer"] == "me" and p["review"]["state"] == "pending") or p["author"] == "me"):
			_selected = p["id"]
			_mode = "pr"
	_render()


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
			v.add_child(UITheme.label("작업 브랜치를 push 한 뒤 '새 Pull Request'를 만드세요.", 13, UITheme.MUTED))
			c.add_child(v)
			_right.add_child(c)


func _render_list() -> void:
	UITheme.clear(_list)
	var prs: Array = CodeHub.prs().duplicate()
	prs.reverse()
	if prs.is_empty():
		_list.add_child(UITheme.label("PR이 없습니다.", 12, UITheme.MUTED))
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
		var sub := "%s · %s" % [Game.npc_name(p["author"]) if p["author"] != "me" else "나", p["branch"]]
		if p["reviewer"] == "me" and p["state"] == "open" and p["review"]["state"] == "pending":
			sub = "리뷰 요청됨 · " + sub
		v.add_child(UITheme.label(sub, 11, UITheme.WARN if sub.begins_with("리뷰") else UITheme.MUTED))
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
	v.add_child(UITheme.bold("새 Pull Request", 18))
	v.add_child(UITheme.label("원격(origin)에 push 된 작업 브랜치를 main에 병합하자고 요청합니다.", 12, UITheme.MUTED))
	v.add_child(UITheme.label("브랜치", 12, UITheme.TEXT2))
	var branch := OptionButton.new()
	branch.fit_to_longest_item = false
	v.add_child(branch)
	v.add_child(UITheme.label("제목", 12, UITheme.TEXT2))
	var title := LineEdit.new()
	title.placeholder_text = "fix(users): 무엇을 고쳤는지"
	v.add_child(title)
	v.add_child(UITheme.label("설명", 12, UITheme.TEXT2))
	var body := TextEdit.new()
	body.custom_minimum_size.y = 110
	body.placeholder_text = "무엇을, 왜 바꿨는지. 어떻게 테스트했는지."
	body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(body)
	var err := UITheme.label("", 12, UITheme.ERR)
	var row := UITheme.hbox(10)
	var create := UITheme.button("PR 만들기", "ok")
	create.custom_minimum_size = Vector2(130, 36)
	row.add_child(create)
	var cancel := UITheme.button("취소")
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
		branch.add_item("(push 된 작업 브랜치 없음)")
		branch.disabled = true
		create.disabled = true
		err.text = "먼저 작업 브랜치를 만들어 git push 하세요."
	for c in candidates:
		branch.add_item(c)
	# Prefer the branch currently checked out.
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
	meta.add_child(UITheme.label("%s 님이 %s → main 병합을 요청" % [Game.npc_name(p["author"]) if p["author"] != "me" else "내가", p["branch"]], 12, UITheme.TEXT2))
	head.add_child(meta)
	var checks := UITheme.hbox(8)
	var ci: Dictionary = p["ci"]
	var ci_text: Array = {"none": ["CI 대기", UITheme.MUTED], "running": ["CI 실행 중…", UITheme.WARN],
		"pass": ["CI 통과 · %d" % int(ci.get("passed", 0)), UITheme.OK], "fail": ["CI 실패 · %d" % int(ci.get("failed", 0)), UITheme.ERR]}[ci["state"]]
	checks.add_child(UITheme.chip(ci_text[0], ci_text[1]))
	var rv: Dictionary = p["review"]
	var rv_by: String = "나" if rv["by"] == "me" else Game.npc_name(rv["by"])
	var rv_text: Array = {"pending": ["리뷰 대기 (%s)" % rv_by, UITheme.WARN], "changes": ["변경 요청 (%s)" % rv_by, UITheme.ERR],
		"approved": ["승인 (%s)" % rv_by, UITheme.OK], "commented": ["코멘트", UITheme.MUTED]}[rv["state"]]
	if p["flags"].get("skip_review", false) and rv["state"] != "approved":
		rv_text = ["리뷰 생략", UITheme.WARN]
	checks.add_child(UITheme.chip(rv_text[0], rv_text[1]))
	if p["state"] == "open":
		var mg: Array = {"unknown": ["병합 가능 여부 확인 중", UITheme.MUTED], "clean": ["충돌 없음", UITheme.OK], "conflict": ["충돌 있음", UITheme.ERR]}[p["mergeable"]]
		checks.add_child(UITheme.chip(mg[0], mg[1]))
	head.add_child(checks)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 13)
	_right.add_child(tabs)
	var conv := _conversation(p)
	conv.name = "대화"
	tabs.add_child(conv)
	var diff := UITheme.vbox(0)
	diff.name = "변경 사항"
	tabs.add_child(diff)
	var cires := _ci_view(p)
	cires.name = "CI 결과"
	tabs.add_child(cires)
	tabs.current_tab = _tab
	tabs.tab_changed.connect(func(i: int) -> void: _tab = i)
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
		if item["from"] in ["system", "ci"]:
			var row := UITheme.hbox(8)
			var bad: bool = "실패" in item["text"] or "충돌" in item["text"]
			var good: bool = not bad and "통과" in item["text"]
			var ic := Icon.make("x" if bad else ("check" if good else "dot"), UITheme.ERR if bad else (UITheme.OK if good else UITheme.MUTED), 14)
			ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(ic)
			row.add_child(UITheme.wrap(item["text"], 12, UITheme.TEXT2))
			row.add_child(UITheme.label(item["time"], 11, UITheme.MUTED))
			v.add_child(row)
			continue
		var box := _comment_box(item["from"], item["time"], item["text"])
		var choices: Array = item["choices"]
		if not choices.is_empty() and item["answered"] == "":
			var opts := UITheme.vbox(6)
			for c in choices:
				var b := UITheme.button(c["label"], "primary")
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
	head.add_child(UITheme.bold("나" if from == "me" else Game.npc_name(from), 13))
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
			v.add_child(UITheme.label("CI 실행 중... (테스트 + [CI] 추가 검증)", 13, UITheme.WARN))
		_:
			v.add_child(UITheme.bold("통과 %d · 실패 %d" % [int(ci["passed"]), int(ci["failed"])], 15, UITheme.OK if ci["state"] == "pass" else UITheme.ERR))
			if int(ci.get("hidden", 0)) > 0:
				v.add_child(UITheme.label("이 PR에는 [CI] 추가 검증 테스트 %d개 파일이 함께 실행되었습니다." % int(ci["hidden"]), 12, UITheme.MUTED))
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
				v.add_child(UITheme.label("모든 테스트가 통과했습니다.", 13, UITheme.TEXT2))
	return UITheme.scroll(UITheme.margin(v, 14))


func _fill_diff(p: Dictionary, holder: VBoxContainer) -> void:
	var id := int(p["id"])
	var cache: Dictionary = _diff_cache.get(id, {})
	if cache.get("head", "") != p["head"] or p["state"] == "merged" and cache.is_empty():
		holder.add_child(UITheme.margin(UITheme.label("변경 사항 불러오는 중...", 12, UITheme.MUTED), 14))
		var text := ""
		if p["state"] == "merged":
			text = String(cache.get("text", ""))
		if text == "":
			text = await Workspace.pr_diff(p["branch"])
		cache = {"head": p["head"], "text": text}
		_diff_cache[id] = cache
		if not is_instance_valid(holder):
			return
		UITheme.clear(holder)
	var selectable: bool = p["reviewer"] == "me" and p["state"] == "open" and p["review"]["state"] != "approved"
	var v := UITheme.vbox(0)
	if selectable:
		v.add_child(UITheme.margin(UITheme.label("리뷰할 줄을 클릭해서 선택하세요. (선택한 줄은 리뷰 코멘트에 포함됩니다)", 12, UITheme.WARN), 8))
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
			var m := line.get_slice("+", 1).get_slice(",", 0).get_slice(" ", 0)
			new_line = int(m) - 1
			v.add_child(UITheme.margin(UITheme.label(line, 11, Color("6b8fd6"), true), 4))
			continue
		var kind := line.left(1)
		if kind != "-":
			new_line += 1
		v.add_child(_diff_line(file, new_line if kind != "-" else 0, line, selectable))
	holder.add_child(UITheme.scroll(v))


func _diff_line(file: String, num: int, line: String, selectable: bool) -> Control:
	var kind := line.left(1)
	var key := "%s:%d" % [file, num]
	var picked := _picked.has(key)
	var bg := Color(0, 0, 0, 0)
	if kind == "+":
		bg = Color(UITheme.OK, 0.10)
	elif kind == "-":
		bg = Color(UITheme.ERR, 0.10)
	if picked:
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
		row.add_child(UITheme.label("이 PR은 병합되었습니다." if p["state"] == "merged" else "닫힌 PR입니다.", 13, UITheme.TEXT2))
		return row
	if p["reviewer"] == "me":
		var done: bool = p["review"]["state"] == "approved"
		row.add_child(UITheme.label("선택한 줄 %d개" % _picked.size(), 12, UITheme.WARN if _picked.size() > 0 else UITheme.MUTED))
		var note := LineEdit.new()
		note.placeholder_text = "리뷰 코멘트 (선택)"
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(note)
		var changes := UITheme.button("변경 요청", "danger")
		var approve := UITheme.button("승인", "ok")
		changes.disabled = done or p["ci"]["state"] == "running"
		approve.disabled = done or p["ci"]["state"] == "running"
		var pid := int(p["id"])
		changes.pressed.connect(func() -> void:
			var lines := _picked.values()
			_picked.clear()
			CodeHub.submit_review(pid, "changes", lines, note.text))
		approve.pressed.connect(func() -> void:
			var lines := _picked.values()
			_picked.clear()
			CodeHub.submit_review(pid, "approve", lines, note.text))
		row.add_child(changes)
		row.add_child(approve)
		return row
	var blockers := CodeHub.merge_blockers(p)
	row.add_child(UITheme.label("병합 가능" if blockers.is_empty() else "병합하려면: " + ", ".join(blockers), 12, UITheme.OK if blockers.is_empty() else UITheme.MUTED))
	row.add_child(UITheme.spacer())
	var merge := UITheme.button("Merge pull request", "ok")
	merge.custom_minimum_size = Vector2(170, 34)
	merge.disabled = not blockers.is_empty() or _busy
	var pid := int(p["id"])
	merge.pressed.connect(func() -> void:
		_busy = true
		merge.disabled = true
		await CodeHub.merge(pid)
		_busy = false
		_render_detail())
	row.add_child(merge)
	return row
