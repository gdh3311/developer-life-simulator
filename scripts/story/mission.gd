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
var chapter := 1
var title := {}
var issue := ""
var tutorial := false           # show the guide card with step-by-step help
var objectives: Array = []
var hints: Array = []           # [{ko,en}] revealed one by one in AICode
var ai_task := {}               # Authored patch recipe: a substitution or file/base pairs.
var default_reviewer := "daniel"
var story: Node
var handling_merge := false


# --- Overridables -----------------------------------------------------------------

func begin() -> void:
	pass


func resume() -> void:
	if has_objective("merged") and (is_done("merged") or pr().get("state", "") == "merged"):
		story._on_event("pr_merged", {"pr": int(data().get("pr", 0)), "by": pr().get("reviewer", "daniel")})
	elif all_done():
		finish()


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


func is_current() -> bool:
	return story.active == self and story.status(id) == "active"


func once(key: String) -> bool:
	if data().get(key, false):
		return false
	data()[key] = true
	Game.save_soon()
	return true


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
	# A restarted introduction may revisit this line, but must not resend a choice or message.
	var key := from + "|" + JSON.stringify(text) + "|" + String(opts.get("key", ""))
	var posted: Dictionary = data().get("_posted", {})
	if posted.has(key):
		for message in Game.state["chat"]:
			if int(message["id"]) == int(posted[key]):
				return message
	var message := Game.say(from, text, opts)
	posted[key] = message["id"]
	data()["_posted"] = posted
	return message


func wait(sec: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(sec).timeout


## options: [[id, {ko,en}], ...]
func choice(from: String, text, key: String, options: Array, opts := {}) -> Dictionary:
	var o := opts.duplicate()
	o["key"] = key
	o["choices"] = options.map(func(c: Array) -> Dictionary: return {"id": c[0], "label": c[1]})
	return say(from, text, o)


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


## --- Docs forms (scope, release, ownership...) -----------------------------------
## forms_def: { form_id: spec } where spec = { title, intro, submit, slots: [{ id, label, multi, max,
## capacity, options: [{ id, text, cost }] }] }. The Docs app renders open forms and calls submit_form.
var forms_def := {}


func open_forms() -> Array:
	if not is_current():
		return []
	return forms_def.keys().map(func(k: String) -> Dictionary:
		var spec: Dictionary = forms_def[k].duplicate()
		spec["id"] = k
		spec["done"] = form_done(k)
		spec["picks"] = data().get("forms", {}).get(k, {})
		return spec)


func form_done(form_id: String) -> bool:
	return data().get("forms", {}).has(form_id)


## Returns notes ([{ko,en}]) explaining what to fix; empty means accepted.
func submit_form(form_id: String, picks: Dictionary) -> Array:
	if not is_current() or form_done(form_id) or not forms_def.has(form_id):
		return []
	var notes := FormRules.missing(forms_def[form_id], picks)
	if notes.is_empty():
		notes = judge_form(form_id, picks)
	data()["form_tries_" + form_id] = int(data().get("form_tries_" + form_id, 0)) + 1
	if not notes.is_empty():
		Game.emit_event("form_rejected", {"form": form_id, "notes": notes.size()})
		return notes
	var forms: Dictionary = data().get("forms", {})
	forms[form_id] = picks.duplicate(true)
	data()["forms"] = forms
	Game.save_soon()
	Game.emit_event("form_submitted", {"form": form_id})
	on_form_accepted(form_id, picks)
	return []


func judge_form(_form_id: String, _picks: Dictionary) -> Array:
	return []


func on_form_accepted(_form_id: String, _picks: Dictionary) -> void:
	pass


const FormRules := preload("res://scripts/story/form_rules.gd")


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
					say("mina", t("%s 브랜치의 실패 케이스는 CI에서도 확인할 수 있어요. 기대 결과와 실제 결과를 비교해 보세요. 병합 전까지 고치면 됩니다." % d["branch"],
						"CI can help inspect the failing cases on %s. Compare expected and actual results; fix them before merging." % d["branch"]))
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
