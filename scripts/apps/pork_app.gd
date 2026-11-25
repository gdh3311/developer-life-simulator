extends MarginContainer
## Local Git client for the same working copy used by Terminal and DevIDE.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const ACCENT := Color("f39677")

var desktop: Control
var _branches: OptionButton
var _branch_name: LineEdit
var _message: LineEdit
var _tabs: TabContainer
var _changes: ItemList
var _history: ItemList
var _diff: RichTextLabel
var _status: Label
var _stage: Button
var _unstage: Button
var _commit: Button
var _operation_bar: HFlowContainer
var _reading := false
var _working := false
var _dirty := true
var _detail_request := 0


func _ready() -> void:
	for side in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, 14)
	var page := UITheme.vbox(9)
	add_child(page)
	page.add_child(UITheme.bold("commerce-api", 21, ACCENT))

	_operation_bar = HFlowContainer.new()
	_operation_bar.add_theme_constant_override("h_separation", 7)
	page.add_child(_operation_bar)
	_branches = OptionButton.new()
	_branches.custom_minimum_size.x = 130
	_branches.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_branches.fit_to_longest_item = false
	_operation_bar.add_child(_branches)
	_add_action(_operation_bar, Game.L("전환", "Switch"), _switch_branch)
	_branch_name = LineEdit.new()
	_branch_name.placeholder_text = "docs/fix-typo"
	_branch_name.custom_minimum_size.x = 136
	_branch_name.max_length = 80
	_operation_bar.add_child(_branch_name)
	_add_action(_operation_bar, Game.L("새 브랜치", "New branch"), _new_branch)
	_add_action(_operation_bar, "Pull", func() -> void: await _execute(["pull", "--ff-only"]))
	_add_action(_operation_bar, "Push", func() -> void: await _execute(["push"]))
	_add_action(_operation_bar, Game.L("PR 열기", "Open PRs"), func() -> void:
		if desktop != null:
			desktop.open_resource("codehub", ""))

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 36
	page.add_child(split)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size.x = 235
	split.add_child(_tabs)
	_changes = _list(Game.L("변경 파일", "Changes"))
	_history = _list(Game.L("커밋 기록", "History"))
	_tabs.tab_changed.connect(_show_selection)
	_diff = RichTextLabel.new()
	_diff.custom_minimum_size.x = 142
	_diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff.selection_enabled = true
	_diff.add_theme_stylebox_override("normal", UITheme.box(UITheme.BG1, 8, UITheme.LINE, 10))
	_diff.add_theme_font_override("normal_font", UITheme.font(true))
	_diff.add_theme_font_size_override("normal_font_size", 12)
	split.add_child(_diff)

	var staging := HFlowContainer.new()
	staging.add_theme_constant_override("h_separation", 7)
	page.add_child(staging)
	_stage = _add_action(staging, Game.L("스테이징", "Stage"), func() -> void: await _stage_file(false))
	_unstage = _add_action(staging, Game.L("스테이징 해제", "Unstage"), func() -> void: await _stage_file(true))
	_message = LineEdit.new()
	_message.placeholder_text = Game.L("커밋 메시지", "Commit message")
	_message.custom_minimum_size.x = 140
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.max_length = 240
	_message.text_changed.connect(func(_value: String) -> void: _update_actions())
	staging.add_child(_message)
	_commit = _add_action(staging, Game.L("커밋", "Commit"), _commit_changes)
	_status = UITheme.label("", 12, UITheme.TEXT2)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	page.add_child(_status)
	Workspace.repo_changed.connect(_queue_refresh)
	Game.event.connect(_on_game_event)
	_queue_refresh()


func _list(label: String) -> ItemList:
	var list := ItemList.new()
	list.name = label
	list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.add_theme_stylebox_override("panel", UITheme.box(Color("151a23"), 5, UITheme.LINE, 4))
	list.add_theme_stylebox_override("selected", UITheme.box(Color("362d32"), 5))
	list.add_theme_stylebox_override("selected_focus", UITheme.box(Color("51372f"), 5))
	list.item_selected.connect(func(_index: int) -> void: _show_selection(_tabs.current_tab))
	_tabs.add_child(list)
	return list


func _add_action(parent: Control, label: String, action: Callable) -> Button:
	var button := UITheme.button(label)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _on_game_event(kind: String, _data: Dictionary) -> void:
	if kind == "file_saved":
		_queue_refresh()


