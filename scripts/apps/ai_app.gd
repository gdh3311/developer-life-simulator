extends VBoxContainer
## AICode: a scripted AI coding agent. Gives hints, and can take over some tasks —
## but its output must be reviewed (GDD 8: "AI와 함께하되, AI 없이도 개발할 수 있다").

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")

var _feed: VBoxContainer
var _scroll: ScrollContainer
var _actions: HBoxContainer
var _busy := false


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var head := UITheme.hbox(10)
	var ic := Icon.make("ai", Color("c084fc"), 26)
	head.add_child(ic)
	var hv := UITheme.vbox(0)
	hv.add_child(UITheme.bold("AICode", 15))
	hv.add_child(UITheme.label(Game.L("사내 AI 코딩 에이전트 · 결과는 반드시 검토하세요", "In-house AI coding agent · always review its output"), 11, UITheme.MUTED))
	head.add_child(hv)
	add_child(UITheme.margin(head, 12))
	_feed = UITheme.vbox(10)
	_scroll = UITheme.scroll(UITheme.margin(_feed, 14))
	add_child(_scroll)
	var bar := UITheme.panel(UITheme.BG0, 0, 12, Color(0, 0, 0, 0))
	_actions = UITheme.hbox(8)
	bar.add_child(_actions)
	add_child(bar)
	Story.objectives_changed.connect(_render_actions)
	_say("ai", Game.L("안녕하세요! 현재 업무에 대한 힌트를 드리거나, 일부 작업은 직접 맡아서 처리할 수 있어요.", "Hi! I can give hints for your current task, or take over some tasks myself."))
	_render_actions()


func _render_actions() -> void:
	UITheme.clear(_actions)
	var m = Story.active
	var hint := UITheme.button(Game.L("힌트 받기", "Get a hint"))
	hint.disabled = m == null or m.hints.is_empty() or _busy
	hint.pressed.connect(_on_hint)
	_actions.add_child(hint)
	if m != null and not m.ai_task.is_empty():
		var used: bool = m.data().get("ai_used", false)
		var delegate := UITheme.button(Game.L("AI에게 맡기기: ", "Delegate to AI: ") + Game.tx(m.ai_task["label"]), "primary")
		delegate.disabled = used or _busy
		delegate.pressed.connect(_on_delegate)
		_actions.add_child(delegate)
	_actions.add_child(UITheme.spacer())
	_actions.add_child(UITheme.label(Game.L("사용한 힌트 %d", "Hints used: %d") % Game.stat("hints"), 11, UITheme.MUTED))


func _on_hint() -> void:
	var h: String = Story.next_hint()
	if h != "":
		_say("me", Game.L("지금 업무 힌트 좀 줘.", "Give me a hint for my current task."))
		_say("ai", h)
	_render_actions()


func _on_delegate() -> void:
	var m = Story.active
	if _busy or m == null or m.ai_task.is_empty() or m.data().get("ai_used", false):
		return
	_busy = true
	_render_actions()
	_say("me", Game.L("%s 작업을 맡아 줘.", "Please take care of: %s") % Game.tx(m.ai_task["label"]))
	for step in [Game.L("저장소 구조 분석 중...", "Analysing the repository..."), Game.L("관련 파일 읽는 중: ", "Reading files: ") + ", ".join(m.ai_task["files"].keys()), Game.L("변경안 작성 중...", "Writing the change...")]:
		_say("ai", step)
		await get_tree().create_timer(0.9).timeout
		if Story.active != m or Story.status(m.id) != "active":
			_busy = false
			_render_actions()
			return
	for path in m.ai_task["files"]:
		Workspace.write_file(path, Workspace.content(m.ai_task["files"][path]))
	await Workspace.refresh()
	if Story.active != m or Story.status(m.id) != "active":
		_busy = false
		_render_actions()
		return
	Game.advance(15)
	m.data()["ai_used"] = true
	Game.inc_stat("ai_used")
	Game.emit_event("ai_used", {})
	_say("ai", Game.L("완료했습니다. %s\n변경된 파일: %s\n\n커밋하기 전에 DevIDE에서 코드를 검토하고 npm test 로 확인해 주세요.",
		"Done. %s\nChanged files: %s\n\nBefore committing, review the code in DevIDE and run npm test.") % [Game.tx(m.ai_task["summary"]), ", ".join(m.ai_task["files"].keys())])
	_busy = false
	_render_actions()


func _say(from: String, text: String) -> void:
	var row := UITheme.hbox(10)
	if from == "me":
		row.add_child(UITheme.spacer())
	else:
		row.add_child(UITheme.avatar("ai", 28))
	var bubble := UITheme.panel(UITheme.ACCENT.darkened(0.35) if from == "me" else Color("c084fc").darkened(0.75), 10, 10, Color(0, 0, 0, 0))
	var l := UITheme.label(text, 13, UITheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200 if from == "me" else 380
	bubble.add_child(l)
	row.add_child(bubble)
	_feed.add_child(row)
	(func() -> void:
		await get_tree().process_frame
		if is_instance_valid(_scroll):
			_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)).call()
