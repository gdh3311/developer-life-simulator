extends VBoxContainer
## Tasks › Small tickets: the side-ticket board with completion progress and per-ticket scorecards
## (your time against the team's distribution).

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Tickets := preload("res://scripts/story/tickets.gd")
const GOLD := Color("f4c95d")

var _busy := false


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	Game.event.connect(func(kind: String, _d: Dictionary) -> void:
		if kind.begins_with("ticket_") or kind == "pr_merged" or kind == "ci":
			_render())
	_render()


func board() -> RefCounted:
	return Story.tickets


func _render() -> void:
	UITheme.clear(self)
	var b = board()
	if b == null:
		return
	var p: Dictionary = b.progress()
	add_child(UITheme.bold(Game.L("작은 일감", "Small tickets"), 18))
	add_child(UITheme.wrap(Game.L("동료와 고객이 던지는 10~30분짜리 실제 버그예요. 주 업무 사이에 하나씩, 하루 %d개까지. 브랜치 이름은 ticket/<번호>.",
		"Real 10–30 minute bugs from teammates and customers. One at a time between main tasks, up to %d a day. Branch name: ticket/<id>.") % Tickets.PER_DAY, 12, UITheme.TEXT2))
	# Completion bar (PowerWash-style): how much of the board you've cleared.
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, int(p["unlocked"]))
	bar.value = int(p["done"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	add_child(bar)
	add_child(UITheme.label(Game.L("완료 %d / 열린 일감 %d (전체 %d)", "Done %d / open %d (of %d)") % [int(p["done"]), int(p["unlocked"]), int(p["total"])], 11, UITheme.MUTED))
	if int(p["unlocked"]) == 0:
		add_child(UITheme.wrap(Game.L("두 번째 달부터 동료들이 작은 일감을 맡기기 시작해요.", "Teammates start handing out small tickets from month two."), 12, UITheme.MUTED))
	var active: String = b.active()
	for r in Tickets.LIST:
		var id: String = r[0]
		if not b.unlocked(id):
			continue
		add_child(_card(r, id == active, b.is_done(id)))


func _card(r: Array, is_active: bool, done: bool) -> Control:
	var b = board()
	var id: String = r[0]
	var card := UITheme.panel(UITheme.BG2 if not is_active else UITheme.BG1, 10, 12, GOLD.darkened(0.5) if is_active else Color(1, 1, 1, 0.05))
	var v := UITheme.vbox(6)
	card.add_child(v)
	var head := UITheme.hbox(8)
	var title := UITheme.bold("%s  %s" % [id.to_upper(), Game.tx(r[6])], 14, UITheme.TEXT if not done else UITheme.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UITheme.label("%s · %s" % [Game.npc_name(r[3]), Game.won(int(r[5]))], 11, GOLD))
	v.add_child(head)
	if done:
		v.add_child(_scorecard(id, b.st()["done"][id]))
		return card
	v.add_child(UITheme.wrap(Game.tx(r[7]), 12, UITheme.TEXT2))
	var actions := UITheme.hbox(8)
	if is_active:
		v.add_child(UITheme.label(Game.L("진행 중 · git pull → git switch -c ticket/%s → 고치고 npm test → PR", "In progress · git pull → git switch -c ticket/%s → fix, npm test → PR") % id, 11, GOLD))
		var drop := UITheme.button(Game.L("내려놓기", "Hand back"))
		drop.pressed.connect(func() -> void: b.drop(); _render())
		actions.add_child(drop)
	else:
		var why: String = b.can_take(id)
		var take := UITheme.button(Game.L("맡기", "Take it"), "primary" if why == "" else "default")
		take.disabled = why != "" or _busy
		take.pressed.connect(func() -> void:
			_busy = true
			_render()
			await b.take(id)
			_busy = false
			_render())
		actions.add_child(take)
		var note := {"busy": Game.L("진행 중인 일감을 먼저 끝내요", "Finish the current ticket first"), "daily": Game.L("오늘은 충분히 맡았어요", "That's enough tickets for today"),
			"workspace": Game.L("작업 공간 준비 중", "Workspace not ready")}.get(why, "") as String
		if note != "":
			actions.add_child(UITheme.label(note, 11, UITheme.MUTED))
	v.add_child(actions)
	return card


## Your record next to the team's: time histogram with your bar highlighted (Exapunks-style).
func _scorecard(id: String, rec: Dictionary) -> Control:
	var b = board()
	var v := UITheme.vbox(4)
	var mins := int(rec.get("minutes", 0))
	v.add_child(UITheme.label(Game.L("✓ %d분 · CI %d번 · 추가한 테스트 %d개 · %s", "✓ %d min · %d CI runs · %d tests added · %s")
		% [mins, int(rec.get("ci_runs", 0)), int(rec.get("tests_added", 0)), Game.tx(Tickets.standing(b.percentile(id, mins)))], 12, UITheme.OK))
	var chart := Histogram.new()
	chart.values = b.team_times(id)
	chart.mine = mins
	chart.custom_minimum_size = Vector2(0, 34)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(chart)
	return v


class Histogram extends Control:
	var values: Array = []
	var mine := 0

	func _draw() -> void:
		if values.is_empty():
			return
		var top := float(values.max())
		top = maxf(top, float(mine)) + 1.0
		var buckets := 12
		var counts := []
		counts.resize(buckets)
		counts.fill(0)
		for x in values:
			counts[clampi(int(float(x) / top * buckets), 0, buckets - 1)] += 1
		var peak := float(counts.max())
		var w := size.x / buckets
		var mine_bucket := clampi(int(float(mine) / top * buckets), 0, buckets - 1)
		for i in buckets:
			var h: float = (size.y - 2.0) * float(counts[i]) / maxf(1.0, peak)
			draw_rect(Rect2(i * w + 1.0, size.y - h, maxf(1.0, w - 2.0), h), Color("4b5563"))
		draw_rect(Rect2(mine_bucket * w + 1.0, 0, maxf(1.0, w - 2.0), size.y), Color("f4c95d"), false, 2.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
