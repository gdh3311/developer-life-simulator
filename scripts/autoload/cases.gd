extends Node
## Optional investigation loop. Notes never replace tests, reviews or permissions.

signal changed

const Files := preload("res://scripts/story/case_files.gd")
var definitions := Files.definitions()


func _ready() -> void:
	Game.event.connect(_observe)
	Game.state_reset.connect(func() -> void: changed.emit())


func has_case(id: String) -> bool:
	return definitions.has(id)


func record(id: String) -> Dictionary:
	return Game.state.get("investigations", {}).get(id, {})


func _ensure(id: String) -> Dictionary:
	if not Game.state.has("investigations"):
		Game.state["investigations"] = {}
	if record(id).is_empty():
		Game.state["investigations"][id] = {"clues": {}, "hypothesis": "", "closed": false, "day": Game.day(), "outcome": ""}
	return record(id)


func _observe(kind: String, data: Dictionary) -> void:
	if Story.active == null or Story.status(Story.active.id) != "active":
		return
	var id: String = Story.active.id
	if not has_case(id) or record(id).get("closed", false):
		return
	var observation := data.duplicate()
	if kind in ["ci", "mergeable"]:
		observation["mission"] = CodeHub.get_pr(int(data.get("pr", 0))).get("mission", "")
	for c in definitions[id]["clues"]:
		if Files.matches(c, kind, observation, id):
			var r := _ensure(id)
			if not r["clues"].has(c["id"]):
				r["clues"][c["id"]] = Game.time_text()
				Game.save_soon()
				changed.emit()
				Game.notify("tasks", Game.L("조사 단서 기록", "Clue recorded"), Game.tx(c["title"]))


func choose(id: String, hypothesis: String) -> bool:
	if Story.active == null or Story.active.id != id or Story.status(id) != "active" or not has_case(id):
		return false
	var r := record(id)
	if r.is_empty() or r.get("closed", false) or r["clues"].is_empty():
		return false
	if not definitions[id]["hypotheses"].any(func(h: Dictionary) -> bool: return h["id"] == hypothesis):
		return false
	if r["hypothesis"] == hypothesis:
		return true
	r["hypothesis"] = hypothesis
	Game.save_soon()
	changed.emit()
	return true


func close_case(id: String) -> void:
	if not has_case(id) or record(id).get("closed", false):
		return
	var r := _ensure(id)
	r["closed"] = true
	r["outcome"] = "followup" if id == "d3_06" and Game.state["flags"].get("coupon_bug", false) else "resolved"
	if id == "d4_09" and not record("d3_06").is_empty():
		record("d3_06")["outcome"] = "recovered"
	Game.save_soon()
	changed.emit()
	Game.notify("tasks", Game.L("조사 기록 정리", "Investigation filed"), Game.L("Dashboard에서 가설과 실제 결과를 돌아볼 수 있어요.", "Review your hypothesis and the outcome in Dashboard."))


func archive() -> Array:
	var result: Array = []
	for id in definitions:
		if record(id).get("closed", false):
			result.append(id)
	return result
