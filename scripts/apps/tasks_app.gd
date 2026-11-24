extends VBoxContainer
## TaskBoard: issues by status + the current mission's checklist.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const CasePanel := preload("res://scripts/apps/case_panel.gd")
const ProductWork := preload("res://scripts/apps/product_work.gd")

var desktop: Control
var _board: HBoxContainer
var _current: VBoxContainer
var _tabs: TabContainer
var _goals: VBoxContainer
var _shown_mission := ""


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_goals = UITheme.vbox(0)
	add_child(_goals)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)
	var work := HBoxContainer.new()
	work.name = Game.L("업무 보드", "Work board")
	_tabs.add_child(work)
	_board = UITheme.hbox(10)
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.add_child(UITheme.margin(_board, 12))
	_board.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side := UITheme.panel(UITheme.BG0, 0, 14, Color(0, 0, 0, 0))
	side.custom_minimum_size.x = 280
	_current = UITheme.vbox(8)
	side.add_child(UITheme.scroll(_current))
	work.add_child(side)
	var notes := CasePanel.new()
	notes.desktop = desktop
	var scroll := UITheme.scroll(UITheme.margin(notes, 16))
	scroll.name = Game.L("조사 노트", "Investigation")
	_tabs.add_child(scroll)
	var product := ProductWork.new()
	product.desktop = desktop
	var products := UITheme.vbox(28)
	products.add_child(product)
	var page := preload("res://scripts/apps/page_work.gd").new()
	page.desktop = desktop
	products.add_child(page)
	var product_scroll := UITheme.scroll(UITheme.margin(products, 16))
	product_scroll.name = Game.L("제품 개발", "Product work")
	_tabs.add_child(product_scroll)
	Game.issues_changed.connect(_render)
	Story.objectives_changed.connect(_render)
	Game.event.connect(func(_k: String, _d: Dictionary) -> void: _render_goals())
	_render_goals()
	_render()


func _render_goals() -> void:
	if _goals == null:
		return
	UITheme.clear(_goals)
	_goals.add_child(preload("res://scripts/apps/career_panel.gd").goals_strip())


func open_product_tab(target: String) -> void:
	if target == "products":
		_tabs.current_tab = 2


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
	_current.add_child(UITheme.label(Game.L("현재 업무", "Current task"), 11, UITheme.MUTED))
	var m = Story.active
	var mission_id: String = m.id if m != null else ""
	if mission_id != _shown_mission:
		_shown_mission = mission_id
		if _tabs.current_tab != 2:
			_tabs.current_tab = 1 if Cases.has_case(mission_id) else 0
	if m == null:
		_current.add_child(UITheme.bold(Game.L("진행 중인 업무 없음", "No active task"), 15))
		_current.add_child(UITheme.wrap(Game.L("오늘 업무를 모두 마쳤다면 상단의 '퇴근하기'를 누르세요.", "If you're done for the day, press 'Clock out' at the top.") if Game.state["day_done"] else Game.L("잠시 후 새 업무가 도착합니다.", "A new task will arrive shortly."), 13, UITheme.TEXT2))
		return
	_current.add_child(UITheme.bold(("%s  " % m.issue if m.issue != "" else "") + m.title_text(), 16))
	_current.add_child(UITheme.label("CHAPTER %d · %s" % [m.chapter, Game.date_text()], 11, UITheme.MUTED))
	if m.chapter == 2 and desktop != null:
		var lab := UITheme.button(Game.L("Request Lab 열기", "Open Request Lab"))
		lab.pressed.connect(func() -> void: desktop.open_resource("lab", ""))
		_current.add_child(lab)
	for o in m.objectives:
		var done: bool = m.is_done(o["id"])
		var row := UITheme.hbox(8)
		var ic := Icon.make("check" if done else "ring", UITheme.OK if done else UITheme.MUTED, 16)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
		row.add_child(UITheme.wrap(Game.tx(o["text"]), 13, UITheme.OK.lightened(0.2) if done else UITheme.TEXT))
		_current.add_child(row)
	if not m.hints.is_empty():
		_current.add_child(UITheme.label("\n" + Game.L("막히면 AICode에서 힌트를 받을 수 있어요.", "Stuck? Get a hint from AICode."), 12, UITheme.MUTED))


func _card(i: Dictionary) -> Control:
	var card := UITheme.panel(UITheme.BG3, 8, 10, Color(1, 1, 1, 0.05))
	var v := UITheme.vbox(6)
	var head := UITheme.hbox(6)
	head.add_child(UITheme.bold(i["id"], 12, UITheme.TEXT2))
	var kc: Color = {"bug": UITheme.ERR, "feature": UITheme.ACCENT, "review": Color("a78bfa"), "docs": UITheme.OK}.get(i["kind"], UITheme.MUTED)
	head.add_child(UITheme.chip(i["kind"], kc))
	v.add_child(head)
	v.add_child(UITheme.wrap(Game.tx(i["title"]), 13, UITheme.TEXT))
	var mine: bool = i["owner"] in ["나", "me"]
	v.add_child(UITheme.label(Game.L("담당: ", "Owner: ") + (Game.L("나", "me") if mine else String(i["owner"])), 11, UITheme.ACCENT.lightened(0.3) if mine else UITheme.MUTED))
	if i["id"] in [ArcadeStudio.ISSUE, PageStudio.ISSUE]:
		var open := UITheme.button(Game.L("업무 열기", "Open ticket"))
		open.pressed.connect(open_product_tab.bind("products"))
		v.add_child(open)
	card.add_child(v)
	return card
