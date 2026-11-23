extends RefCounted
## Base class for a story mission.
##
## A mission has ordered objectives. Common development objectives complete automatically from
## real events (tests, git, CodeHub); missions add their own scripting in begin()/on_event().
## Judgement is result-based: tests and CI, not exact code.
##
## Auto objective ids: tests, branch, commit, push, pr, ci, approved, merged, sync
## Objective fields: { id, text: {ko,en}, app: dock app to highlight (tutorial), guide: {ko,en} }

var id := ""
var day := 1
var title := {}
var issue := ""
var tutorial := false           # show the guide card with step-by-step help
var objectives: Array = []
var hints: Array = []           # [{ko,en}] revealed one by one in AICode
var ai_task := {}               # { label, files: {path: content_path}, summary }
var default_reviewer := "daniel"
var story: Node


# --- Overridables -----------------------------------------------------------------

func begin() -> void:
	pass


func resume() -> void:
	pass


func on_event(_kind: String, _data: Dictionary) -> void:
	pass


## Hidden CI tests for this mission's PR: { filename: content }.
func hidden_tests() -> Dictionary:
	return {}


## Called when CI passes on the mission's PR and it has no review decision yet.
func review(pr: Dictionary) -> void:
	CodeHub.review(pr["id"], default_reviewer, "approved", t("확인했습니다. 테스트도 통과하고 변경 범위도 적절하네요.", "Looks good. Tests pass and the change is well scoped."))


func should_run() -> bool:
	return true


# --- Text -------------------------------------------------------------------------

static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


func title_text() -> String:
	return Game.tx(title)


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


## First objective not yet done (for the tutorial guide).
func current_objective() -> Dictionary:
	for o in objectives:
		if not is_done(o["id"]):
			return o
	return {}


func complete(obj_id: String) -> void:
	if is_done(obj_id) or not has_objective(obj_id):
		return
	st()["obj"][obj_id] = true
	for o in objectives:
		if o["id"] == obj_id:
			Game.notify("tasks", "%s · %s" % [issue if issue != "" else title_text(), Game.L("진행", "progress")], "✓ " + Game.tx(o["text"]))
	story.objectives_changed.emit()
	Game.save_soon()


func finish() -> void:
	story.finish_mission(self)


func pr() -> Dictionary:
	return CodeHub.get_pr(int(data().get("pr", 0)))


# --- Helpers -----------------------------------------------------------------------

func say(from: String, text, opts := {}) -> Dictionary:
	return Game.say(from, text, opts)


func wait(sec: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(sec).timeout


## options: [[id, {ko,en}], ...]
func choice(from: String, text, key: String, options: Array, opts := {}) -> Dictionary:
	var o := opts.duplicate()
	o["key"] = key
	o["choices"] = options.map(func(c: Array) -> Dictionary: return {"id": c[0], "label": c[1]})
	return Game.say(from, text, o)


func load_tests(folder: String) -> Dictionary:
	var result := {}
	var dir := Workspace.ci_content_dir(folder)
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


## Updates the production Monitor. status: ok | warn | down. mode: log stream preset.
func monitor(service: String, status: String, mode := "") -> void:
	var m: Dictionary = Game.state["monitor"]
	m["status"][service] = status
	if mode != "":
		m["mode"] = mode
	Game.emit_event("monitor", {"service": service, "status": status})


## Is argv a git command with this subcommand (and optional extra words)?
static func is_git(argv: Array, sub: String) -> bool:
	return argv.size() >= 2 and argv[0] == "git" and argv[1] == sub


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
				if not data().get("tests_ok", true) and has_objective("tests") and not data().get("warned_red", false):
					data()["warned_red"] = true
					Game.relate("mina", {"work": -3})
					say("mina", t("%s 브랜치 올라온 거 봤는데, 로컬 테스트가 아직 실패하지 않나요? push 전에 꼭 돌려 주세요." % d["branch"],
						"I saw %s get pushed, but aren't the local tests still failing? Please run them before pushing." % d["branch"]))
		"git_committed_main":
			pass
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
					CodeHub.comment(int(d["pr"]), "mina", t("CI에는 [CI] 로 시작하는 추가 검증 테스트가 있어요. 실패한 케이스를 보고 위키의 스펙을 다시 확인해 보세요!",
						"CI also runs extra checks whose names start with [CI]. Look at the failing case and re-read the spec in the Wiki!"))
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
