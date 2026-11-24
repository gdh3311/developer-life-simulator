extends ScrollContainer
## Dashboard: career profile, work stats, team relationships, progress and settings.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Icon := preload("res://scripts/ui/icon.gd")
const DeskItems := preload("res://scripts/room/desk_items.gd")

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
	Game.event.connect(func(kind: String, _d: Dictionary) -> void:
		if kind in ["achievement", "skill_up"] and is_visible_in_tree():
			_render())
	Game.wallet_changed.connect(_render)
	Cases.changed.connect(_render)
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
	pv.add_child(UITheme.label("%s · %s   ·   %s %d%%   ·   %s" % [Game.date_text(), Game.clock_text(), Game.L("컨디션", "Energy"), Game.condition(), Game.won(Game.money())], 12, UITheme.MUTED))
	pr.add_child(pv)
	pr.add_child(UITheme.spacer())
	var available := Story.chapter_missions(Game.chapter())
	var done: int = available.filter(func(m) -> bool: return Story.status(m.id) == "done").size()
	var total: int = available.filter(func(m) -> bool: return Story.status(m.id) != "skipped").size()
	var prog := UITheme.vbox(4)
	prog.add_child(UITheme.label(Game.L("CHAPTER %d 진행도  %d / %d", "CHAPTER %d progress  %d / %d") % [Game.chapter(), done, total], 12, UITheme.TEXT2))
	if not Story.Chapters.DATA[Game.chapter()]["complete"]:
		prog.add_child(UITheme.label(Game.L("현재 %d / %d개 업무 제공", "%d of %d tasks available") % [available.size(), Story.Chapters.DATA[Game.chapter()]["planned"]], 11, UITheme.MUTED))
	prog.add_child(UITheme.bar(100.0 * done / maxf(total, 1), UITheme.ACCENT, 200))
	pr.add_child(prog)
	prof.add_child(pr)
	_root.add_child(prof)
	_root.add_child(preload("res://scripts/apps/career_panel.gd").dashboard())

	# Storylines
	if Game.chapter() >= 3:
		var arcs := UITheme.panel(UITheme.BG2, 12, 14, Color(0, 0, 0, 0))
		var av := UITheme.vbox(6)
		av.add_child(UITheme.label(Game.L("스토리라인  ·  동시에 %d개까지 따라갈 수 있어요", "Storylines  ·  follow up to %d at once") % Story.arcs.MAX_ACTIVE, 12, UITheme.TEXT2))
		for a in Story.arcs.all():
			var status_text := {"active": Game.L("진행 중", "Active"), "deferred": Game.L("보류", "On hold"), "dropped": Game.L("내려놓음", "Set aside"), "offered": Game.L("제안됨", "Offered")}.get(a.status(), Game.L("아직", "Not yet")) as String
			var row := UITheme.hbox(10)
			row.add_child(UITheme.label(status_text, 12, UITheme.OK if a.is_active() else UITheme.MUTED))
			row.add_child(UITheme.bold(Game.tx(a.title), 13))
			row.add_child(UITheme.spacer())
			row.add_child(UITheme.label(a.summary(), 12, UITheme.TEXT2))
			av.add_child(row)
		arcs.add_child(av)
		_root.add_child(arcs)

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
		var bad: bool = s[0] in ["main_commits", "caught_slacking"] and Game.stat(s[0]) > 0
		v.add_child(UITheme.bold(str(Game.stat(s[0])), 22, UITheme.ERR if bad else UITheme.TEXT))
		v.add_child(UITheme.label(s[1], 11, UITheme.MUTED))
		box.add_child(v)
		grid.add_child(box)
	_root.add_child(grid)
	_root.add_child(UITheme.label(Game.L("CI 실패는 실험 기록입니다. 실패 횟수만으로 신뢰가 떨어지지 않습니다.", "CI failures are experiments. Their count alone does not lower trust."), 11, UITheme.MUTED))
	_render_cases()

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

	_root.add_child(_desk_panel())

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
	var wrow := UITheme.hbox(10)
	var wl := UITheme.label(Game.L("딴짓 단속 이벤트", "Boss walk-by event"), 13, UITheme.TEXT2)
	wl.custom_minimum_size.x = 110
	wrow.add_child(wl)
	var wcheck := CheckButton.new()
	wcheck.button_pressed = Game.walkby_enabled
	wcheck.focus_mode = Control.FOCUS_NONE
	wcheck.toggled.connect(func(on: bool) -> void: Game.set_walkby(on))
	wrow.add_child(wcheck)
	wrow.add_child(UITheme.label(Game.L("끄면 딴짓을 해도 상사가 지나가지 않아요.", "When off, nobody walks by while you browse."), 11, UITheme.MUTED))
	_root.add_child(wrow)
	for vol in [["music", Game.L("음악", "Music")], ["sfx", Game.L("효과음", "Sound effects")], ["ambience", Game.L("사무실 소리", "Office ambience")]]:
		var vrow := UITheme.hbox(10)
		var vl := UITheme.label(vol[1], 13, UITheme.TEXT2)
		vl.custom_minimum_size.x = 110
		vrow.add_child(vl)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size.x = 220
		slider.value = {"music": Sfx.music_volume, "sfx": Sfx.sfx_volume, "ambience": Sfx.ambience_volume}[vol[0]]
		var which: String = vol[0]
		slider.value_changed.connect(func(v: float) -> void:
			match which:
				"music":
					Sfx.music_volume = v
				"ambience":
					Sfx.ambience_volume = v
				_:
					Sfx.sfx_volume = v
					Sfx.play("tick")
			Sfx.apply_volumes()
			Sfx.save_settings())
		vrow.add_child(slider)
		_root.add_child(vrow)
	_root.add_child(UITheme.label(Game.L("이미 받은 메시지는 두 언어로 저장되어 바로 바뀝니다. 회사 저장소의 코드 언어는 처음 만들 때 정해집니다.",
		"Messages switch instantly. The company repo's code language is fixed when it is created."), 11, UITheme.MUTED))

	var reset := UITheme.button(Game.L("정말 처음부터 다시 시작할까요? (회사 저장소와 진행이 모두 지워집니다)", "Really start over? (The company repo and all progress will be deleted)") if _confirm else Game.L("처음부터 다시 시작", "Start over"), "danger" if _confirm else "default")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		if not _confirm:
			_confirm = true
			_render()
			return
		if Game.new_game():
			get_tree().reload_current_scene())
	_root.add_child(reset)


