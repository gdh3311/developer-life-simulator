extends VBoxContainer
## AICode operates on the company's real local checkout using in-game task recipes.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const Draft := preload("res://scripts/services/agent_draft.gd")
const Reports := preload("res://scripts/services/agent_report.gd")
const ACCENT := Color("d5aff8")
const COST_REPOSITORY := 60
const COST_FILE := 80
const COST_TESTS := 120
const COST_REVIEW := 160
const COST_HINT := 60
const PASTE_LIMIT := 12000

var desktop: Control
var _feed: VBoxContainer
var _scroll: ScrollContainer
var _actions: HFlowContainer
var _files: OptionButton
var _read_file: Button
var _scope: Label
var _budget: Label
var _token_bar: ProgressBar
var _clip_panel: VBoxContainer
var _clip_code: TextEdit
var _clip_scope: Label
var _clip_prepare: Button
var _clip_apply: Button
var _clipboard_feedback: Label
var _busy := false
var _draft := {}
var _last_application := {}


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var head := UITheme.hbox(10)
	head.add_child(Icon.make("ai", ACCENT, 26))
	var heading := UITheme.vbox(2)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(UITheme.bold("AICode  /  commerce-api", 17, ACCENT))
	_scope = UITheme.wrap("", 12, UITheme.TEXT2)
	heading.add_child(_scope)
	head.add_child(heading)
	var quota := UITheme.vbox(3)
	quota.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_budget = UITheme.label("", 12, ACCENT)
	quota.add_child(_budget)
	_token_bar = ProgressBar.new()
	_token_bar.custom_minimum_size = Vector2(117, 6)
	_token_bar.show_percentage = false
	_token_bar.max_value = Game.ai_daily_tokens()
	_token_bar.add_theme_stylebox_override("background", UITheme.box(Color("292234"), 4))
	_token_bar.add_theme_stylebox_override("fill", UITheme.box(Color("ae81e4"), 4))
	quota.add_child(_token_bar)
	head.add_child(quota)
	add_child(UITheme.margin(head, 12))

	var toolbar := UITheme.panel(UITheme.BG0, 0, 10, Color.TRANSPARENT)
	var tools := UITheme.vbox(7)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 7)
	_actions.add_theme_constant_override("v_separation", 6)
	tools.add_child(_actions)
	var source := UITheme.hbox(8)
	_files = OptionButton.new()
	_files.fit_to_longest_item = false
	_files.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_files.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_files.item_selected.connect(func(_i: int) -> void: _update_clip_controls())
	source.add_child(_files)
	_read_file = _button(source, _priced(Game.L("파일 조사", "Inspect file"), COST_FILE), _on_file)
	_button(source, Game.L("코드 붙여넣기 창", "Paste code panel"), _toggle_clipboard)
	tools.add_child(source)
	tools.add_child(_build_clip_panel())
	_clipboard_feedback = UITheme.wrap("", 12, UITheme.OK)
	_clipboard_feedback.hide()
	tools.add_child(_clipboard_feedback)
	toolbar.add_child(tools)
	add_child(toolbar)

	_feed = UITheme.vbox(11)
	_scroll = UITheme.scroll(UITheme.margin(_feed, 12))
	add_child(_scroll)
	Story.objectives_changed.connect(_render_actions)
	Game.state_reset.connect(_reset)
	Game.ai_tokens_changed.connect(_render_actions)
	Workspace.repo_changed.connect(_load_files)
	_load_files()
	_report(Game.L("작업 요청", "Ask AICode"),
		Game.L("요청마다 토큰을 사용합니다. 자동 적용은 지원 업무의 변경안을 만들고 현재 작업 브랜치에 저장합니다. 토큰은 다음 근무일에 충전됩니다.",
			"Requests use tokens. Auto-apply drafts supported tasks and saves the changes on your working branch. Tokens refill on the next workday."))


func _reset() -> void:
	_draft.clear()
	_last_application.clear()
	_clip_code.clear()
	_load_files()