func _queue_refresh() -> void:
	_dirty = true
	if not _working and not _reading:
		_refresh.call_deferred()


func _refresh() -> void:
	if _working or _reading or not _dirty:
		return
	_dirty = false
	if not Workspace.is_ready:
		_update_actions()
		_status.text = Game.L("저장소가 준비되면 파일과 커밋이 표시됩니다.", "Files and commits appear when the repository is ready.")
		return
	_reading = true
	_update_actions()
	var refs := await Workspace.local_branches()
	var status := await Workspace._working_git(["-c", "core.quotepath=false", "status", "--porcelain=v1", "--untracked-files=all", "--no-renames"])
	var log := await Workspace._working_git(["log", "--all", "-n", "40", "--format=%H%x09%h%x09%D%x09%s"])
	var previous := _selected(_changes)
	var previous_commit := _selected(_history)
	_branches.clear()
	for ref in refs:
		var current: bool = ref == Workspace.branch
		_branches.add_item(("●  " if current else "") + ref)
		var i := _branches.item_count - 1
		_branches.set_item_metadata(i, ref)
		if current:
			_branches.select(i)
	_branches.tooltip_text = Game.L("현재 브랜치 · ", "Current branch · ") + Workspace.branch
	_changes.clear()
	for line in String(status["out"]).split("\n", false):
		if line.length() < 4:
			continue
		var path := line.substr(3)
		if path.begins_with('"'):
			var decoded = JSON.parse_string(path)
			if decoded is String:
				path = decoded
		var state := line.left(2)
		_changes.add_item(path + "   ·   " + _change_label(state))
		var i := _changes.item_count - 1
		_changes.set_item_metadata(i, {"id": path, "state": state})
		_changes.set_item_tooltip(i, path + " · " + _change_label(state))
		_changes.set_item_custom_fg_color(i, Color("f8ca89") if state == "??" else UITheme.TEXT)
		if previous.get("id") == path:
			_changes.select(i)
	_history.clear()
	for line in String(log["out"]).split("\n", false):
		var columns := line.split("\t", true, 3)
		if columns.size() != 4:
			continue
		var decoration := "  ·  " + columns[2] if columns[2] != "" else ""
		_history.add_item(columns[1] + "  " + columns[3] + decoration)
		var i := _history.item_count - 1
		_history.set_item_metadata(i, {"id": columns[0]})
		_history.set_item_tooltip(i, columns[3] + decoration)
		if previous_commit.get("id") == columns[0]:
			_history.select(i)
	_reading = false
	if status["code"] != 0 or log["code"] != 0:
		var warning := (String(status["err"]) + " " + String(log["err"])).strip_edges()
		_status.text = warning.replace("\n", " ")
		_status.tooltip_text = warning
	elif _status.text == "":
		_status.text = Game.L("현재 브랜치 · ", "Current branch · ") + Workspace.branch
	_update_actions()
	_show_selection(_tabs.current_tab, false)
	if _dirty:
		_refresh.call_deferred()


func _selected(list: ItemList) -> Dictionary:
	var items := list.get_selected_items()
	return list.get_item_metadata(items[0]) if not items.is_empty() else {}


func _change_label(state: String) -> String:
	if state == "??":
		return Game.L("새 파일", "Untracked")
	if "U" in state or state in ["DD", "AA"]:
		return Game.L("충돌", "Conflict")
	if state[0] == " ":
		return Game.L("작업 중", "Modified")
	if state[1] == " ":
		return Game.L("스테이징됨", "Staged")
	return Game.L("일부 스테이징됨", "Partially staged")


