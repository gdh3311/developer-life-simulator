extends Node
## Runs the missions in order, day by day, routes game events to the active mission,
## and fires side events (lunch, coffee chats, check-ins, job offers...).

signal objectives_changed
signal mission_started(id: String)
signal chapter_finished
signal content_paused

const MISSIONS := [
	preload("res://scripts/story/missions/d1_01_first_day.gd"),
	preload("res://scripts/story/missions/d1_02_first_pr.gd"),
	preload("res://scripts/story/missions/d1_03_sync.gd"),
	preload("res://scripts/story/missions/d2_04_first_fix.gd"),
	preload("res://scripts/story/missions/d2_05_regression.gd"),
	preload("res://scripts/story/missions/d3_06_review.gd"),
	preload("res://scripts/story/missions/d3_07_shipping.gd"),
	preload("res://scripts/story/missions/d4_08_login_incident.gd"),
	preload("res://scripts/story/missions/d4_09_coupon_hotfix.gd"),
	preload("res://scripts/story/missions/d4_10_retro.gd"),
	preload("res://scripts/story/missions/c02_01_customer.gd"),
	preload("res://scripts/story/missions/c02_02_reproduction.gd"),
	preload("res://scripts/story/missions/c02_03_idempotency.gd"),
	preload("res://scripts/story/missions/c02_04_logs.gd"),
	preload("res://scripts/story/missions/c02_05_screen_states.gd"),
	preload("res://scripts/story/missions/c02_06_concurrency.gd"),
	preload("res://scripts/story/missions/c02_07_rollout.gd"),
	preload("res://scripts/story/missions/c02_08_reply.gd"),
	preload("res://scripts/story/missions/c03_01_scope.gd"),
	preload("res://scripts/story/missions/c03_02_deadline.gd"),
	preload("res://scripts/story/missions/c03_03_cancel.gd"),
	preload("res://scripts/story/missions/c03_04_beta.gd"),
	preload("res://scripts/story/missions/c03_05_labels.gd"),
	preload("res://scripts/story/missions/c03_06_release.gd"),
	preload("res://scripts/story/missions/c03_07_ownership.gd"),
	preload("res://scripts/story/missions/c03_08_contract.gd"),
	preload("res://scripts/story/missions/c04_01_legacy_branch.gd"),
	preload("res://scripts/story/missions/c04_02_author.gd"),
	preload("res://scripts/story/missions/c04_03_dual_write.gd"),
	preload("res://scripts/story/missions/c04_04_reconcile.gd"),
	preload("res://scripts/story/missions/c04_05_rewrite.gd"),
	preload("res://scripts/story/missions/c04_06_pilot.gd"),
	preload("res://scripts/story/missions/c04_07_review_load.gd"),
	preload("res://scripts/story/missions/c04_08_decision_record.gd"),
]
const SideEvents := preload("res://scripts/story/side_events.gd")
const Arcs := preload("res://scripts/story/arcs.gd")
const Events := preload("res://scripts/story/events.gd")
const Career := preload("res://scripts/story/career.gd")
const Chapters := preload("res://scripts/story/chapters.gd")

var _missions: Array = []
var active: RefCounted = null
var side: RefCounted
var arcs: RefCounted          # storyline engine (see docs/STORYLINES.md)
var events: RefCounted        # event card engine
var career: RefCounted        # skills, daily goals, grades, achievements


func _ready() -> void:
	_build()
	Game.event.connect(_on_event)
	Game.time_changed.connect(func(_d: int, _m: int) -> void:
		side.check()
		arcs.check()
		events.check())
	Game.state_reset.connect(func() -> void:
		active = null
		_build())


func _build() -> void:
	_missions.clear()
	for script in MISSIONS:
		var m = script.new()
		m.story = self
		_missions.append(m)
	side = SideEvents.new()
	arcs = Arcs.new()
	events = Events.new()
	career = Career.new()


func mission(id: String) -> RefCounted:
	for m in _missions:
		if m.id == id:
			return m
	return null


func missions() -> Array:
	return _missions


func chapter_missions(id: int) -> Array:
	return _missions.filter(func(m) -> bool: return m.chapter == id)


func can_continue_chapter() -> bool:
	var next := Game.chapter() + 1
	return Game.state["day_done"] and Game.day() >= int(Chapters.DATA[Game.chapter()]["last_day"]) and Chapters.DATA.has(next) and not chapter_missions(next).is_empty()


func _signal_chapter_end() -> void:
	var info: Dictionary = Chapters.DATA[Game.chapter()]
	if Game.day() >= int(info["last_day"]):
		if info["complete"]:
			chapter_finished.emit()
		else:
			content_paused.emit()


