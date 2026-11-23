extends Node
## Runs the missions in order, day by day, routes game events to the active mission,
## and fires side events (lunch, coffee chats, check-ins, job offers...).

signal objectives_changed
signal mission_started(id: String)
signal chapter_finished

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
]
const SideEvents := preload("res://scripts/story/side_events.gd")
const LAST_DAY := 4

var _missions: Array = []
var active: RefCounted = null
var side: RefCounted


func _ready() -> void:
	_build()
	Game.event.connect(_on_event)
	Game.time_changed.connect(func(_d: int, _m: int) -> void: side.check())
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


func mission(id: String) -> RefCounted:
	for m in _missions:
		if m.id == id:
			return m
	return null


func missions() -> Array:
	return _missions


func status(id: String) -> String:
	return String(Game.state["story"].get(id, {}).get("status", "locked"))


func start_new() -> void:
	start_day(Game.day())


func resume() -> void:
	for m in _missions:
		if status(m.id) == "active":
			active = m
			m.resume()
			objectives_changed.emit()
			return
	if not Game.state["day_done"]:
		_start_next()


func start_day(_d: int) -> void:
	_start_next()
	side.check()


func _start_next() -> void:
	for m in _missions:
		if status(m.id) == "locked" and m.day == Game.day():
			if not m.should_run():
				Game.state["story"][m.id] = {"status": "skipped", "obj": {}, "data": {}}
				continue
			_start(m)
			return
	active = null
	objectives_changed.emit()
	side.flush_day()
	if Game.day() >= LAST_DAY:
		chapter_finished.emit()
	Game.finish_day()


func _start(m: RefCounted) -> void:
	Game.state["story"][m.id] = {"status": "active", "obj": {}, "data": {}}
	active = m
	if m.issue != "":
		Game.set_issue(m.issue, "progress")
	objectives_changed.emit()
	mission_started.emit(m.id)
	Game.save_soon()
	m.begin()


func finish_mission(m: RefCounted) -> void:
	if status(m.id) != "active":
		return
	Game.state["story"][m.id]["status"] = "done"
	if m.issue != "":
		Game.set_issue(m.issue, "done")
	Game.inc_stat("missions")
	Game.save_soon()
	await get_tree().create_timer(2.5).timeout
	_start_next()


func _on_event(kind: String, data: Dictionary) -> void:
	if kind == "git_committed":
		Game.inc_stat("commits")
		if data["branch"] == "main":
			Game.inc_stat("main_commits")
			_main_commit_warning()
	side.on_event(kind, data)
	if active == null:
		return
	var m = active
	m.auto_event(kind, data)
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
	return Game.tx(active.hints[i])
