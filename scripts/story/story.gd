extends Node
## Runs the missions in order, day by day, and routes game events to the active mission.

signal objectives_changed
signal mission_started(id: String)
signal chapter_finished

const MISSIONS := [
	preload("res://scripts/story/missions/m01_onboarding.gd"),
	preload("res://scripts/story/missions/m02_first_fix.gd"),
	preload("res://scripts/story/missions/m03_sync.gd"),
	preload("res://scripts/story/missions/m04_regression.gd"),
	preload("res://scripts/story/missions/m05_review.gd"),
	preload("res://scripts/story/missions/m06_shipping.gd"),
	preload("res://scripts/story/missions/m07_login_incident.gd"),
	preload("res://scripts/story/missions/m08_coupon_hotfix.gd"),
	preload("res://scripts/story/missions/m09_retro.gd"),
]

var _missions: Array = []  # instances, in order
var active: RefCounted = null


func _ready() -> void:
	_build()
	Game.event.connect(_on_event)
	Game.state_reset.connect(func() -> void:
		active = null
		_build())


func _build() -> void:
	_missions.clear()
	for script in MISSIONS:
		var m = script.new()
		m.story = self
		_missions.append(m)


func mission(id: String) -> RefCounted:
	for m in _missions:
		if m.id == id:
			return m
	return null


func missions() -> Array:
	return _missions


func status(id: String) -> String:
	return String(Game.state["story"].get(id, {}).get("status", "locked"))


## New game: start day 1.
func start_new() -> void:
	start_day(Game.day())


## After loading: re-attach to the active mission, or continue the day.
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
	if _missions.all(func(x) -> bool: return status(x.id) in ["done", "skipped"]):
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
	await (get_tree()).create_timer(2.5).timeout
	_start_next()


func _on_event(kind: String, data: Dictionary) -> void:
	if active == null:
		return
	var m = active
	m.auto_event(kind, data)
	m.on_event(kind, data)
	if kind == "git_committed" and data["branch"] == "main":
		Game.inc_stat("main_commits")
	if kind == "git_committed":
		Game.inc_stat("commits")


## A player PR is attached to the active mission (for hidden CI tests and objectives).
func claim_pr(pr: Dictionary) -> void:
	if active != null and active.has_objective("pr") and not active.is_done("pr") \
			and int(active.data().get("pr", 0)) == 0:
		active.data()["pr"] = pr["id"]
		pr["mission"] = active.id


func hidden_tests_for(pr: Dictionary) -> Dictionary:
	var m = mission(pr.get("mission", ""))
	return m.hidden_tests() if m != null else {}


## Objectives of the active mission, for the TaskBoard: [{text, done}]
func active_objectives() -> Array:
	if active == null:
		return []
	var m = active
	return m.objectives.map(func(o: Dictionary) -> Dictionary: return {"text": o["text"], "done": m.is_done(o["id"])})


## Next hint for the active mission, or "".
func next_hint() -> String:
	if active == null or active.hints.is_empty():
		return ""
	var d: Dictionary = active.data()
	var i := int(d.get("hint", 0))
	if i >= active.hints.size():
		return active.hints[-1]
	d["hint"] = i + 1
	Game.inc_stat("hints")
	return active.hints[i]