func _build_clip_panel() -> VBoxContainer:
	_clip_panel = UITheme.vbox(6)
	_clip_scope = UITheme.wrap("", 12, UITheme.TEXT2)
	_clip_panel.add_child(_clip_scope)
	_clip_code = TextEdit.new()
	_clip_code.custom_minimum_size.y = 82
	_clip_code.placeholder_text = Game.L("교체할 파일의 전체 코드를 여기에 붙여넣기", "Paste the complete replacement contents here")
	_clip_code.add_theme_font_override("font", UITheme.font(true))
	_clip_code.text_changed.connect(_update_clip_controls)
	_clip_panel.add_child(_clip_code)
	var controls := HFlowContainer.new()
	_button(controls, Game.L("클립보드에서 붙여넣기", "Paste from clipboard"), func() -> void:
		_clip_code.paste()
		_clip_code.grab_focus())
	_clip_prepare = _button(controls, "", _on_pasted_code)
	_clip_apply = _button(controls, "", _on_pasted_code.bind(true), true)
	_clip_panel.add_child(controls)
	_clip_panel.hide()
	return _clip_panel


func _toggle_clipboard() -> void:
	_clip_panel.visible = not _clip_panel.visible
	if _clip_panel.visible:
		_clip_code.grab_focus()


func _paste_cost() -> int:
	return 220 + ceili(float(_clip_code.text.length()) / 24.0)


func _update_clip_controls() -> void:
	var target := _selected_file()
	var label := Game.L("교체 대상 · %s", "Replacement target · %s") % target
	_clip_scope.text = label if target != "" else Game.L("저장소 파일을 선택하세요.", "Choose a repository file.")
	var length := _clip_code.text.length()
	if length > PASTE_LIMIT:
		_clip_scope.text += Game.L("  ·  최대 %d자", "  ·  Up to %d characters") % PASTE_LIMIT
	_clip_prepare.text = _priced(Game.L("교체 초안 보기", "Preview replacement"), _paste_cost())
	_clip_apply.text = _priced(Game.L("선택 파일에 바로 저장", "Apply to selected file"), _paste_cost())
	var unavailable := not _can_run() or not _draft.is_empty() or target.is_empty() or length == 0 or length > PASTE_LIMIT or not _can_afford(_paste_cost())
	_clip_prepare.disabled = unavailable
	_clip_apply.disabled = unavailable


func _load_files() -> void:
	var old := _selected_file()
	_files.clear()
	if Workspace.is_ready and Workspace.exists():
		var paths := Workspace.list_files()
		paths.sort()
		for path in paths:
			if not String(path).get_extension().to_lower() in ["ts", "md", "json"]:
				continue
			_files.add_item(path)
			var i := _files.item_count - 1
			_files.set_item_metadata(i, path)
			if path == old:
				_files.select(i)
	if _files.item_count == 0:
		_files.add_item(Game.L("저장소 파일 없음", "No repository files"))
	_render_actions()


func _selected_file() -> String:
	if _files.selected < 0:
		return ""
	var selected = _files.get_selected_metadata()
	return selected if selected is String else ""


func _can_run() -> bool:
	return not _busy and Workspace.is_ready and Workspace.exists()


func _priced(label: String, cost: int) -> String:
	return "%s · %d" % [label, cost]


func _can_afford(cost: int) -> bool:
	return cost <= Game.ai_tokens_remaining()


func _paid_action(label: String, cost: int, callback: Callable) -> Button:
	var btn := _button(_actions, _priced(label, cost), callback)
	btn.disabled = not _can_run() or not _can_afford(cost)
	return btn