## My desk: pick the keyboard, mouse, mug and plant. Locked items say how to unlock them.
func _desk_panel() -> Control:
	var box := UITheme.panel(UITheme.BG2, 12, 14, Color(0, 0, 0, 0))
	var v := UITheme.vbox(10)
	box.add_child(v)
	var head := UITheme.hbox(8)
	head.add_child(UITheme.label(Game.L("내 책상", "My desk"), 12, UITheme.TEXT2))
	head.add_child(UITheme.spacer())
	var reload := UITheme.button(Game.L("내 에셋 다시 읽기", "Reload my assets"))
	reload.tooltip_text = DeskItems.CUSTOM_DIR
	reload.pressed.connect(func() -> void:
		DeskItems.reload()
		Game.emit_event("desk_changed", {})
		_render())
	head.add_child(reload)
	v.add_child(head)
	for slot in DeskItems.slots():
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		var label := UITheme.label(Game.tx(DeskItems.slot_info(slot)["name"]), 12, UITheme.MUTED)
		label.custom_minimum_size = Vector2(64, 0)
		row.add_child(label)
		var current: Dictionary = DeskItems.equipped(slot)
		for it in DeskItems.items_for(slot):
			row.add_child(_desk_choice(slot, it, it["id"] == current.get("id", "")))
		v.add_child(row)
	return box


