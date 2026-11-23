extends ScrollContainer
## Dashboard: career profile, work stats, team relationships, progress and settings.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")

var _root: VBoxContainer
var _confirm := false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root = UITheme.vbox(14)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UITheme.margin(_root, 16))
	get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Game.relation_changed.connect(func(_n: String, _k: String, _d: int) -> void: _render())
	Story.objectives_changed.connect(_render)
	Game.wallet_changed.connect(_render)
	_render()


func _render() -> void:
	UITheme.clear(_root)
	# Profile
	var prof := UITheme.panel(UITheme.BG2, 12, 16, Color(0, 0, 0, 0))
	var pr := UITheme.hbox(14)
	pr.add_child(UITheme.avatar("me", 52))
	var pv := UITheme.vbox(2)
	pv.add_child(UITheme.bold(Game.pname(), 18))
	pv.add_child(UITheme.label("%s · Backend · NEXORA" % Game.rank_name(), 13, UITheme.TEXT2))
	pv.add_child(UITheme.label("DAY %d · %s   ·   %s %d%%   ·   %s" % [Game.day(), Game.clock_text(), Game.L("컨디션", "Energy"), Game.condition(), Game.won(Game.money())], 12, UITheme.MUTED))
	pr.add_child(pv)
	pr.add_child(UITheme.spacer())
	var done: int = Story.missions().filter(func(m) -> bool: return Story.status(m.id) == "done").size()
	var total: int = Story.missions().filter(func(m) -> bool: return Story.status(m.id) != "skipped").size()
	var prog := UITheme.vbox(4)
	prog.add_child(UITheme.label(Game.L("CHAPTER 1 진행도  %d / %d", "CHAPTER 1 progress  %d / %d") % [done, total], 12, UITheme.TEXT2))
	prog.add_child(UITheme.bar(100.0 * done / maxf(total, 1), UITheme.ACCENT, 200))
	pr.add_child(prog)
	prof.add_child(pr)
	_root.add_child(prof)

	# Stats
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for s in [["commits", Game.L("커밋", "Commits")], ["prs", "PR"], ["merges", Game.L("병합됨", "Merged")], ["reviews", Game.L("리뷰 코멘트", "Review comments")],
			["test_runs", Game.L("테스트 실행", "Test runs")], ["ci_pass", Game.L("CI 통과", "CI green")], ["ci_fail", Game.L("CI 실패", "CI red")], ["main_commits", Game.L("main 직접 커밋", "Commits to main")],
			["ai_used", Game.L("AI 위임", "AI delegations")], ["hints", Game.L("힌트 사용", "Hints used")], ["caught_slacking", Game.L("딴짓 적발", "Caught slacking")], ["missions", Game.L("완료 업무", "Tasks done")]]:
		var box := UITheme.panel(UITheme.BG2, 10, 12, Color(0, 0, 0, 0))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UITheme.vbox(0)
		var bad: bool = s[0] in ["ci_fail", "main_commits", "caught_slacking"] and Game.stat(s[0]) > 0
		v.add_child(UITheme.bold(str(Game.stat(s[0])), 22, UITheme.ERR if bad else UITheme.TEXT))
		v.add_child(UITheme.label(s[1], 11, UITheme.MUTED))
		box.add_child(v)
		grid.add_child(box)
	_root.add_child(grid)

	# Team
	_root.add_child(UITheme.label(Game.L("팀 관계 — 신뢰는 천천히 쌓이고, 실수하면 크게 떨어집니다.", "Team trust — earned slowly, lost quickly."), 12, UITheme.MUTED))
	var team := GridContainer.new()
	team.columns = 2
	team.add_theme_constant_override("h_separation", 10)
	team.add_theme_constant_override("v_separation", 10)
	for npc in ["daniel", "mina", "alex", "sophie"]:
		var card := UITheme.panel(UITheme.BG2, 10, 12, Color(0, 0, 0, 0))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UITheme.vbox(6)
		var h := UITheme.hbox(10)
		h.add_child(UITheme.avatar(npc, 32))
		var nv := UITheme.vbox(0)
		nv.add_child(UITheme.bold(Game.npc_name(npc), 14))
		nv.add_child(UITheme.label(Game.npc_role(npc), 11, UITheme.MUTED))
		h.add_child(nv)
		v.add_child(h)
		for key in Game.REL_KEYS:
			var r := UITheme.hbox(8)
			var l := UITheme.label(Game.rel_label(key), 12, UITheme.TEXT2)
			l.custom_minimum_size.x = 76
			r.add_child(l)
			var b := UITheme.bar(Game.rel(npc, key), Game.npc_color(npc), 150)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(b)
			r.add_child(UITheme.label(str(Game.rel(npc, key)), 12, UITheme.TEXT))
			v.add_child(r)
		card.add_child(v)
		team.add_child(card)
	_root.add_child(team)

	# Missions
	_root.add_child(UITheme.label(Game.L("업무 기록", "Work log"), 12, UITheme.MUTED))
	for m in Story.missions():
		var st := Story.status(m.id)
		if st == "skipped":
			continue
		var row := UITheme.hbox(8)
		row.add_child(Icon.make("check" if st == "done" else ("dot" if st == "active" else "ring"),
			UITheme.OK if st == "done" else (UITheme.ACCENT if st == "active" else UITheme.MUTED), 14))
		row.add_child(UITheme.label("DAY %d  ·  %s%s" % [m.day, (m.issue + " ") if m.issue != "" else "", m.title_text() if st != "locked" else "???"], 13,
			UITheme.TEXT if st != "locked" else UITheme.MUTED))
		_root.add_child(row)

	# Settings
	_root.add_child(UITheme.label(Game.L("설정", "Settings"), 12, UITheme.MUTED))
	var srow := UITheme.hbox(10)
	srow.add_child(UITheme.label("Language / 언어", 13, UITheme.TEXT2))
	for pair in [["ko", "한국어"], ["en", "English"]]:
		var b := UITheme.button(pair[1], "primary" if Game.lang == pair[0] else "default")
		var code: String = pair[0]
		b.pressed.connect(func() -> void:
			if Game.lang == code:
				return
			Game.set_language(code)
			Game._save()
			get_tree().reload_current_scene())
		srow.add_child(b)
	_root.add_child(srow)
	_root.add_child(UITheme.label(Game.L("이미 받은 메시지는 두 언어로 저장되어 바로 바뀝니다. 회사 저장소의 코드 언어는 처음 만들 때 정해집니다.",
		"Messages switch instantly. The company repo's code language is fixed when it is created."), 11, UITheme.MUTED))

	var reset := UITheme.button(Game.L("정말 처음부터 다시 시작할까요? (회사 저장소와 진행이 모두 지워집니다)", "Really start over? (The company repo and all progress will be deleted)") if _confirm else Game.L("처음부터 다시 시작", "Start over"), "danger" if _confirm else "default")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		if not _confirm:
			_confirm = true
			_render()
			return
		Game.new_game()
		get_tree().reload_current_scene())
	_root.add_child(reset)