func _render_actions() -> void:
	UITheme.clear(_actions)
	var m = Story.active
	if not _draft.is_empty() and _draft["mission"] != "" and (m == null or _draft["mission"] != m.id):
		_draft.clear()
	var scope := Workspace.branch if Workspace.branch != "" else Game.L("분리된 HEAD", "Detached HEAD")
	if m != null:
		scope += "  ·  " + m.title_text()
	_scope.text = Game.L("요청 실행 중…", "Running request…") if _busy else scope
	var remaining := Game.ai_tokens_remaining()
	_token_bar.max_value = Game.ai_daily_tokens()
	_budget.text = Game.L("%d / %d 토큰", "%d / %d tokens") % [remaining, Game.ai_daily_tokens()]
	_budget.add_theme_color_override("font_color", UITheme.WARN if remaining < 240 else ACCENT)
	_token_bar.value = remaining
	_budget.tooltip_text = Game.L("다음 근무일에 충전됩니다. 지금은 DevIDE와 Terminal에서 직접 작업할 수 있습니다.",
		"Refills on the next workday. You can work directly in DevIDE and Terminal.")
	if remaining < COST_HINT:
		_scope.text += Game.L("  ·  다음 근무일에 충전", "  ·  Refills next workday")
	_files.disabled = not _can_run() or _selected_file() == ""
	_read_file.disabled = _files.disabled or not _can_afford(COST_FILE)
	_paid_action(Game.L("저장소 조사", "Inspect repository"), COST_REPOSITORY, _on_repository)
	_paid_action(Game.L("로컬 테스트", "Run local tests"), COST_TESTS, _on_tests)
	_paid_action(Game.L("PR 초안", "Review / PR draft"), COST_REVIEW, _on_review)
	var hint := _paid_action(Game.L("힌트", "Hint"), COST_HINT, _on_hint)
	hint.disabled = hint.disabled or m == null or m.hints.is_empty() or int(m.data().get("hint", 0)) >= m.hints.size()
	if m != null and not m.ai_task.is_empty() and not m.data().get("ai_used", false) and _draft.is_empty():
		var cost := _task_cost(m.ai_task)
		_paid_action(Game.L("초안 보기", "Draft preview"), cost, _on_delegate)
		var auto_apply := _button(_actions, _priced(Game.L("자동 적용", "Auto-apply"), cost), _on_delegate.bind(true), true)
		auto_apply.disabled = not _can_run() or not _can_afford(cost)
	if not _draft.is_empty():
		_button(_actions, Game.L("초안 적용", "Apply draft"), _apply_draft, true).disabled = not _can_run()
		_button(_actions, Game.L("초안 닫기", "Dismiss draft"), _dismiss_draft).disabled = _busy
	if not _last_application.is_empty():
		_button(_actions, Game.L("최근 적용 되돌리기", "Undo last apply"), _undo_application).disabled = not _can_run()
	_update_clip_controls()


func _button(parent: Control, label: String, callback: Callable, primary := false) -> Button:
	var btn := UITheme.button(label, "primary" if primary else "")
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _on_hint() -> void:
	var m = Story.active
	if not _can_run() or m == null or int(m.data().get("hint", 0)) >= m.hints.size() or not Game.spend_ai_tokens(COST_HINT):
		return
	var hint: String = Story.next_hint()
	if hint != "":
		_report(Game.L("현재 업무 힌트", "Hint for the current task"), hint)


func _on_repository() -> String:
	if not _can_run() or not Game.spend_ai_tokens(COST_REPOSITORY):
		return ""
	_busy = true
	_render_actions()
	var result := await Reports.repository()
	_report(Game.L("저장소 조사", "Repository inspection"),
		Game.L("현재 브랜치, 변경 파일과 최근 커밋입니다.", "Current branch, changed files and recent commits."), result)
	_busy = false
	_render_actions()
	return result


func _on_file() -> void:
	var path := _selected_file()
	if not _can_run() or path.is_empty() or not Game.spend_ai_tokens(COST_FILE):
		return
	var card := _report(path, Game.L("저장된 파일의 주요 줄과 테스트 참조입니다.", "Key lines and test references in the saved file."), Reports.inspect(path))
	if desktop != null:
		_button(card, Game.L("DevIDE에서 열기", "Open in DevIDE"), desktop.open_resource.bind("ide", path)).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _on_tests() -> Dictionary:
	if not _can_run() or not Game.spend_ai_tokens(COST_TESTS):
		return {}
	_busy = true
	var branch := Workspace.branch
	_render_actions()
	var result := await Workspace.run_tests()
	_report(Game.L("로컬 테스트 · %s", "Local tests · %s") % branch,
		Game.L("실행 범위는 저장소의 tests/입니다. 추가 CI 검증은 CodeHub의 PR에서 확인합니다.",
			"These results cover the repository's tests/ directory. Additional CI checks run on the PR in CodeHub."), Reports.tests(result))
	_busy = false
	_render_actions()
	return result


func _on_review() -> Dictionary:
	if not _can_run() or not Game.spend_ai_tokens(COST_REVIEW):
		return {}
	_busy = true
	_render_actions()
	var result := await Reports.review()
	var card := _report(Game.L("작업 브랜치 검토", "Working branch review"),
		result.get("error", ""), result.get("report", ""))
	if result.has("draft"):
		var brief: String = result["draft"]
		_report(Game.L("PR 제목·설명 초안", "PR title and description draft"),
			Game.L("변경 요약을 바탕으로 작성했습니다. 업무 맥락과 실제 검증 결과를 채워 주세요.",
				"The change summary comes from Git. Fill in the task context and actual verification results."), brief)
	if desktop != null:
		_button(card, Game.L("Pork Git에서 줄별 변경 보기", "See line changes in Pork Git"),
			desktop.open_resource.bind("pork", "")).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_busy = false
	_render_actions()
	return result


