extends RefCounted
## Base class for a story mission.
##
## A mission has ordered objectives. Common development objectives complete automatically from
## real events (tests, git, CodeHub); missions add their own scripting in begin()/on_event().
## Judgement is result-based: tests and CI, not exact code.
##
## Auto objective ids: tests, branch, commit, push, pr, ci, approved, merged, sync

var id := ""
var day := 1
var title := ""
var issue := ""
var objectives: Array = []      # [{ id, text }]
var hints: Array = []           # beginner hints, revealed one by one in AICode
var ai_task := {}               # { label, files: {path: content_path}, summary } for AI delegation
var default_reviewer := "daniel"
var story: Node


# --- Overridables -----------------------------------------------------------------

## Called once when the mission starts (coroutine allowed).
func begin() -> void:
	pass


## Called after loading a save while this mission is active.
func resume() -> void:
	pass


func on_event(_kind: String, _data: Dictionary) -> void:
	pass


## Hidden CI tests for this mission's PR: { filename: content }.
func hidden_tests() -> Dictionary:
	return {}


## Called when CI passes on the mission's PR and it has no review decision yet.
func review(pr: Dictionary) -> void:
	CodeHub.review(pr["id"], default_reviewer, "approved", "확인했습니다. 테스트도 통과하고 변경 범위도 적절하네요. 👍")


## Skip this mission (conditional content).
func should_run() -> bool:
	return true


# --- State --------------------------------------------------------------------------

func st() -> Dictionary:
	return Game.state["story"][id]


func data() -> Dictionary:
	return st()["data"]


func is_done(obj_id: String) -> bool:
	return st()["obj"].get(obj_id, false)


func has_objective(obj_id: String) -> bool:
	return objectives.any(func(o: Dictionary) -> bool: return o["id"] == obj_id)


func all_done() -> bool:
	return objectives.all(func(o: Dictionary) -> bool: return is_done(o["id"]))


func complete(obj_id: String) -> void:
	if is_done(obj_id) or not has_objective(obj_id):
		return
	st()["obj"][obj_id] = true
	for o in objectives:
		if o["id"] == obj_id:
			Game.notify("tasks", "%s · 진행" % (issue if issue != "" else title), "✓ " + String(o["text"]))
	story.objectives_changed.emit()
	Game.save_soon()


func finish() -> void:
	story.finish_mission(self)


func pr() -> Dictionary:
	return CodeHub.get_pr(int(data().get("pr", 0)))


# --- Helpers -----------------------------------------------------------------------

func say(from: String, text: String, opts := {}) -> Dictionary:
	return Game.say(from, text, opts)


func wait(sec: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(sec).timeout


func choice(from: String, text: String, key: String, options: Array, opts := {}) -> Dictionary:
	var o := opts.duplicate()
	o["key"] = key
	o["choices"] = options.map(func(c: Array) -> Dictionary: return {"id": c[0], "label": c[1]})
	return Game.say(from, text, o)


## Updates the production Monitor. status: ok | warn | down. mode: log stream preset.
func monitor(service: String, status: String, mode := "") -> void:
	var m: Dictionary = Game.state["monitor"]
	m["status"][service] = status
	if mode != "":
		m["mode"] = mode
	Game.emit_event("monitor", {"service": service, "status": status})


func load_tests(folder: String) -> Dictionary:
	var result := {}
	var dir := "res://content/ci/" + folder
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".ts"):
			result[f] = FileAccess.get_file_as_string(dir.path_join(f))
	return result


func diff_touches_tests(pr_dict: Dictionary) -> bool:
	var diff := await Workspace.pr_diff(pr_dict["branch"])
	return "+++ b/tests/" in diff


func added_tests_count(pr_dict: Dictionary) -> int:
	var diff := await Workspace.pr_diff(pr_dict["branch"])
	var n := 0
	var in_test_file := false
	for line in diff.split("\n"):
		if line.begins_with("+++ "):
			in_test_file = line.begins_with("+++ b/tests/")
		elif in_test_file and line.begins_with("+") and "test(" in line:
			n += 1
	return n


# --- Automatic objectives ---------------------------------------------------------

func auto_event(kind: String, d: Dictionary) -> void:
	match kind:
		"tests":
			data()["tests_ok"] = d.get("ok", false)
			if d.get("ok", false):
				complete("tests")
		"git_branch_created":
			if d["branch"] != "main":
				complete("branch")
		"git_committed":
			if d["branch"] != "main":
				complete("commit")
		"git_pushed":
			if d["branch"] != "main":
				complete("push")
		"git_synced":
			complete("sync")
		"pr_opened":
			if int(data().get("pr", 0)) == int(d["pr"]):
				complete("pr")
		"ci":
			if int(d["pr"]) == int(data().get("pr", 0)) and not d["ok"] and not data().get("ci_explained", false):
				var failures: Array = pr()["ci"]["failures"]
				if failures.any(func(f: Dictionary) -> bool: return String(f["name"]).begins_with("[CI]")):
					data()["ci_explained"] = true
					CodeHub.comment(int(d["pr"]), "mina", "CI에는 [CI] 로 시작하는 추가 검증 테스트가 있어요. 실패한 케이스를 보고 위키의 스펙을 다시 확인해 보세요!")
			if int(d["pr"]) == int(data().get("pr", 0)) and d["ok"]:
				complete("ci")
				var p := pr()
				if p["review"]["state"] == "pending" and not d.get("conflict", false):
					review(p)
		"review":
			if int(d["pr"]) == int(data().get("pr", 0)) and d["state"] == "approved":
				complete("approved")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				complete("merged")