func _desk_choice(slot: String, it: Dictionary, selected: bool) -> Control:
	var open := DeskItems.unlocked(it)
	var b := Button.new()
	b.custom_minimum_size = Vector2(112, 86)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = Game.tx(it["name"]) + ("" if open else "
" + DeskItems.lock_reason(it))
	b.disabled = not open
	b.add_theme_stylebox_override("normal", UITheme.box(UITheme.BG3, 8, UITheme.ACCENT if selected else Color(1, 1, 1, 0.06), 6, 2 if selected else 1))
	b.add_theme_stylebox_override("hover", UITheme.box(UITheme.BG3.lightened(0.05), 8, UITheme.ACCENT, 6))
	b.add_theme_stylebox_override("disabled", UITheme.box(UITheme.BG1, 8, Color(1, 1, 1, 0.04), 6))
	var v := UITheme.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = DeskItems.texture(it)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(98, 48)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.modulate.a = 1.0 if open else 0.35
	v.add_child(pic)
	var name := UITheme.label(Game.tx(it["name"]) if open else "🔒 " + DeskItems.lock_reason(it), 10, UITheme.TEXT if open else UITheme.MUTED)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size.x = 98
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name)
	b.add_child(v)
	var item_id: String = it["id"]
	b.pressed.connect(func() -> void:
		if DeskItems.equip(slot, item_id):
			Sfx.play("click")
			_render())
	return b


func _render_cases() -> void:
	var archive := Cases.archive()
	_root.add_child(UITheme.bold(Game.L("조사 수첩  ·  %d / %d", "Investigation journal  ·  %d / %d") % [archive.size(), Cases.definitions.size()], 16))
	if archive.is_empty():
		_root.add_child(UITheme.wrap(Game.L("TaskBoard의 조사 노트에서 단서와 가설을 기록해 보세요. 업무가 끝나면 실제 결과와 배운 점이 여기 남습니다.", "Record clues and hypotheses in TaskBoard. When a task ends, its outcome and lessons stay here."), 12, UITheme.TEXT2))
	for id in archive:
		var file: Dictionary = Cases.definitions[id]
		var record := Cases.record(id)
		var card := UITheme.panel(UITheme.BG2, 10, 12, UITheme.LINE)
		var v := UITheme.vbox(6)
		card.add_child(v)
		var followup: bool = record.get("outcome", "") == "followup"
		var status := Game.L("후속 조치 필요", "Follow-up needed") if followup else (Game.L("후속 수정으로 회복", "Recovered with a follow-up fix") if record.get("outcome", "") == "recovered" else Game.L("업무 완료", "Task complete"))
		v.add_child(UITheme.label("DAY %d  ·  %s  ·  %s" % [int(record["day"]), status, Game.L("단서 %d개", "%d clues") % record["clues"].size()], 11, UITheme.WARN if followup else UITheme.OK))
		v.add_child(UITheme.wrap(Game.tx(file["question"]), 15, UITheme.TEXT))
		var selected := String(record.get("hypothesis", ""))
		for h in file["hypotheses"]:
			if h["id"] == selected:
				v.add_child(UITheme.wrap(Game.L("내 가설: ", "My hypothesis: ") + Game.tx(h["text"]), 12, UITheme.TEXT2))
		if selected == "":
			v.add_child(UITheme.label(Game.L("가설을 기록하지 않고 진행했어요.", "No hypothesis was recorded."), 12, UITheme.MUTED))
		elif selected != file["answer"]:
			v.add_child(UITheme.wrap(Game.L("다른 원인이 확인됐어요. 다음 조사에 쓸 근거로 남겨 둡니다.", "The evidence points to a different cause. Keep this for the next investigation."), 12, UITheme.ACCENT.lightened(0.3)))
		v.add_child(UITheme.wrap(Game.tx(file["lesson"]), 12, UITheme.TEXT2))
		_root.add_child(card)