func _show_selection(tab: int, report := true) -> void:
	_detail_request += 1
	var request := _detail_request
	var item := _selected(_history if tab == 1 else _changes)
	_update_actions()
	if item.is_empty():
		_diff.text = Game.L("목록에서 파일이나 커밋을 선택하세요.", "Select a file or commit to inspect it.")
		return
	var id: String = item["id"]
	_diff.text = Game.L("변경 내용 불러오는 중…", "Reading changes…")
	if tab == 1:
		var commit := await Workspace._working_git(["show", "--no-ext-diff", "--format=fuller", "--stat", "--patch", id])
		if report and commit["code"] == 0:
			Game.emit_event("command_finished", {"argv": ["git", "show", id], "code": 0, "out": String(commit["out"])})
		if request == _detail_request:
			var details := String(commit["out"]) + String(commit["err"])
			if commit["code"] == 0 and "\ndiff --git " not in details:
				details += Game.L("\n이 커밋에서 표시할 파일 변경이 없습니다.", "\nThis commit has no file changes to display.")
			_show_diff(details)
	elif item["state"] == "??":
		_show_diff(Game.L("새 파일 · ", "Untracked file · ") + id + "\n+" + Workspace.read_file(id).left(10000).replace("\n", "\n+"))
	else:
		var staged := await Workspace._working_git(["diff", "--cached", "--no-ext-diff", "--", id], true)
		var working := await Workspace._working_git(["diff", "--no-ext-diff", "--", id], true)
		if request != _detail_request:
			return
		var staged_text := String(staged["out"])
		var working_text := String(working["out"])
		var combined := (Game.L("스테이징됨", "STAGED") + "\n" + staged_text + "\n" if staged_text != "" else "") + working_text
		_show_diff(combined + String(staged["err"]) + String(working["err"]))
		if report and combined != "" and staged["code"] == 0 and working["code"] == 0:
			Game.emit_event("command_finished", {"argv": ["git", "diff", "--", id], "code": 0, "out": combined})


func _show_diff(source: String) -> void:
	_diff.clear()
	for line in source.left(24000).split("\n"):
		var tint := UITheme.TEXT
		if line.begins_with("+"):
			tint = Color("93dfb1")
		elif line.begins_with("-"):
			tint = Color("f3a3a9")
		elif line.begins_with("@@"):
			tint = Color("a4b5ff")
		_diff.push_color(tint)
		_diff.add_text(line + "\n")
		_diff.pop()


func _update_actions() -> void:
	var unavailable := not Workspace.is_ready or _working or _reading
	var item := _selected(_changes)
	var state: String = item.get("state", "  ")
	var has_staged := false
	for index in _changes.item_count:
		var file_state: String = _changes.get_item_metadata(index)["state"]
		if file_state[0] not in [" ", "?"]:
			has_staged = true
			break
	_stage.disabled = unavailable or _tabs.current_tab != 0 or state[1] == " "
	_unstage.disabled = unavailable or _tabs.current_tab != 0 or state[0] in [" ", "?"]
	_commit.disabled = unavailable or not has_staged or _message.text.strip_edges().is_empty()
	for child in _operation_bar.get_children():
		if child is BaseButton and child != _operation_bar.get_child(-1):
			child.disabled = unavailable


func _switch_branch() -> void:
	if _branches.selected < 0:
		return
	var selected: String = _branches.get_selected_metadata()
	if selected != Workspace.branch:
		await _execute(["switch", selected])


func _new_branch() -> void:
	var name := _branch_name.text.strip_edges()
	var branch_pattern := RegEx.create_from_string("^[a-zA-Z0-9][a-zA-Z0-9._/-]{0,79}$")
	if branch_pattern.search(name) == null:
		_status.text = Game.L("브랜치 이름을 입력하세요. 예: docs/fix-typo", "Enter a branch name such as docs/fix-typo.")
		return
	if await _execute(["switch", "-c", name]):
		_branch_name.clear()


func _stage_file(unstage: bool) -> void:
	var item := _selected(_changes)
	if item.is_empty():
		return
	var args := ["restore", "--staged"] if unstage else ["add"]
	await _execute(args + ["--", item["id"]], true)


func _commit_changes() -> void:
	var message := _message.text.strip_edges()
	if message != "" and await _execute(["commit", "-m", message]):
		_message.clear()
		_update_actions()


func _execute(args: Array, literal_path := false) -> bool:
	if _working or _reading or not Workspace.is_ready:
		return false
	var why := Workspace.check_git_args(args)
	if why != "":
		_status.text = why
		return false
	_working = true
	_update_actions()
	var result := await Workspace.git(args, literal_path)
	Game.emit_event("command_finished", {"argv": ["git"] + args, "code": result["code"], "out": result["out"]})
	var ok: bool = result["code"] == 0
	var report := (String(result["out"]) + "\n" + String(result["err"])).strip_edges()
	_status.text = Game.L("완료 · git ", "Done · git ") + args[0] if ok else report.replace("\n", " ")
	_status.tooltip_text = report
	_working = false
	_queue_refresh()
	return ok