func _task_cost(task: Dictionary) -> int:
	var files: Dictionary = task.get("files", {})
	return 240 + 80 * maxi(1, files.size())


func _on_delegate(auto_apply := false) -> bool:
	var m = Story.active
	if not _can_run() or not _draft.is_empty() or m == null or m.ai_task.is_empty() or m.data().get("ai_used", false):
		return false
	var cost := _task_cost(m.ai_task)
	if not _can_afford(cost):
		return false
	var result := Draft.make(m.ai_task)
	if result.has("error"):
		_report(Game.L("업무 초안", "Task draft"), result["error"])
		return false
	var job := _new_draft(result, m.id, Game.tx(m.ai_task["label"]), Game.tx(m.ai_task["summary"]), int(m.ai_task.get("minutes", 15)))
	if auto_apply:
		return _apply_changes(job, cost)
	if not Game.spend_ai_tokens(cost):
		return false
	_preview_draft(job)
	return true


func _on_pasted_code(auto_apply := false) -> bool:
	var text := _clip_code.text
	var cost := _paste_cost()
	if not _can_run() or not _draft.is_empty() or text.is_empty() or text.length() > PASTE_LIMIT or not _can_afford(cost):
		return false
	var path := _selected_file()
	var result := Draft.replacement(path, text)
	if result.has("error"):
		_report(Game.L("파일 교체", "Replace file contents"), result["error"])
		return false
	var title := Game.L("붙여넣은 코드 · %s", "Pasted code · %s") % path
	var job := _new_draft(result, "", title, Game.L("선택한 파일에 붙여넣은 코드를 저장했습니다.", "Saved the pasted code to the selected file."), 0)
	if auto_apply:
		if not _apply_changes(job, cost):
			return false
	else:
		if not Game.spend_ai_tokens(cost):
			return false
		_preview_draft(job)
	_clip_panel.hide()
	return true


func _new_draft(result: Dictionary, mission: String, title: String, summary: String, minutes: int) -> Dictionary:
	return {"mission": mission, "branch": Workspace.branch, "head": Workspace._snap.get("head", ""),
		"title": title, "summary": summary, "minutes": minutes, "changes": result["changes"], "patch": result["patch"]}


func _preview_draft(job: Dictionary) -> void:
	_draft = job
	var note := Game.L("기준 브랜치 · %s", "Base branch · %s") % job["branch"]
	if int(job["minutes"]) > 0:
		note += Game.L(" · 적용 시 업무 시간 %d분", " · %d in-game minutes to apply") % job["minutes"]
	var conflicts := Draft.divergent_files(job["changes"])
	if not conflicts.is_empty():
		note += "\n" + Game.L("기준과 다른 파일이 있어요. 변경안을 참고해 DevIDE에서 직접 합쳐 주세요.", "Some files differ from the draft's base. Use the preview to reconcile them in DevIDE.")
		note += "\n" + ", ".join(conflicts)
	var card := _report(job["title"], note, job["patch"], Game.L("Diff 복사", "Copy diff"))
	_code_copies(card, job["changes"])
	_render_actions()


func _apply_draft() -> bool:
	if _draft.is_empty() or not _apply_changes(_draft, 0):
		return false
	_draft = {}
	_render_actions()
	return true


func _apply_changes(job: Dictionary, cost: int) -> bool:
	if not _can_run() or not _can_afford(cost):
		return false
	var m = Story.active
	if job["mission"] != "" and (m == null or job["mission"] != m.id or m.data().get("ai_used", false)):
		return false
	var problem := _apply_problem(job)
	if problem == "":
		problem = Workspace.apply_agent_patch(job["patch"])
	if problem != "":
		_report(Game.L("초안 적용 대기", "Draft waiting to be applied"), problem)
		return false
	_last_application = job.duplicate(true)
	if cost > 0:
		Game.spend_ai_tokens(cost)
	var changes: Dictionary = job["changes"]
	if job["mission"] != "":
		m.data()["ai_used"] = true
		Game.advance(job["minutes"])
		Game.inc_stat("ai_used")
		Game.emit_event("ai_used", {"paths": changes.keys()})
	for path in changes:
		Game.emit_event("file_saved", {"path": path})
	var card := _report(Game.L("작업 브랜치에 적용했습니다", "Applied to the working branch"), job["summary"], job["patch"], Game.L("Diff 복사", "Copy diff"))
	_code_copies(card, changes)
	if desktop != null:
		_button(card, Game.L("Pork Git에서 변경 검토", "Review changes in Pork Git"),
			desktop.open_resource.bind("pork", "")).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_render_actions()
	return true