func status(id: String) -> String:
	return String(Game.state["story"].get(id, {}).get("status", "locked"))


func start_new() -> void:
	start_day(Game.day())


func resume() -> void:
	# Fresh mission instances invalidate coroutines left behind by a scene/language reload.
	active = null
	_build()
	arcs.resume()
	for m in _missions:
		if status(m.id) == "active":
			active = m
			if not m.data().get("_intro_complete", false) and not m.is_done("merged"):
				await _introduce(m)
			if active != m or status(m.id) != "active":
				return
			m.resume()
			objectives_changed.emit()
			CodeHub.resume_work()
			return
	if not Game.state["day_done"]:
		_start_next()
	else:
		objectives_changed.emit()
		_signal_chapter_end()


func start_day(_d: int) -> void:
	_start_next()
	side.check()
	arcs.check()
	events.check()


func _start_next() -> void:
	for m in _missions:
		if status(m.id) == "locked" and m.chapter == Game.chapter() and m.day == Game.day():
			if not m.should_run():
				Game.state["story"][m.id] = {"status": "skipped", "obj": {}, "data": {}}
				continue
			_start(m)
			return
	active = null
	objectives_changed.emit()
	side.flush_day()
	arcs.flush_day()
	events.flush_day()
	_signal_chapter_end()
	Game.finish_day()
	career.finish_day()


func _start(m: RefCounted) -> void:
	Game.state["story"][m.id] = {"status": "active", "obj": {}, "data": {}}
	active = m
	if m.issue != "":
		Game.set_issue(m.issue, "progress")
	objectives_changed.emit()
	mission_started.emit(m.id)
	if Cases.has_case(m.id):
		Game.notify("tasks", Game.L("새 조사 노트", "New investigation"), Game.tx(Cases.definitions[m.id]["question"]))
	Game.save_soon()
	_introduce(m)


func _introduce(m: RefCounted) -> void:
	await m.begin()
	if active == m and status(m.id) == "active":
		m.data()["_intro_complete"] = true
		Game.save_soon()


func finish_mission(m: RefCounted) -> void:
	if status(m.id) != "active":
		return
	Game.state["story"][m.id]["status"] = "done"
	if m.issue != "":
		Game.set_issue(m.issue, "done")
	Game.inc_stat("missions")
	Cases.close_case(m.id)
	Game.save_soon()
	await get_tree().create_timer(2.5).timeout
	if active == m and status(m.id) == "done":
		_start_next()


func _on_event(kind: String, data: Dictionary) -> void:
	if kind == "git_committed":
		Game.inc_stat("commits")
		if data["branch"] == "main":
			Game.inc_stat("main_commits")
			_main_commit_warning()
	side.on_event(kind, data)
	arcs.on_event(kind, data)
	events.on_event(kind, data)
	career.on_event(kind, data)
	if active == null or status(active.id) != "active":
		return
	var m = active
	m.auto_event(kind, data)
	if kind == "pr_merged" and int(data.get("pr", 0)) == int(m.data().get("pr", -1)):
		if m.handling_merge:
			return
		m.handling_merge = true
	m.on_event(kind, data)


func _main_commit_warning() -> void:
	Game.relate("daniel", {"work": -5})
	if not Game.state["flags"].get("warned_main", false):
		Game.state["flags"]["warned_main"] = true
		Game.say("daniel", Game.LL("main에 바로 커밋하셨네요. 위키 협업 규칙대로 작업 브랜치에서 진행해 주세요. (git switch -c 새브랜치 로 지금 커밋을 그대로 가져갈 수 있어요)",
			"You committed straight to main. Please follow the Wiki rules and work on a branch. (git switch -c new-branch carries this commit over.)"))


func claim_pr(pr: Dictionary) -> void:
	if active != null and active.has_objective("pr") and not active.is_done("pr") \
			and int(active.data().get("pr", 0)) == 0:
		active.data()["pr"] = pr["id"]
		pr["mission"] = active.id


func hidden_tests_for(pr: Dictionary) -> Dictionary:
	var m = mission(pr.get("mission", ""))
	return m.hidden_tests() if m != null else {}


func next_hint() -> String:
	if active == null or active.hints.is_empty():
		return ""
	var d: Dictionary = active.data()
	var i := int(d.get("hint", 0))
	if i >= active.hints.size():
		return Game.tx(active.hints[-1])
	d["hint"] = i + 1
	Game.inc_stat("hints")
	Game.save_soon()
	return Game.tx(active.hints[i])
