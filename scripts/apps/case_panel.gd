extends VBoxContainer
## Evidence cards and revisable hypotheses, displayed beside the existing work flow.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
var desktop: Control
var _pending := false


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	Cases.changed.connect(_refresh)
	Story.objectives_changed.connect(_refresh)
	_render()


func _refresh() -> void:
	if not _pending:
		_pending = true
		_render.call_deferred()


func _render() -> void:
	_pending = false
	UITheme.clear(self)
	var id: String = Story.active.id if Story.active != null else ""
	if not Cases.has_case(id):
		add_child(UITheme.bold(Game.L("조사 노트", "Investigation notebook"), 22))
		add_child(UITheme.wrap(Game.L("버그·리뷰·충돌 업무에서 단서를 모으고 원인 가설을 기록할 수 있어요. 완료한 조사는 Dashboard에 남습니다.", "Collect clues and record hypotheses during bug, review, and conflict tasks. Finished investigations stay in Dashboard."), 14, UITheme.TEXT2))
		return
	var file: Dictionary = Cases.definitions[id]
	var r := Cases.record(id)
	var found: Dictionary = r.get("clues", {})
	var closed: bool = r.get("closed", false)
	add_child(UITheme.label(Game.L("조사 → 가설 → 코드 검증 → 회고", "Observe → hypothesize → validate code → reflect"), 12, UITheme.ACCENT.lightened(0.3)))
	add_child(UITheme.bold(Game.tx(file["question"]), 20))
	add_child(UITheme.wrap(Game.L("단서 1개부터 가설을 고를 수 있어요. 실제 업무가 끝나기 전까지 바꿔도 괜찮습니다. 가설 선택이 코드를 수정하거나 리뷰를 제출하지는 않아요.", "One clue unlocks hypotheses. Revise freely until the task ends. Choosing one does not change code or submit a review."), 12, UITheme.TEXT2))
	var progress := UITheme.hbox(10)
	progress.add_child(UITheme.chip(Game.L("단서 %d / %d", "Clues %d / %d") % [found.size(), file["clues"].size()], UITheme.ACCENT))
	progress.add_child(UITheme.chip(Game.L("조사 정리됨", "Filed") if closed else (Game.L("가설 기록됨", "Hypothesis recorded") if r.get("hypothesis", "") != "" else Game.L("조사 중", "Investigating")), UITheme.OK if closed else UITheme.WARN))
	add_child(progress)
	var columns := UITheme.hbox(18)
	add_child(columns)
	var evidence := UITheme.vbox(8)
	evidence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence.custom_minimum_size.x = 290
	columns.add_child(evidence)
	evidence.add_child(UITheme.bold(Game.L("관찰한 단서", "Observed evidence"), 14))
	for c in file["clues"]:
		var seen := found.has(c["id"])
		var panel := UITheme.panel(UITheme.BG2, 8, 12, Color(UITheme.OK, 0.3) if seen else UITheme.LINE)
		var content := UITheme.vbox(6)
		panel.add_child(content)
		content.add_child(UITheme.wrap(("✓ " if seen else "○ ") + Game.tx(c["title"]), 13, UITheme.OK if seen else UITheme.TEXT))
		if seen:
			content.add_child(UITheme.wrap(Game.tx(c["detail"]), 12, UITheme.TEXT2))
			content.add_child(UITheme.label(Game.L("기록 시각 ", "Recorded at ") + String(found[c["id"]]), 11, UITheme.MUTED))
		elif not closed:
			var open := UITheme.button(Game.tx(c["action"]))
			open.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			open.focus_mode = Control.FOCUS_ALL
			open.disabled = desktop == null
			var source: Dictionary = c
			open.pressed.connect(func() -> void: desktop.open_resource(source["app"], source["target"]))
			content.add_child(open)
		evidence.add_child(panel)
	var theories := UITheme.vbox(8)
	theories.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theories.custom_minimum_size.x = 290
	columns.add_child(theories)
	theories.add_child(UITheme.bold(Game.L("내 원인 가설", "My hypothesis"), 14))
	for h in file["hypotheses"]:
		var selected: bool = r.get("hypothesis", "") == h["id"]
		var b := UITheme.button(("● " if selected else "○ ") + Game.tx(h["text"]), "primary" if selected else "default")
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 54
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = closed or found.is_empty()
		var hypothesis: String = h["id"]
		b.pressed.connect(func() -> void: Cases.choose(id, hypothesis))
		theories.add_child(b)
	if found.is_empty() and not closed:
		theories.add_child(UITheme.wrap(Game.L("왼쪽의 도구에서 단서를 하나 확인해 보세요.", "Inspect one clue with the tools on the left."), 12, UITheme.WARN))
	if closed:
		theories.add_child(UITheme.wrap(Game.tx(file["lesson"]), 13, UITheme.TEXT2))
	else:
		theories.add_child(UITheme.wrap(Game.L("가설을 정했다면 DevIDE·Terminal·CodeHub에서 실제로 검증하세요. 힌트 사용과 틀린 가설에는 감점이 없습니다.", "Test your hypothesis in DevIDE, Terminal, and CodeHub. Hints and incorrect hypotheses carry no penalty."), 12, UITheme.MUTED))
