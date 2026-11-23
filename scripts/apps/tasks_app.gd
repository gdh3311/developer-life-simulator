extends HBoxContainer
## TaskBoard: issues by status + the current mission's checklist.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")

var _board: HBoxContainer
var _current: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_board = UITheme.hbox(10)
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UITheme.margin(_board, 12))
	_board.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side := UITheme.panel(UITheme.BG0, 0, 14, Color(0, 0, 0, 0))
	side.custom_minimum_size.x = 280
	_current = UITheme.vbox(8)
	side.add_child(_current)
	add_child(side)
	Game.issues_changed.connect(_render)
	Story.objectives_changed.connect(_render)
	_render()


func _render() -> void:
	UITheme.clear(_board)
	for col in [["todo", "To Do", UITheme.MUTED], ["progress", "In Progress", UITheme.ACCENT], ["done", "Done", UITheme.OK]]:
		var panel := UITheme.panel(UITheme.BG2, 10, 10, Color(0, 0, 0, 0))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UITheme.vbox(8)
		var issues: Array = Game.state["issues"].filter(func(i: Dictionary) -> bool: return i["status"] == col[0])
		var head := UITheme.hbox(6)
		head.add_child(Icon.make("dot", col[2], 10))
		head.add_child(UITheme.bold(col[1], 13, UITheme.TEXT2))
		head.add_child(UITheme.label(str(issues.size()), 12, UITheme.MUTED))
		v.add_child(head)
		for i in issues:
			v.add_child(_card(i))
		panel.add_child(UITheme.scroll(v))
		_board.add_child(panel)

	UITheme.clear(_current)
	_current.add_child(UITheme.label("현재 업무", 11, UITheme.MUTED))
	var m = Story.active
	if m == null:
		_current.add_child(UITheme.bold("진행 중인 업무 없음", 15))
		_current.add_child(UITheme.wrap("오늘 업무를 모두 마쳤다면 상단의 '퇴근하기'를 누르세요." if Game.state["day_done"] else "잠시 후 새 업무가 도착합니다.", 13, UITheme.TEXT2))
		return
	_current.add_child(UITheme.bold(("%s  " % m.issue if m.issue != "" else "") + m.title, 16))
	_current.add_child(UITheme.label("DAY %d" % m.day, 11, UITheme.MUTED))
	for o in m.objectives:
		var done: bool = m.is_done(o["id"])
		var row := UITheme.hbox(8)
		var ic := Icon.make("check" if done else "ring", UITheme.OK if done else UITheme.MUTED, 16)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
		row.add_child(UITheme.wrap(o["text"], 13, UITheme.OK.lightened(0.2) if done else UITheme.TEXT))
		_current.add_child(row)
	if not m.hints.is_empty():
		_current.add_child(UITheme.label("\n막히면 AICode에서 힌트를 받을 수 있어요.", 12, UITheme.MUTED))


func _card(i: Dictionary) -> Control:
	var card := UITheme.panel(UITheme.BG3, 8, 10, Color(1, 1, 1, 0.05))
	var v := UITheme.vbox(6)
	var head := UITheme.hbox(6)
	head.add_child(UITheme.bold(i["id"], 12, UITheme.TEXT2))
	var kc: Color = {"bug": UITheme.ERR, "feature": UITheme.ACCENT, "review": Color("a78bfa")}.get(i["kind"], UITheme.MUTED)
	head.add_child(UITheme.chip(i["kind"], kc))
	v.add_child(head)
	v.add_child(UITheme.wrap(i["title"], 13, UITheme.TEXT))
	v.add_child(UITheme.label("담당: " + String(i["owner"]), 11, UITheme.ACCENT.lightened(0.3) if i["owner"] == "나" else UITheme.MUTED))
	card.add_child(v)
	return card
