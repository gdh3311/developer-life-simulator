extends RefCounted
## Dashboard card "My record": the evidence grades later chapters read, where each came from,
## and what would raise it (scripts/story/evidence.gd).

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const GRADE_COLORS := [Color("8a93a6"), Color("5b8cff"), Color("3ddc84")]


## Returns null before there is anything worth showing.
static func dashboard() -> Control:
	var ev = Story.evidence
	if ev == null or Game.chapter() < 2:
		return null
	var keys: Array = ev.visible_keys()
	if keys.is_empty():
		return null
	var box := UITheme.panel(UITheme.BG2, 12, 16, Color(0, 0, 0, 0))
	box.name = "EvidencePanel"
	var v := UITheme.vbox(10)
	box.add_child(v)
	var head := UITheme.hbox(8)
	head.add_child(UITheme.bold(Game.L("내 기록", "My record"), 16))
	head.add_child(UITheme.spacer())
	head.add_child(UITheme.label(Game.L("한 번의 대화가 아니라 실제로 한 일로 쌓입니다. 뒤 챕터가 이 기록을 읽어요.",
		"Built from what you actually did, not from one conversation. Later chapters read this."), 11, UITheme.MUTED))
	v.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	for key in keys:
		grid.add_child(_row(ev, key))
	v.add_child(grid)
	return box


static func _row(ev, key: String) -> Control:
	var info: Dictionary = ev.KEYS[key]
	var cell := UITheme.vbox(3)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.tooltip_text = Game.L("쓰이는 곳: ", "Used for: ") + Game.tx(info["uses"])
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var top := UITheme.hbox(8)
	var name := UITheme.bold(Game.tx(info["name"]), 13)
	name.size_flags_horizontal = Control.SIZE_FILL
	top.add_child(name)
	var r: int = ev.rank(key)
	if info.get("choice", false):
		top.add_child(UITheme.chip(Game.tx(ev.label(key)), UITheme.ACCENT if r >= 0 else UITheme.MUTED))
	else:
		top.add_child(_pips(r, (info["grades"] as Array).size()))
		top.add_child(UITheme.label(Game.tx(ev.label(key)), 12, GRADE_COLORS[r] if r >= 0 else UITheme.MUTED))
	cell.add_child(top)
	var src: String = ev.source_text(key)
	var first: String = ev.first_grade(key)
	var line := ""
	if src != "":
		line = Game.L("근거: %s", "From: %s") % src
		if first != "" and first != ev.grade(key):
			line += Game.L("  ·  처음엔 '%s'", "  ·  first '%s'") % Game.tx(info["labels"][first])
	var next: String = ev.next_text(key)
	if line != "":
		cell.add_child(UITheme.label(line, 11, UITheme.TEXT2))
	if next != "":
		cell.add_child(UITheme.label("→ " + next, 11, UITheme.MUTED))
	return cell


static func _pips(rank: int, count: int) -> Control:
	var h := UITheme.hbox(3)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in count:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(14, 6)
		var col: Color = GRADE_COLORS[mini(rank, GRADE_COLORS.size() - 1)] if i <= rank else Color(1, 1, 1, 0.08)
		p.add_theme_stylebox_override("panel", UITheme.box(col, 3))
		h.add_child(p)
	return h