func _apply_problem(job: Dictionary, reverse := false) -> String:
	if Workspace.branch in ["main", ""]:
		return Game.L("Terminal이나 Pork Git에서 작업 브랜치를 만든 뒤 초안을 다시 생성하세요.",
			"Create a working branch in Terminal or Pork Git, then generate a draft there.")
	if Workspace.branch != job["branch"] or Workspace._snap.get("head", "") != job["head"]:
		return Game.L("초안을 만들 때와 브랜치 또는 커밋이 달라졌습니다. 현재 작업에서 다시 생성하세요.",
			"The branch or commit changed after this draft. Generate a new draft for the current checkout.")
	var changes: Dictionary = job["changes"]
	if reverse:
		changes = {}
		for path in job["changes"]:
			changes[path] = {"exists": true, "before": job["changes"][path]["after"]}
	var conflicts := Draft.divergent_files(changes)
	if not conflicts.is_empty():
		return Game.L("파일 버전이 초안과 다릅니다. 현재 내용을 검토하세요. ", "File versions differ from the draft. Review the current contents. ") + ", ".join(conflicts)
	if desktop != null and desktop._open.has("ide"):
		var ide = desktop._find_method(desktop._open["ide"], "has_unsaved_changes")
		for path in changes:
			if ide != null and ide.has_unsaved_changes(path):
				return Game.L("DevIDE에서 이 파일을 먼저 저장하거나 변경을 취소하세요. ", "Save or discard the edit in DevIDE first. ") + path
	return ""


func _undo_application() -> bool:
	if not _can_run() or _last_application.is_empty():
		return false
	var problem := _apply_problem(_last_application, true)
	if problem == "":
		problem = Workspace.apply_agent_patch(_last_application["patch"], true)
	if problem != "":
		_report(Game.L("되돌리기 확인", "Check before reverting"), problem)
		return false
	var paths: Array = _last_application["changes"].keys()
	_last_application.clear()
	for path in paths:
		Game.emit_event("file_saved", {"path": path})
	_report(Game.L("작업 사본을 되돌렸습니다", "Reverted the working copy"), "\n".join(paths))
	_render_actions()
	return true


func _dismiss_draft() -> void:
	_draft.clear()
	_render_actions()


func _copy_to_clipboard(source: String) -> void:
	DisplayServer.clipboard_set(source)
	_clipboard_feedback.text = Game.L("클립보드에 복사했습니다.", "Copied to the clipboard.")
	_clipboard_feedback.show()


func _code_copies(card: VBoxContainer, changes: Dictionary) -> void:
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 7)
	card.add_child(buttons)
	for path in changes:
		var label := Game.L("%s 코드 복사", "Copy %s code") % String(path).get_file()
		_button(buttons, label, _copy_to_clipboard.bind(changes[path]["after"]))


func _report(title: String, body: String, detail := "", copy_label := "") -> VBoxContainer:
	var shell := UITheme.panel(Color("242033"), 9, 12, Color("413251"))
	var card := UITheme.vbox(7)
	var header := UITheme.wrap(title, 15, ACCENT)
	header.add_theme_font_override("font", UITheme.font(false, true))
	card.add_child(header)
	if body != "":
		card.add_child(UITheme.wrap(body, 13, UITheme.TEXT2))
	if detail != "":
		var text := RichTextLabel.new()
		text.fit_content = true
		text.scroll_active = false
		text.selection_enabled = true
		text.add_theme_font_override("normal_font", UITheme.font(true))
		text.add_theme_font_size_override("normal_font_size", 12)
		var lines := detail.left(12000).split("\n")
		for i in lines.size():
			var line := lines[i]
			text.push_color(UITheme.OK if line.begins_with("+") or line.begins_with("✓") else (UITheme.ERR if line.begins_with("-") or line.begins_with("✗") else UITheme.TEXT))
			text.add_text(line + ("\n" if i < lines.size() - 1 else ""))
			text.pop()
		card.add_child(text)
	var source := detail if detail != "" else body
	if source != "":
		var label := copy_label if copy_label != "" else Game.L("복사", "Copy")
		_button(card, label, _copy_to_clipboard.bind(source)).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	shell.add_child(card)
	_feed.add_child(shell)
	_scroll_to.call_deferred(shell)
	return card


func _scroll_to(report: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(report) and is_instance_valid(_scroll):
		_scroll.scroll_vertical = roundi(report.position.y)
