extends RefCounted
## Career UI pieces shared by Dashboard, TaskBoard and the side monitor.

const UITheme := preload("res://scripts/ui/ui_theme.gd")


## Skills with level, progress and perks; today's goals; trophy shelf.
static func dashboard() -> Control:
	var career = Story.career
	var box := UITheme.panel(UITheme.BG2, 12, 16, Color(0, 0, 0, 0))
	var v := UITheme.vbox(12)
	box.add_child(v)
	var head := UITheme.hbox(8)
	head.add_child(UITheme.bold(Game.L("커리어", "Career"), 16))
	head.add_child(UITheme.spacer())
	var grades: Dictionary = career.st()["grades"]
	if not grades.is_empty():
		head.add_child(UITheme.label(Game.L("하루 평가", "Day grades"), 11, UITheme.MUTED))
		var colors := {"S": Color("f4c95d"), "A": Color("3ddc84"), "B": Color("5b8cff"), "C": Color("8a93a6")}
		var keys: Array = grades.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
		for d in keys.slice(maxi(0, keys.size() - 8)):
			var g := String(grades[d])
			var chip := UITheme.chip(g, colors.get(g, UITheme.MUTED))
			chip.tooltip_text = Game.L("%s일차", "Day %s") % d
			head.add_child(chip)
	v.add_child(head)
	var cols := UITheme.hbox(18)
	v.add_child(cols)
	# Skills
	var skills := UITheme.vbox(8)
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in career.SKILLS:
		var info: Dictionary = career.SKILLS[id]
		var col := Color(info["color"])
		var row := UITheme.hbox(8)
		var name := UITheme.label(Game.tx(info["name"]), 12, UITheme.TEXT)
		name.custom_minimum_size.x = 64
		row.add_child(name)
		row.add_child(UITheme.label("Lv %d" % career.level(id), 12, col))
		var p: Array = career.progress(id)
		row.add_child(UITheme.bar(100.0 if p[1] == 0 else 100.0 * p[0] / p[1], col, 150))
		row.add_child(UITheme.label("MAX" if p[1] == 0 else "%d/%d" % [p[0], p[1]], 10, UITheme.MUTED))
		skills.add_child(row)
	var perks := UITheme.vbox(3)
	perks.add_child(UITheme.label(Game.L("특성", "Perks"), 11, UITheme.MUTED))
	for perk in career.PERKS:
		var on: bool = career.has_perk(perk[0], perk[1])
		perks.add_child(UITheme.label(("● " if on else "○ ") + Game.tx(perk[2]) + ("" if on else "  (%s Lv%d)" % [Game.tx(career.SKILLS[perk[0]]["name"]), perk[1]]), 11, UITheme.OK if on else UITheme.MUTED))
	skills.add_child(perks)
	cols.add_child(skills)
	# Today's goals
	var goals_box := UITheme.vbox(6)
	goals_box.custom_minimum_size.x = 250
	goals_box.add_child(goals_list(11))
	cols.add_child(goals_box)
	# Achievements
	var got: Dictionary = career.st()["achievements"]
	v.add_child(UITheme.label(Game.L("업적  %d / %d", "Achievements  %d / %d") % [got.size(), career.ACHIEVEMENTS.size()], 11, UITheme.MUTED))
	var shelf := HFlowContainer.new()
	shelf.add_theme_constant_override("h_separation", 8)
	shelf.add_theme_constant_override("v_separation", 8)
	for id in career.ACHIEVEMENTS:
		shelf.add_child(_trophy(id, got.has(id)))
	v.add_child(shelf)
	return box


static func _trophy(id: String, open: bool) -> Control:
	var a: Dictionary = Story.career.ACHIEVEMENTS[id]
	var card := UITheme.panel(Color("2a2416") if open else UITheme.BG1, 10, 8, Color("f4c95d").darkened(0.35) if open else Color(1, 1, 1, 0.04))
	card.custom_minimum_size = Vector2(132, 0)
	card.tooltip_text = Game.tx(a["desc"])
	var v := UITheme.vbox(2)
	card.add_child(v)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, 30)
	icon.draw.connect(func() -> void: _draw_cup(icon, open))
	v.add_child(icon)
	var n := UITheme.label(Game.tx(a["name"]) if open else "???", 11, Color("f4c95d") if open else UITheme.MUTED)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	return card


static func _draw_cup(c: Control, open: bool) -> void:
	var x := c.size.x / 2.0
	var gold := Color("f4c95d") if open else Color(1, 1, 1, 0.12)
	var dark := Color("b98a2c") if open else Color(1, 1, 1, 0.06)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - 11, 3), Vector2(x + 11, 3), Vector2(x + 8, 15), Vector2(x - 8, 15)]), gold)
	c.draw_arc(Vector2(x - 11, 8), 5, PI * 0.5, PI * 1.5, 10, dark, 2.0, true)
	c.draw_arc(Vector2(x + 11, 8), 5, -PI * 0.5, PI * 0.5, 10, dark, 2.0, true)
	c.draw_rect(Rect2(x - 2, 15, 4, 6), dark)
	c.draw_rect(Rect2(x - 8, 21, 16, 4), gold)
	if open:
		c.draw_line(Vector2(x - 6, 5), Vector2(x - 4, 12), Color(1, 1, 1, 0.5), 1.5)


## Today's goals with live status.
static func goals_list(size := 12) -> Control:
	var career = Story.career
	var v := UITheme.vbox(5)
	var goals: Array = career.goals()
	var done := goals.filter(func(id: String) -> bool: return career.goal_status(id) == "done").size()
	v.add_child(UITheme.label(Game.L("오늘의 목표  %d / %d", "Daily goals  %d / %d") % [done, goals.size()], size, UITheme.MUTED))
	for id in goals:
		var status: String = career.goal_status(id)
		var mark := {"done": "✓", "failed": "✕", "open": "○"}[status] as String
		var col: Color = {"done": UITheme.OK, "failed": UITheme.ERR.darkened(0.15), "open": UITheme.TEXT2}[status]
		var row := UITheme.hbox(6)
		row.add_child(UITheme.label(mark, size + 1, col))
		var t := UITheme.wrap(Game.tx(career.GOALS[id]["text"]), size, UITheme.TEXT if status != "failed" else UITheme.MUTED)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		v.add_child(row)
	return v


## One-line strip for the top of TaskBoard.
static func goals_strip() -> Control:
	var career = Story.career
	var strip := UITheme.panel(Color("16202e"), 0, 8, Color(0, 0, 0, 0))
	# Wraps onto a second line instead of widening TaskBoard (English goals are long).
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 14)
	h.add_theme_constant_override("v_separation", 4)
	strip.add_child(h)
	h.add_child(UITheme.label(Game.L("오늘의 목표", "Today's goals"), 11, UITheme.ACCENT.lightened(0.2)))
	for id in career.goals():
		var status: String = career.goal_status(id)
		var mark := {"done": "✓", "failed": "✕", "open": "○"}[status] as String
		var col: Color = {"done": UITheme.OK, "failed": UITheme.ERR.darkened(0.15), "open": UITheme.TEXT2}[status]
		h.add_child(UITheme.label("%s %s" % [mark, Game.tx(career.GOALS[id]["text"])], 11, col))
	h.add_child(UITheme.label(Game.L("달성마다 +%s · 경험치", "+%s and XP each") % Game.won(career.GOAL_REWARD), 10, UITheme.MUTED))
	return strip
